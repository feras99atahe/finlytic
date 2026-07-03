import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/account.dart';
import '../models/debt.dart';
import '../models/transaction.dart' as txm;

// ── Column indices ────────────────────────────────────────────────────────────
// type | amount | date | account | category | note | contact | direction | due_date
const _kType      = 0;
const _kAmount    = 1;
const _kDate      = 2;
const _kAccount   = 3;
const _kCategory  = 4;
const _kNote      = 5;
const _kContact   = 6;
const _kDirection = 7; // only for debt_record
const _kDueDate   = 8; // only for debt_record

const _kValidTypes    = ['income', 'expense', 'debt', 'transfer', 'debt_record'];
const _kValidAccounts = ['bank', 'safe', 'wallet'];

final _dateFormats = [
  DateFormat('yyyy-MM-dd'),
  DateFormat('dd/MM/yyyy'),
  DateFormat('MM/dd/yyyy'),
];

// ── Parsed row ────────────────────────────────────────────────────────────────
class CsvRow {
  final int rowNumber;
  final String rawType;
  final double amount;
  final DateTime date;
  final AccountType account;
  final String? category;
  final String? note;
  final String? contact;
  // debt_record fields
  final DebtDirection? debtDirection;
  final DateTime? dueDate;
  final String? error;

  const CsvRow({
    required this.rowNumber,
    required this.rawType,
    required this.amount,
    required this.date,
    required this.account,
    this.category,
    this.note,
    this.contact,
    this.debtDirection,
    this.dueDate,
    this.error,
  });

  bool get isValid => error == null;
  bool get isDebtRecord => rawType == 'debt_record';
}

// ── Error-only row (parse failed before building a CsvRow) ───────────────────
class CsvErrorRow extends CsvRow {
  CsvErrorRow({required super.rowNumber, required String error})
      : super(
          rawType: '',
          amount: 0,
          date: DateTime.now(),
          account: AccountType.bank,
          error: error,
        );
}

// ── Service ───────────────────────────────────────────────────────────────────
class CsvService {
  static const List<String> categories = [
    'Food', 'Services', 'Restaurants', 'Personal', 'Debt',
    'Transport', 'Shopping', 'Health', 'Entertain.', 'Other',
  ];
  static const String templateContent =
      'type,amount,date,account,category,note,contact,direction,due_date\n'
      'income,5000.00,2026-01-15,Bank,,Monthly salary,,,\n'
      'income,800.00,2026-01-16,Safe,,Cash from client,,,\n'
      'expense,120.50,2026-01-17,Wallet,Food,Weekly groceries,,,\n'
      'expense,45.00,2026-01-18,Bank,Transport,Uber ride,,,\n'
      'expense,200.00,2026-01-19,Bank,Shopping,New shoes,,,\n'
      'debt,300.00,2026-01-20,Bank,,Paid for friend,John Doe,,\n'
      'transfer,150.00,2026-01-21,Safe,,,,,\n'
      'debt_record,500.00,2026-01-22,,,,Sarah,iOwe,2026-03-01\n'
      'debt_record,200.00,2026-01-23,,,,Mike,owesMe,\n';

  static const String columnGuide =
      'type     — income | expense | debt | transfer | debt_record\n'
      'amount   — positive number  e.g. 120.50\n'
      'date     — YYYY-MM-DD  (also accepts DD/MM/YYYY)\n'
      'account  — Bank | Safe | Wallet\n'
      '           (leave empty for debt_record)\n'
      'category — Food | Transport | Shopping … (expense/debt only)\n'
      'note     — optional description\n'
      'contact  — person name (required for debt & debt_record)\n'
      'direction— iOwe | owesMe  (debt_record only)\n'
      'due_date — YYYY-MM-DD  optional, for debt_record only';

  // ── Share template ──────────────────────────────────────────────────────────
  static Future<void> shareTemplate() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/finlytic_import_template.csv');
    await file.writeAsString(templateContent);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Finlytic CSV Import Template',
    );
  }

  // ── Export ──────────────────────────────────────────────────────────────────
  /// Exports all transactions to CSV and opens the share sheet. Columns follow
  /// the change-spec §6 fixed order and include the two-axis fields. Written as
  /// UTF-8 **with BOM** so Arabic renders correctly in Excel.
  static const List<String> exportColumns = [
    'date', 'type', 'category', 'name', 'amount', 'currency', 'account',
    'is_recurring', 'is_essential', 'recurrence_months', 'contact', 'items',
  ];

  static Future<void> exportTransactions({
    required List<txm.Transaction> transactions,
    required List<Account> accounts,
  }) async {
    final accById = {for (final a in accounts) a.id: a};

    final rows = <List<dynamic>>[exportColumns];
    for (final t in transactions) {
      // The account whose currency/name best represents this row.
      final acc = accById[t.fromAccountId ?? t.toAccountId];
      rows.add([
        t.date.toIso8601String(),
        t.type.name,
        t.category ?? '',
        '', // name/vendor — not captured yet (add-flow redesign, spec §3)
        t.amount,
        acc?.currency ?? '',
        acc?.name ?? '',
        t.isRecurring ? 1 : 0,
        t.isEssential ? 1 : 0,
        t.recurrenceMonths,
        t.contact ?? '',
        t.items.isEmpty
            ? ''
            : jsonEncode(t.items.map((e) => e.toMap()).toList()),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/finlytic_export_$stamp.csv');
    // Prefix with the UTF-8 BOM (writeAsString encodes UTF-8 by default).
    await file.writeAsString('\u{FEFF}$csv');
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Finlytic export',
    );
  }

  // ── Validate / re-validate a single row (used for in-app editing) ───────────
  static CsvRow validateRow({
    required int rowNumber,
    required String type,
    required String amountStr,
    required String dateStr,
    required String account,
    required String category,
    required String note,
    required String contact,
    required String direction,
    required String dueDateStr,
  }) {
    final typeRaw      = type.trim().toLowerCase();
    final amountRaw    = amountStr.trim();
    final accountRaw   = account.trim().toLowerCase();
    final categoryRaw  = category.trim();
    final noteRaw      = note.trim();
    final contactRaw   = contact.trim();
    final directionRaw = direction.trim().toLowerCase();
    final dueDateRaw   = dueDateStr.trim();

    if (!_kValidTypes.contains(typeRaw)) {
      return CsvErrorRow(rowNumber: rowNumber,
          error: 'Unknown type "$typeRaw". Use: income, expense, debt, transfer, debt_record');
    }

    final amount = double.tryParse(amountRaw);
    if (amount == null || amount <= 0) {
      return CsvErrorRow(rowNumber: rowNumber,
          error: 'Invalid amount "$amountRaw". Must be a positive number.');
    }

    if (typeRaw == 'debt_record') {
      if (contactRaw.isEmpty) {
        return CsvErrorRow(rowNumber: rowNumber,
            error: 'Contact is required for debt_record.');
      }
      if (directionRaw != 'iowe' && directionRaw != 'owesme') {
        return CsvErrorRow(rowNumber: rowNumber,
            error: 'Direction must be "iOwe" or "owesMe" for debt_record.');
      }
      DateTime? dueDate;
      if (dueDateRaw.isNotEmpty) {
        for (final fmt in _dateFormats) {
          try { dueDate = fmt.parseStrict(dueDateRaw); break; } catch (_) {}
        }
      }
      return CsvRow(
        rowNumber: rowNumber,
        rawType: typeRaw,
        amount: amount,
        date: DateTime.now(),
        account: AccountType.bank,
        contact: contactRaw,
        note: noteRaw.isEmpty ? null : noteRaw,
        debtDirection:
            directionRaw == 'iowe' ? DebtDirection.iOwe : DebtDirection.owesMe,
        dueDate: dueDate,
      );
    }

    DateTime? date;
    for (final fmt in _dateFormats) {
      try { date = fmt.parseStrict(dateStr.trim()); break; } catch (_) {}
    }
    if (date == null) {
      return CsvErrorRow(rowNumber: rowNumber,
          error: 'Invalid date "${dateStr.trim()}". Use YYYY-MM-DD.');
    }

    if (!_kValidAccounts.contains(accountRaw)) {
      return CsvErrorRow(rowNumber: rowNumber,
          error: 'Unknown account "$accountRaw". Use: Bank, Safe, Wallet');
    }
    final accountType =
        AccountType.values.firstWhere((a) => a.name.toLowerCase() == accountRaw);

    String? businessError;
    if (typeRaw == 'income' && accountType == AccountType.wallet) {
      businessError = 'Income cannot go directly to Wallet. Use Bank or Safe.';
    } else if (typeRaw == 'expense' && accountType == AccountType.safe) {
      businessError = 'Expenses cannot be paid from Safe. Use Bank or Wallet.';
    } else if (typeRaw == 'debt' && accountType == AccountType.safe) {
      businessError = 'Debt cannot be paid from Safe. Use Bank or Wallet.';
    } else if (typeRaw == 'transfer' && accountType != AccountType.safe) {
      businessError = 'Transfer must use Safe as the source account.';
    } else if ((typeRaw == 'expense' || typeRaw == 'debt') && categoryRaw.isEmpty) {
      businessError = 'Category is required for expense and debt rows.';
    } else if (typeRaw == 'debt' && contactRaw.isEmpty) {
      businessError = 'Contact is required for debt rows.';
    }

    String? resolvedCategory;
    if (categoryRaw.isNotEmpty) {
      resolvedCategory = categories.firstWhere(
        (c) => c.toLowerCase() == categoryRaw.toLowerCase(),
        orElse: () => 'Other',
      );
    }

    return CsvRow(
      rowNumber: rowNumber,
      rawType: typeRaw,
      amount: amount,
      date: date,
      account: accountType,
      category: resolvedCategory,
      note: noteRaw.isEmpty ? null : noteRaw,
      contact: contactRaw.isEmpty ? null : contactRaw,
      error: businessError,
    );
  }

  // ── Parse CSV file ──────────────────────────────────────────────────────────
  static List<CsvRow> parse(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent);
    if (rows.isEmpty) return [];

    final dataRows = rows.skip(1).toList();
    final result = <CsvRow>[];

    for (int i = 0; i < dataRows.length; i++) {
      final row    = dataRows[i];
      final rowNum = i + 2;

      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      if (row.length < 2) {
        result.add(CsvErrorRow(
            rowNumber: rowNum,
            error: 'Too few columns (need at least type and amount)'));
        continue;
      }

      final typeRaw      = row[_kType].toString().trim().toLowerCase();
      final amountRaw    = row[_kAmount].toString().trim();
      final dateRaw      = row.length > _kDate ? row[_kDate].toString().trim() : '';
      final accountRaw   = row.length > _kAccount ? row[_kAccount].toString().trim().toLowerCase() : '';
      final categoryRaw  = row.length > _kCategory ? row[_kCategory].toString().trim() : '';
      final noteRaw      = row.length > _kNote ? row[_kNote].toString().trim() : '';
      final contactRaw   = row.length > _kContact ? row[_kContact].toString().trim() : '';
      final directionRaw = row.length > _kDirection ? row[_kDirection].toString().trim() : '';
      final dueDateRaw   = row.length > _kDueDate ? row[_kDueDate].toString().trim() : '';

      // Validate type
      if (!_kValidTypes.contains(typeRaw)) {
        result.add(CsvErrorRow(
            rowNumber: rowNum,
            error: 'Unknown type "$typeRaw". Use: income, expense, debt, transfer, debt_record'));
        continue;
      }

      // Validate amount
      final amount = double.tryParse(amountRaw);
      if (amount == null || amount <= 0) {
        result.add(CsvErrorRow(
            rowNumber: rowNum,
            error: 'Invalid amount "$amountRaw". Must be a positive number.'));
        continue;
      }

      // ── debt_record: different validation path ────────────────────────────
      if (typeRaw == 'debt_record') {
        if (contactRaw.isEmpty) {
          result.add(CsvErrorRow(
              rowNumber: rowNum, error: 'Contact is required for debt_record.'));
          continue;
        }
        if (directionRaw != 'iowe' && directionRaw != 'owesme') {
          result.add(CsvErrorRow(
              rowNumber: rowNum,
              error: 'Direction must be "iOwe" or "owesMe" for debt_record.'));
          continue;
        }
        DateTime? dueDate;
        if (dueDateRaw.isNotEmpty) {
          for (final fmt in _dateFormats) {
            try { dueDate = fmt.parseStrict(dueDateRaw); break; } catch (_) {}
          }
        }
        result.add(CsvRow(
          rowNumber: rowNum,
          rawType: typeRaw,
          amount: amount,
          date: DateTime.now(),
          account: AccountType.bank, // unused for debt_record
          contact: contactRaw,
          note: noteRaw.isEmpty ? null : noteRaw,
          debtDirection: directionRaw == 'iowe'
              ? DebtDirection.iOwe
              : DebtDirection.owesMe,
          dueDate: dueDate,
        ));
        continue;
      }

      // ── Standard transaction rows ─────────────────────────────────────────
      // Validate date
      DateTime? date;
      for (final fmt in _dateFormats) {
        try { date = fmt.parseStrict(dateRaw); break; } catch (_) {}
      }
      if (date == null) {
        result.add(CsvErrorRow(
            rowNumber: rowNum, error: 'Invalid date "$dateRaw". Use YYYY-MM-DD.'));
        continue;
      }

      // Validate account
      if (!_kValidAccounts.contains(accountRaw)) {
        result.add(CsvErrorRow(
            rowNumber: rowNum,
            error: 'Unknown account "$accountRaw". Use: Bank, Safe, Wallet'));
        continue;
      }
      final account = AccountType.values
          .firstWhere((a) => a.name.toLowerCase() == accountRaw);

      // Business rules
      String? businessError;
      if (typeRaw == 'income' && account == AccountType.wallet) {
        businessError = 'Income cannot go directly to Wallet. Use Bank or Safe.';
      } else if (typeRaw == 'expense' && account == AccountType.safe) {
        businessError = 'Expenses cannot be paid from Safe. Use Bank or Wallet.';
      } else if (typeRaw == 'debt' && account == AccountType.safe) {
        businessError = 'Debt cannot be paid from Safe. Use Bank or Wallet.';
      } else if (typeRaw == 'transfer' && account != AccountType.safe) {
        businessError = 'Transfer must use Safe as the source account.';
      } else if ((typeRaw == 'expense' || typeRaw == 'debt') && categoryRaw.isEmpty) {
        businessError = 'Category is required for expense and debt rows.';
      } else if (typeRaw == 'debt' && contactRaw.isEmpty) {
        businessError = 'Contact is required for debt rows.';
      }

      String? category;
      if (categoryRaw.isNotEmpty) {
        category = categories.firstWhere(
          (c) => c.toLowerCase() == categoryRaw.toLowerCase(),
          orElse: () => 'Other',
        );
      }

      result.add(CsvRow(
        rowNumber: rowNum,
        rawType: typeRaw,
        amount: amount,
        date: date,
        account: account,
        category: category,
        note: noteRaw.isEmpty ? null : noteRaw,
        contact: contactRaw.isEmpty ? null : contactRaw,
        error: businessError,
      ));
    }

    return result;
  }
}

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart' as txm;

/// One line parsed from a bank statement CSV.
class BankEntry {
  final DateTime? date;
  final double amount; // magnitude (sign dropped for matching)
  final String description;
  final int rowNumber;

  BankEntry({
    required this.date,
    required this.amount,
    required this.description,
    required this.rowNumber,
  });
}

enum MatchKind { exact, mismatch }

/// A bank entry paired with an app transaction.
class ReconcileMatch {
  final BankEntry bank;
  final txm.Transaction app;
  final MatchKind kind; // exact = amounts agree; mismatch = amount differs
  ReconcileMatch({required this.bank, required this.app, required this.kind});

  double get delta => (bank.amount - app.amount).abs();
}

/// The full reconciliation outcome.
class ReconcileReport {
  final List<ReconcileMatch> matched;     // amounts agree within tolerance
  final List<ReconcileMatch> mismatched;  // paired but amount differs
  final List<BankEntry> bankOnly;         // on statement, missing from app
  final List<txm.Transaction> appOnly;    // in app, not on statement

  ReconcileReport({
    required this.matched,
    required this.mismatched,
    required this.bankOnly,
    required this.appOnly,
  });

  double get bankTotal =>
      [...matched, ...mismatched].fold(0.0, (s, m) => s + m.bank.amount) +
      bankOnly.fold(0.0, (s, b) => s + b.amount);
  double get appTotal =>
      [...matched, ...mismatched].fold(0.0, (s, m) => s + m.app.amount) +
      appOnly.fold(0.0, (s, t) => s + t.amount);

  int get bankCount =>
      matched.length + mismatched.length + bankOnly.length;
  bool get isClean =>
      mismatched.isEmpty && bankOnly.isEmpty && appOnly.isEmpty;
}

class ReconcileService {
  static final _dateFormats = [
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('d/M/yyyy'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd.MM.yyyy'),
  ];

  static const _dateKeys = ['date', 'التاريخ', 'day', 'trans date', 'value date'];
  static const _amountKeys = [
    'amount', 'المبلغ', 'value', 'debit', 'credit', 'withdrawal', 'deposit',
  ];
  static const _descKeys = [
    'description', 'details', 'narration', 'البيان', 'desc', 'reference', 'memo',
  ];

  /// Parses a bank statement CSV into [BankEntry]s. Tolerant of column order,
  /// header names (English/Arabic), comma or semicolon delimiters, and common
  /// date formats. Rows without a parseable amount are skipped.
  static List<BankEntry> parseBankCsv(String content) {
    List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(content);
    // Retry with semicolon if it looks like everything landed in one column.
    if (rows.isNotEmpty && rows.first.length <= 1) {
      rows = const CsvToListConverter(fieldDelimiter: ';', eol: '\n')
          .convert(content);
    }
    if (rows.isEmpty) return [];

    final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    int dateCol = _findCol(header, _dateKeys);
    int amountCol = _findCol(header, _amountKeys);
    int descCol = _findCol(header, _descKeys);
    final hasHeader = dateCol >= 0 || amountCol >= 0;

    // Fallback positions when there is no recognizable header.
    if (dateCol < 0) dateCol = 0;
    if (amountCol < 0) amountCol = header.length > 1 ? 1 : 0;
    if (descCol < 0) descCol = header.length > 2 ? 2 : -1;

    final out = <BankEntry>[];
    final dataRows = hasHeader ? rows.skip(1) : rows;
    var i = hasHeader ? 1 : 0;
    for (final r in dataRows) {
      i++;
      final amount = amountCol < r.length ? _parseAmount(r[amountCol]) : null;
      if (amount == null || amount == 0) continue;
      out.add(BankEntry(
        date: dateCol < r.length ? _parseDate(r[dateCol]) : null,
        amount: amount.abs(),
        description:
            (descCol >= 0 && descCol < r.length) ? r[descCol].toString().trim() : '',
        rowNumber: i,
      ));
    }
    return out;
  }

  static int _findCol(List<String> header, List<String> keys) {
    for (var i = 0; i < header.length; i++) {
      for (final k in keys) {
        if (header[i].contains(k)) return i;
      }
    }
    return -1;
  }

  static double? _parseAmount(dynamic raw) {
    if (raw is num) return raw.toDouble();
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    final negative = s.contains('(') || s.startsWith('-');
    s = s.replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null) return null;
    return negative ? -v : v;
  }

  static DateTime? _parseDate(dynamic raw) {
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    for (final f in _dateFormats) {
      try {
        return f.parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  /// Reconciles bank entries against app transactions. Matches greedily by
  /// amount (within [tolerance]) and date (within [dateWindowDays]); near
  /// amounts (within 10%) on the same date window are flagged as mismatches.
  ///
  /// Internal movements (transfers, opening balances) are excluded from the
  /// app side since they don't appear as ordinary statement lines.
  static ReconcileReport reconcile({
    required List<txm.Transaction> transactions,
    required List<BankEntry> bankEntries,
    double tolerance = 0.01,
    int dateWindowDays = 3,
  }) {
    final candidates = transactions
        .where((t) =>
            t.type != txm.TxType.transfer &&
            t.type != txm.TxType.openingBalance)
        .toList();
    final used = <int>{}; // indices of consumed app transactions

    final matched = <ReconcileMatch>[];
    final mismatched = <ReconcileMatch>[];
    final bankOnly = <BankEntry>[];

    bool withinDate(DateTime? b, DateTime a) {
      if (b == null) return true; // undated bank row: don't gate on date
      return (b.difference(a).inDays).abs() <= dateWindowDays;
    }

    for (final entry in bankEntries) {
      int bestExact = -1, bestNear = -1;
      double bestExactDate = double.infinity, bestNearAmt = double.infinity;
      for (var i = 0; i < candidates.length; i++) {
        if (used.contains(i)) continue;
        final t = candidates[i];
        if (!withinDate(entry.date, t.date)) continue;
        final diff = (entry.amount - t.amount).abs();
        if (diff <= tolerance) {
          final dd = entry.date == null
              ? 0.0
              : entry.date!.difference(t.date).inDays.abs().toDouble();
          if (dd < bestExactDate) {
            bestExactDate = dd;
            bestExact = i;
          }
        } else if (diff / (t.amount.abs().clamp(1, double.infinity)) <= 0.10) {
          if (diff < bestNearAmt) {
            bestNearAmt = diff;
            bestNear = i;
          }
        }
      }

      if (bestExact >= 0) {
        used.add(bestExact);
        matched.add(ReconcileMatch(
            bank: entry, app: candidates[bestExact], kind: MatchKind.exact));
      } else if (bestNear >= 0) {
        used.add(bestNear);
        mismatched.add(ReconcileMatch(
            bank: entry, app: candidates[bestNear], kind: MatchKind.mismatch));
      } else {
        bankOnly.add(entry);
      }
    }

    final appOnly = <txm.Transaction>[];
    for (var i = 0; i < candidates.length; i++) {
      if (!used.contains(i)) appOnly.add(candidates[i]);
    }

    return ReconcileReport(
      matched: matched,
      mismatched: mismatched,
      bankOnly: bankOnly,
      appOnly: appOnly,
    );
  }
}

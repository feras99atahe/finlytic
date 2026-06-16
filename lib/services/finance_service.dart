import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/contact.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/transaction.dart' as txm;
import '../models/tx_edit_log.dart';
import '../utils/money.dart';

class IncomeSource {
  final String name;
  final double amount;
  IncomeSource({required this.name, required this.amount});

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};

  factory IncomeSource.fromMap(Map<String, dynamic> m) => IncomeSource(
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
      );
}

class FinanceService extends ChangeNotifier {
  final _uuid = const Uuid();

  List<Account> _accounts = [];
  List<txm.Transaction> _transactions = [];
  List<IncomeSource> _incomeSources = [];
  double _riskFundAllocationPct = 0.10;
  double _riskFundSavedAmount = 0.0;
  List<Goal> _goals = [];
  List<Debt> _debts = [];
  List<Contact> _contacts = [];

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<txm.Transaction> get transactions => List.unmodifiable(_transactions);
  List<Goal> get goals => List.unmodifiable(_goals);
  List<Debt> get debts => List.unmodifiable(_debts);
  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<IncomeSource> get incomeSources => List.unmodifiable(_incomeSources);

  /// Total monthly income from all sources.
  double get monthlySalary =>
      _incomeSources.fold(0.0, (s, src) => s + src.amount);
  double get riskFundAllocationPct => _riskFundAllocationPct;
  double get riskFundSavedAmount => _riskFundSavedAmount;

  /// Recommended emergency fund target = 3 months of average expenses.
  double get riskFundTarget => avgMonthlyExpenses() * 3;

  /// Sum of risk fund + all goal allocations as a fraction (may exceed 1.0).
  double get totalAllocatedPct =>
      _riskFundAllocationPct +
      _goals.fold(0.0, (s, g) => s + g.allocationPct);

  List<Debt> get iOweDebts =>
      _debts.where((d) => d.direction == DebtDirection.iOwe).toList();
  List<Debt> get owesMeDebts =>
      _debts.where((d) => d.direction == DebtDirection.owesMe).toList();

  double get totalIOwe => iOweDebts.fold(0.0, (s, d) => s + d.amount);
  double get totalOwesMe => owesMeDebts.fold(0.0, (s, d) => s + d.amount);

  /// All unique contact names that appear in any transaction.
  Set<String> get allContactNames => _transactions
      .where((t) => t.contact != null && t.contact!.isNotEmpty)
      .map((t) => t.contact!)
      .toSet();

  // -------------------- LOAD --------------------
  Future<void> load() async {
    final db = await DBHelper.instance.database;
    final aRows = await db.query('accounts', orderBy: 'createdAt ASC');
    final tRows = await db.query('transactions', orderBy: 'date DESC');
    final gRows = await db.query('goals', orderBy: 'createdAt DESC');
    final dRows = await db.query('debts', orderBy: 'createdAt DESC');
    final cRows = await db.query('contacts', orderBy: 'name ASC');

    _accounts     = aRows.map(Account.fromMap).toList();
    _transactions = tRows.map(txm.Transaction.fromMap).toList();
    _goals        = gRows.map(Goal.fromMap).toList();
    _debts        = dRows.map(Debt.fromMap).toList();
    _contacts     = cRows.map(Contact.fromMap).toList();

    final prefs = await SharedPreferences.getInstance();
    final sourcesJson = prefs.getString('profile_income_sources');
    if (sourcesJson != null) {
      final list = (jsonDecode(sourcesJson) as List)
          .cast<Map<String, dynamic>>();
      _incomeSources = list.map(IncomeSource.fromMap).toList();
    } else {
      // Migrate from old single-salary key
      final legacy = prefs.getDouble('profile_monthly_salary') ?? 0;
      if (legacy > 0) {
        _incomeSources = [IncomeSource(name: 'Salary', amount: legacy)];
        await prefs.setString('profile_income_sources',
            jsonEncode(_incomeSources.map((s) => s.toMap()).toList()));
      }
    }
    _riskFundAllocationPct = prefs.getDouble('risk_fund_allocation_pct') ?? 0.10;
    _riskFundSavedAmount = prefs.getDouble('risk_fund_saved_amount') ?? 0.0;

    if (_accounts.isEmpty) {
      await _seedDefaultAccounts();
    }
    notifyListeners();
  }

  Future<void> setRiskFundAllocation(double pct) async {
    _riskFundAllocationPct = pct.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('risk_fund_allocation_pct', _riskFundAllocationPct);
    notifyListeners();
  }

  Future<void> contributeToRiskFund(double amount) async {
    _riskFundSavedAmount += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('risk_fund_saved_amount', _riskFundSavedAmount);
    notifyListeners();
  }

  Future<void> updateGoalAllocationPct(String goalId, double pct) async {
    final db = await DBHelper.instance.database;
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;
    final updated = _goals[idx].copyWith(allocationPct: pct.clamp(0.0, 1.0));
    _goals[idx] = updated;
    await db.update('goals', updated.toMap(),
        where: 'id = ?', whereArgs: [goalId]);
    notifyListeners();
  }

  Future<void> setIncomeSources(List<IncomeSource> sources) async {
    _incomeSources = List.of(sources);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_income_sources',
        jsonEncode(_incomeSources.map((s) => s.toMap()).toList()));
    notifyListeners();
  }

  Future<void> _seedDefaultAccounts() async {
    await addAccount(name: 'Bank',   type: AccountType.bank,   initialBalance: 0);
    await addAccount(name: 'Safe',   type: AccountType.safe,   initialBalance: 0);
    await addAccount(name: 'Wallet', type: AccountType.wallet, initialBalance: 0);
  }

  // -------------------- ACCOUNTS --------------------
  Future<Account> addAccount({
    required String name,
    required AccountType type,
    double initialBalance = 0,
    String currency = 'USD',
    String? bankName,
    String? notes,
  }) async {
    final db = await DBHelper.instance.database;
    final acc = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: 0,
      createdAt: DateTime.now(),
      currency: currency,
      bankName: bankName,
      notes: notes,
    );
    await db.insert('accounts', acc.toMap());
    _accounts.add(acc);

    if (initialBalance > 0) {
      await addOpeningBalance(accountId: acc.id, amount: initialBalance);
    } else {
      notifyListeners();
    }
    return acc;
  }

  Future<void> updateAccount(
    String id, {
    String? name,
    String? currency,
    String? bankName,
    String? notes,
    bool clearBankName = false,
    bool clearNotes = false,
  }) async {
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final updated = _accounts[idx].copyWith(
      name: name,
      currency: currency,
      bankName: bankName,
      notes: notes,
      clearBankName: clearBankName,
      clearNotes: clearNotes,
    );
    final db = await DBHelper.instance.database;
    await db.update('accounts', updated.toMap(),
        where: 'id = ?', whereArgs: [id]);
    _accounts[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    final db = await DBHelper.instance.database;
    // Drop the edit history of any transactions this account is removing.
    final orphanedTxIds = _transactions
        .where((t) => t.fromAccountId == id || t.toAccountId == id)
        .map((t) => t.id)
        .toList();
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await db.delete('transactions',
        where: 'fromAccountId = ? OR toAccountId = ?', whereArgs: [id, id]);
    for (final txId in orphanedTxIds) {
      await db.delete('tx_edit_logs', where: 'txId = ?', whereArgs: [txId]);
    }
    _accounts.removeWhere((a) => a.id == id);
    _transactions.removeWhere(
        (t) => t.fromAccountId == id || t.toAccountId == id);
    notifyListeners();
  }

  Account? accountById(String? id) =>
      id == null ? null : _accounts.firstWhere(
          (a) => a.id == id, orElse: () => _accounts.first);

  Account? firstOfType(AccountType type) {
    for (final a in _accounts) {
      if (a.type == type) return a;
    }
    return null;
  }

  Future<void> _updateBalance(String accountId, double delta) async {
    final db = await DBHelper.instance.database;
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx < 0) return;
    final updated = _accounts[idx].copyWith(
      balance: _accounts[idx].balance + delta,
    );
    _accounts[idx] = updated;
    await db.update('accounts', updated.toMap(),
        where: 'id = ?', whereArgs: [accountId]);
  }

  // -------------------- CONTACTS --------------------
  Future<Contact> addContact({required String name, String? phone}) async {
    final db = await DBHelper.instance.database;
    final c = Contact(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      createdAt: DateTime.now(),
    );
    await db.insert('contacts', c.toMap());
    _contacts.add(c);
    _contacts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return c;
  }

  Future<void> deleteContact(String id) async {
    final db = await DBHelper.instance.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // -------------------- TRANSACTIONS --------------------

  /// Income → any account.
  Future<void> addIncome({
    required String toAccountId,
    required double amount,
    String? note,
    String? contact,
    DateTime? date,
    List<txm.TxItem> items = const [],
  }) async {
    final acc = accountById(toAccountId);
    if (acc == null) throw 'Account not found';
    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.income,
      amount: amount,
      toAccountId: toAccountId,
      contact: contact?.trim().isEmpty == true ? null : contact?.trim(),
      note: note,
      date: date ?? DateTime.now(),
      items: items,
    ));
    await _updateBalance(toAccountId, amount);
    notifyListeners();
  }

  /// Opening balance — special tagged income at start date.
  Future<void> addOpeningBalance({
    required String accountId,
    required double amount,
    DateTime? date,
  }) async {
    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.openingBalance,
      amount: amount,
      toAccountId: accountId,
      note: 'Opening Balance',
      date: date ?? DateTime.now(),
    ));
    await _updateBalance(accountId, amount);
    notifyListeners();
  }

  /// Expense → any account.
  Future<void> addExpense({
    required String fromAccountId,
    required double amount,
    required String category,
    String? note,
    String? contact,
    DateTime? date,
    List<txm.TxItem> items = const [],
  }) async {
    final acc = accountById(fromAccountId);
    if (acc == null) throw 'Account not found';
    if (acc.balance < amount) {
      throw 'Insufficient balance in ${acc.name}.';
    }

    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.expense,
      amount: amount,
      fromAccountId: fromAccountId,
      category: category,
      contact: contact?.trim().isEmpty == true ? null : contact?.trim(),
      note: note,
      date: date ?? DateTime.now(),
      items: items,
    ));
    await _updateBalance(fromAccountId, -amount);
    notifyListeners();
  }

  /// Debt — linked to a contact.
  /// [fromAccountId] null → I owe (just a record, no balance change).
  /// [fromAccountId] set → I paid / I lent (deducts from that account).
  Future<void> addDebtTransaction({
    String? fromAccountId,
    required double amount,
    required String contact,
    String? note,
    DateTime? date,
  }) async {
    if (fromAccountId != null) {
      final acc = accountById(fromAccountId);
      if (acc == null) throw 'Account not found';
      if (acc.balance < amount) {
        throw 'Insufficient balance in ${acc.name}.';
      }
    }

    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.debt,
      amount: amount,
      fromAccountId: fromAccountId,
      category: 'Debt',
      contact: contact,
      note: note,
      date: date ?? DateTime.now(),
    ));
    if (fromAccountId != null) {
      await _updateBalance(fromAccountId, -amount);
    }
    notifyListeners();
  }

  /// Transfer between any two accounts.
  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    if (fromAccountId == toAccountId) {
      throw 'Cannot transfer to the same account.';
    }
    final from = accountById(fromAccountId);
    final to = accountById(toAccountId);
    if (from == null || to == null) throw 'Account not found.';
    if (from.balance < amount) {
      throw 'Insufficient balance in ${from.name}.';
    }

    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.transfer,
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      note: (note == null || note.trim().isEmpty)
          ? '${from.name} → ${to.name}'
          : note.trim(),
      date: date ?? DateTime.now(),
    ));
    await _updateBalance(fromAccountId, -amount);
    await _updateBalance(toAccountId, amount);
    notifyListeners();
  }

  /// Backward-compat shortcut used by CSV import.
  Future<void> transferSafeToWallet({
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final safe   = firstOfType(AccountType.safe);
    final wallet = firstOfType(AccountType.wallet);
    if (safe == null || wallet == null) {
      throw 'Safe or Wallet account missing.';
    }
    await transfer(
      fromAccountId: safe.id,
      toAccountId: wallet.id,
      amount: amount,
      note: note,
      date: date,
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await DBHelper.instance.database;
    final tx = _transactions.firstWhere((t) => t.id == id);

    switch (tx.type) {
      case txm.TxType.income:
      case txm.TxType.openingBalance:
        if (tx.toAccountId != null) {
          await _updateBalance(tx.toAccountId!, -tx.amount);
        }
        break;
      case txm.TxType.expense:
      case txm.TxType.debt:
        if (tx.fromAccountId != null) {
          await _updateBalance(tx.fromAccountId!, tx.amount);
        }
        break;
      case txm.TxType.transfer:
        if (tx.fromAccountId != null) {
          await _updateBalance(tx.fromAccountId!, tx.amount);
        }
        if (tx.toAccountId != null) {
          await _updateBalance(tx.toAccountId!, -tx.amount);
        }
        break;
    }

    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await db.delete('tx_edit_logs', where: 'txId = ?', whereArgs: [id]);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Account balance deltas applied to the ledger when [tx] is "added".
  /// Reversing a transaction is the negation of these.
  Map<String, double> _balanceDeltas(txm.Transaction tx) {
    final d = <String, double>{};
    void bump(String? acc, double v) {
      if (acc == null) return;
      d[acc] = (d[acc] ?? 0) + v;
    }

    switch (tx.type) {
      case txm.TxType.income:
      case txm.TxType.openingBalance:
        bump(tx.toAccountId, tx.amount);
        break;
      case txm.TxType.expense:
      case txm.TxType.debt:
        bump(tx.fromAccountId, -tx.amount);
        break;
      case txm.TxType.transfer:
        bump(tx.fromAccountId, -tx.amount);
        bump(tx.toAccountId, tx.amount);
        break;
    }
    return d;
  }

  /// Edits an existing transaction in place: re-derives the net balance impact
  /// (reverse the old version, apply the new), persists the row, and appends an
  /// audit-log entry describing exactly which fields changed.
  ///
  /// The transaction [type] may be changed; the caller is responsible for
  /// clearing fields that are no longer relevant to the new type via the
  /// matching `clear*` flags. Nullable fields are cleared the same way.
  Future<void> updateTransaction(
    String id, {
    txm.TxType? type,
    double? amount,
    String? fromAccountId,
    String? toAccountId,
    String? category,
    String? contact,
    String? note,
    DateTime? date,
    List<txm.TxItem>? items,
    bool clearFromAccount = false,
    bool clearToAccount = false,
    bool clearCategory = false,
    bool clearContact = false,
    bool clearNote = false,
  }) async {
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final old = _transactions[idx];
    final updated = old.copyWith(
      type: type,
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      category: category,
      contact: contact,
      note: note,
      date: date,
      items: items,
      clearFromAccount: clearFromAccount,
      clearToAccount: clearToAccount,
      clearCategory: clearCategory,
      clearContact: clearContact,
      clearNote: clearNote,
    );

    // Net ledger change = reverse the old version, then apply the new one.
    final net = <String, double>{};
    _balanceDeltas(old).forEach((k, v) => net[k] = (net[k] ?? 0) - v);
    _balanceDeltas(updated).forEach((k, v) => net[k] = (net[k] ?? 0) + v);

    // Guard: no involved account may end up negative.
    for (final e in net.entries) {
      if (e.value >= 0) continue;
      final acc = accountById(e.key);
      if (acc != null && acc.balance + e.value < 0) {
        throw 'Insufficient balance in ${acc.name}.';
      }
    }

    for (final e in net.entries) {
      if (e.value != 0) await _updateBalance(e.key, e.value);
    }

    final db = await DBHelper.instance.database;
    await db.update('transactions', updated.toMap(),
        where: 'id = ?', whereArgs: [id]);
    _transactions[idx] = updated;

    final changes = _diffTx(old, updated);
    if (changes.isNotEmpty) {
      final log = TxEditLog(
        id: _uuid.v4(),
        txId: id,
        editedAt: DateTime.now(),
        changes: changes,
      );
      await db.insert('tx_edit_logs', log.toMap());
    }
    notifyListeners();
  }

  /// Human-readable before→after diff of the fields relevant to a transaction.
  List<TxFieldChange> _diffTx(txm.Transaction a, txm.Transaction b) {
    final out = <TxFieldChange>[];
    void cmp(String field, String before, String after) {
      if (before != after) {
        out.add(TxFieldChange(field: field, before: before, after: after));
      }
    }

    String acc(String? id) => id == null ? '—' : (accountById(id)?.name ?? '—');
    final df = DateFormat('MMM d, y');

    cmp('Type', a.type.label, b.type.label);
    cmp('Amount', Money.format(a.amount), Money.format(b.amount));
    cmp('From', acc(a.fromAccountId), acc(b.fromAccountId));
    cmp('To', acc(a.toAccountId), acc(b.toAccountId));
    cmp('Category', a.category ?? '—', b.category ?? '—');
    cmp('Contact', a.contact ?? '—', b.contact ?? '—');
    cmp('Note', a.note ?? '—', b.note ?? '—');
    cmp('Date', df.format(a.date), df.format(b.date));
    cmp('Items', '${a.items.length}', '${b.items.length}');
    return out;
  }

  /// Edit history for a transaction, newest first.
  Future<List<TxEditLog>> editLogsFor(String txId) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query('tx_edit_logs',
        where: 'txId = ?', whereArgs: [txId], orderBy: 'editedAt DESC');
    return rows.map(TxEditLog.fromMap).toList();
  }

  Future<void> _writeTx(txm.Transaction tx) async {
    final db = await DBHelper.instance.database;
    await db.insert('transactions', tx.toMap());
    _transactions.insert(0, tx);
  }

  // -------------------- GOALS --------------------
  Future<Goal> addGoal({
    required String name,
    required double targetAmount,
    double? allocationPct,
    DateTime? targetDate,
  }) async {
    final db = await DBHelper.instance.database;
    // Term is always derived from the target amount vs current savings capacity.
    final autoTerm = GoalTermX.autoFrom(targetAmount, effectiveMonthlySavings());
    final g = Goal(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      savedAmount: 0,
      term: autoTerm,
      allocationPct: allocationPct ?? autoTerm.defaultAllocationPct,
      createdAt: DateTime.now(),
      targetDate: targetDate,
    );
    await db.insert('goals', g.toMap());
    _goals.insert(0, g);
    notifyListeners();
    return g;
  }

  Future<void> contributeToGoal(String goalId, double amount) async {
    final db = await DBHelper.instance.database;
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return;
    final updated = _goals[idx].copyWith(
      savedAmount: _goals[idx].savedAmount + amount,
    );
    _goals[idx] = updated;
    await db.update('goals', updated.toMap(),
        where: 'id = ?', whereArgs: [goalId]);
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    final db = await DBHelper.instance.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  // -------------------- DEBTS --------------------
  Future<Debt> addDebt({
    required DebtDirection direction,
    required double amount,
    required String contact,
    String? description,
    DateTime? dueDate,
  }) async {
    final db = await DBHelper.instance.database;
    final debt = Debt(
      id: _uuid.v4(),
      direction: direction,
      amount: amount,
      contact: contact,
      description: description,
      createdAt: DateTime.now(),
      dueDate: dueDate,
    );
    await db.insert('debts', debt.toMap());
    _debts.insert(0, debt);
    notifyListeners();
    return debt;
  }

  Future<void> settleDebt(String debtId, String accountId) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final acc  = accountById(accountId);
    if (acc == null) throw 'Account not found';

    if (debt.direction == DebtDirection.iOwe) {
      if (acc.balance < debt.amount) {
        throw 'Insufficient balance in ${acc.name}.';
      }
      await _writeTx(txm.Transaction(
        id: _uuid.v4(),
        type: txm.TxType.expense,
        amount: debt.amount,
        fromAccountId: accountId,
        category: 'Debt',
        contact: debt.contact,
        note: debt.description ?? 'Settled: ${debt.contact}',
        date: DateTime.now(),
      ));
      await _updateBalance(accountId, -debt.amount);
    } else {
      await _writeTx(txm.Transaction(
        id: _uuid.v4(),
        type: txm.TxType.income,
        amount: debt.amount,
        toAccountId: accountId,
        contact: debt.contact,
        note: debt.description ?? 'Received from: ${debt.contact}',
        date: DateTime.now(),
      ));
      await _updateBalance(accountId, debt.amount);
    }

    final db = await DBHelper.instance.database;
    await db.delete('debts', where: 'id = ?', whereArgs: [debtId]);
    _debts.removeWhere((d) => d.id == debtId);
    notifyListeners();
  }

  Future<void> deleteDebt(String id) async {
    final db = await DBHelper.instance.database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
    _debts.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  // -------------------- RESET --------------------
  Future<void> clearAllData() async {
    final db = await DBHelper.instance.database;
    await db.delete('transactions');
    await db.delete('tx_edit_logs');
    await db.delete('accounts');
    await db.delete('goals');
    await db.delete('debts');
    await db.delete('contacts');
    _transactions.clear();
    _accounts.clear();
    _goals.clear();
    _debts.clear();
    _contacts.clear();
    await _seedDefaultAccounts();
    notifyListeners();
  }

  // -------------------- ANALYTICS --------------------
  double get totalBalance =>
      _accounts.fold(0.0, (s, a) => s + a.balance);

  double incomeForMonth(DateTime month, {String? contact}) {
    return _transactions
        .where((t) =>
            (t.type == txm.TxType.income ||
                t.type == txm.TxType.openingBalance) &&
            t.date.year == month.year &&
            t.date.month == month.month &&
            (contact == null || t.contact == contact))
        .fold(0.0, (s, t) => s + t.amount);
  }

  double expensesForMonth(DateTime month, {String? contact}) {
    return _transactions
        .where((t) =>
            (t.type == txm.TxType.expense || t.type == txm.TxType.debt) &&
            t.date.year == month.year &&
            t.date.month == month.month &&
            (contact == null || t.contact == contact))
        .fold(0.0, (s, t) => s + t.amount);
  }

  double savingsForMonth(DateTime month, {String? contact}) =>
      incomeForMonth(month, contact: contact) -
      expensesForMonth(month, contact: contact);

  double avgMonthlySavings({String? contact}) {
    if (_transactions.isEmpty) return 0;
    final cur = _currentMonthKey;
    final byMonth = <String, double>{};
    for (final t in _transactions) {
      // Opening balance is a one-time setup entry, not recurring income — exclude it.
      if (t.type == txm.TxType.openingBalance) continue;
      if (contact != null && t.contact != contact) continue;
      final key = '${t.date.year}-${t.date.month}';
      if (key == cur) continue; // exclude the current incomplete month
      byMonth.putIfAbsent(key, () => 0);
      if (t.type == txm.TxType.income) {
        byMonth[key] = byMonth[key]! + t.amount;
      } else if (t.type == txm.TxType.expense || t.type == txm.TxType.debt) {
        byMonth[key] = byMonth[key]! - t.amount;
      }
    }
    if (byMonth.isEmpty) return 0;
    final sum = byMonth.values.fold(0.0, (s, v) => s + v);
    return sum / byMonth.length;
  }

  double spendingDeltaPct(DateTime month, {String? contact}) {
    final prev = DateTime(month.year, month.month - 1);
    final cur = expensesForMonth(month, contact: contact);
    final pre = expensesForMonth(prev, contact: contact);
    if (pre <= 0) return cur > 0 ? 100 : 0;
    return ((cur - pre) / pre) * 100;
  }

  Map<String, double> categoryBreakdown(DateTime month, {String? contact}) {
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.type != txm.TxType.expense && t.type != txm.TxType.debt) continue;
      if (contact != null && t.contact != contact) continue;
      final c = t.category ?? 'Other';
      map[c] = (map[c] ?? 0) + t.amount;
    }
    return map;
  }

  double categoryDelta(String category, DateTime month, {String? contact}) {
    final prev = DateTime(month.year, month.month - 1);
    final cur = categoryBreakdown(month, contact: contact)[category] ?? 0;
    final pre = categoryBreakdown(prev, contact: contact)[category] ?? 0;
    return cur - pre;
  }

  ({double cash, double card}) cashVsCard(DateTime month, {String? contact}) {
    double cash = 0, card = 0;
    for (final t in _transactions) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.type != txm.TxType.expense && t.type != txm.TxType.debt) continue;
      if (contact != null && t.contact != contact) continue;
      final acc = accountById(t.fromAccountId);
      if (acc == null) continue;
      if (acc.type == AccountType.bank) {
        card += t.amount;
      } else if (acc.type == AccountType.wallet) {
        cash += t.amount;
      }
    }
    return (cash: cash, card: card);
  }

  /// Key for the current (still-running) month — excluded from all averages.
  String get _currentMonthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}';
  }

  /// Number of fully-completed calendar months that have any expense or income data.
  int completedMonthsOfData() {
    final cur = _currentMonthKey;
    final keys = <String>{};
    for (final t in _transactions) {
      if (t.type == txm.TxType.openingBalance) continue;
      final key = '${t.date.year}-${t.date.month}';
      if (key != cur) keys.add(key);
    }
    return keys.length;
  }

  /// True once at least one full calendar month of real transactions exists.
  bool get hasEnoughData => completedMonthsOfData() >= 1;

  /// Average monthly expenses from *completed* months only.
  /// Excludes the current (still-running) month to avoid partial-month distortion.
  double avgMonthlyExpenses() {
    if (_transactions.isEmpty) return 0;
    final cur = _currentMonthKey;
    final byMonth = <String, double>{};
    for (final t in _transactions) {
      if (t.type != txm.TxType.expense && t.type != txm.TxType.debt) continue;
      final key = '${t.date.year}-${t.date.month}';
      if (key == cur) continue; // skip current incomplete month
      byMonth[key] = (byMonth[key] ?? 0) + t.amount;
    }
    if (byMonth.isEmpty) return 0;
    return byMonth.values.fold(0.0, (s, v) => s + v) / byMonth.length;
  }

  /// Best estimate of monthly savings capacity.
  /// - With salary: salary − avg completed-month expenses (forward-looking, stable).
  /// - Without salary: avg completed-month (income − expenses), opening balance excluded.
  /// Returns 0 when there is not yet enough data (no completed month and no salary).
  double effectiveMonthlySavings() {
    final total = monthlySalary;
    if (total > 0) {
      // Salary path: always usable. If no expense history yet, expenses = 0 (optimistic).
      return total - avgMonthlyExpenses();
    }
    // Transaction-history path: only meaningful after ≥1 completed month.
    if (!hasEnoughData) return 0;
    return avgMonthlySavings();
  }

  /// 50/30/20 budgeting rule breakdown based on salary.
  /// Returns null when no salary is set.
  ({double needs, double wants, double savings})? budgetRule5030() {
    final total = monthlySalary;
    if (total <= 0) return null;
    return (
      needs:   total * 0.50,
      wants:   total * 0.30,
      savings: total * 0.20,
    );
  }

  /// Actual savings rate this month relative to salary.
  double? savingsRatePct(DateTime month) {
    final total = monthlySalary;
    if (total <= 0) return null;
    final saved = savingsForMonth(month);
    return (saved / total) * 100;
  }

  List<txm.Transaction> filtered({
    DateTime? from,
    DateTime? to,
    String? category,
    bool? cashOnly,
    bool? cardOnly,
    txm.TxType? type,
    String? contact,
  }) {
    return _transactions.where((t) {
      if (from != null && t.date.isBefore(from)) return false;
      if (to != null && t.date.isAfter(to)) return false;
      if (category != null && t.category != category) return false;
      if (type != null && t.type != type) return false;
      if (contact != null && t.contact != contact) return false;
      if (cashOnly == true || cardOnly == true) {
        final acc = accountById(t.fromAccountId);
        if (acc == null) return false;
        if (cashOnly == true && acc.type != AccountType.wallet) return false;
        if (cardOnly == true && acc.type != AccountType.bank) return false;
      }
      return true;
    }).toList();
  }
}

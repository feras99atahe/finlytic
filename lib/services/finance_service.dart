import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/contact.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/transaction.dart' as txm;

class FinanceService extends ChangeNotifier {
  final _uuid = const Uuid();

  List<Account> _accounts = [];
  List<txm.Transaction> _transactions = [];
  List<Goal> _goals = [];
  List<Debt> _debts = [];
  List<Contact> _contacts = [];

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<txm.Transaction> get transactions => List.unmodifiable(_transactions);
  List<Goal> get goals => List.unmodifiable(_goals);
  List<Debt> get debts => List.unmodifiable(_debts);
  List<Contact> get contacts => List.unmodifiable(_contacts);

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

    if (_accounts.isEmpty) {
      await _seedDefaultAccounts();
    }
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
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await db.delete('transactions',
        where: 'fromAccountId = ? OR toAccountId = ?', whereArgs: [id, id]);
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
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
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
    required GoalTerm term,
    double? allocationPct,
    DateTime? targetDate,
  }) async {
    final db = await DBHelper.instance.database;
    final g = Goal(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      savedAmount: 0,
      term: term,
      allocationPct: allocationPct ?? term.defaultAllocationPct,
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
    final byMonth = <String, double>{};
    for (final t in _transactions) {
      if (contact != null && t.contact != contact) continue;
      final key = '${t.date.year}-${t.date.month}';
      byMonth.putIfAbsent(key, () => 0);
      if (t.type == txm.TxType.income || t.type == txm.TxType.openingBalance) {
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

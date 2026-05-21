import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/transaction.dart' as txm;

/// Encapsulates ALL business rules:
///   - Income → Bank or Safe
///   - Cash expense → Wallet only
///   - Card expense → Bank only
///   - Internal transfer → Safe → Wallet ONLY (the only allowed cash flow into the wallet)
///   - Debt → expense tied to a contact
///   - Opening Balance → seed transaction
class FinanceService extends ChangeNotifier {
  final _uuid = const Uuid();

  List<Account> _accounts = [];
  List<txm.Transaction> _transactions = [];
  List<Goal> _goals = [];
  List<Debt> _debts = [];

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<txm.Transaction> get transactions => List.unmodifiable(_transactions);
  List<Goal> get goals => List.unmodifiable(_goals);
  List<Debt> get debts => List.unmodifiable(_debts);

  List<Debt> get iOweDebts =>
      _debts.where((d) => d.direction == DebtDirection.iOwe).toList();
  List<Debt> get owesMeDebts =>
      _debts.where((d) => d.direction == DebtDirection.owesMe).toList();

  double get totalIOwe =>
      iOweDebts.fold(0.0, (s, d) => s + d.amount);
  double get totalOwesMe =>
      owesMeDebts.fold(0.0, (s, d) => s + d.amount);

  // -------------------- LOAD --------------------
  Future<void> load() async {
    final db = await DBHelper.instance.database;
    final aRows = await db.query('accounts', orderBy: 'createdAt ASC');
    final tRows = await db.query('transactions', orderBy: 'date DESC');
    final gRows = await db.query('goals', orderBy: 'createdAt DESC');
    final dRows = await db.query('debts', orderBy: 'createdAt DESC');

    _accounts     = aRows.map(Account.fromMap).toList();
    _transactions = tRows.map(txm.Transaction.fromMap).toList();
    _goals        = gRows.map(Goal.fromMap).toList();
    _debts        = dRows.map(Debt.fromMap).toList();

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
  }) async {
    final db = await DBHelper.instance.database;
    final acc = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: 0,
      createdAt: DateTime.now(),
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

  // -------------------- TRANSACTIONS --------------------

  /// Income: added to Bank OR Safe.
  Future<void> addIncome({
    required String toAccountId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final acc = accountById(toAccountId);
    if (acc == null) throw 'Account not found';
    if (acc.type == AccountType.wallet) {
      throw 'Income cannot be added directly to Wallet. Use Safe → Wallet transfer.';
    }
    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.income,
      amount: amount,
      toAccountId: toAccountId,
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

  /// Cash expense → must come from Wallet.
  /// Card expense → must come from Bank.
  Future<void> addExpense({
    required String fromAccountId,
    required double amount,
    required String category,
    String? note,
    DateTime? date,
  }) async {
    final acc = accountById(fromAccountId);
    if (acc == null) throw 'Account not found';
    if (acc.type == AccountType.safe) {
      throw 'Expenses cannot be paid from Safe. Use Wallet (cash) or Bank (card).';
    }
    if (acc.balance < amount) {
      throw 'Insufficient balance in ${acc.name}.';
    }

    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.expense,
      amount: amount,
      fromAccountId: fromAccountId,
      category: category,
      note: note,
      date: date ?? DateTime.now(),
    ));
    await _updateBalance(fromAccountId, -amount);
    notifyListeners();
  }

  /// Debt — categorized expense linked to a contact.
  Future<void> addDebtTransaction({
    required String fromAccountId,
    required double amount,
    required String contact,
    String? note,
    DateTime? date,
  }) async {
    final acc = accountById(fromAccountId);
    if (acc == null) throw 'Account not found';
    if (acc.type == AccountType.safe) {
      throw 'Pay debts from Wallet (cash) or Bank (card).';
    }
    if (acc.balance < amount) {
      throw 'Insufficient balance in ${acc.name}.';
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
    await _updateBalance(fromAccountId, -amount);
    notifyListeners();
  }

  /// Internal transfer — only Safe → Wallet allowed.
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
    if (safe.balance < amount) throw 'Insufficient balance in Safe.';

    await _writeTx(txm.Transaction(
      id: _uuid.v4(),
      type: txm.TxType.transfer,
      amount: amount,
      fromAccountId: safe.id,
      toAccountId: wallet.id,
      note: note ?? 'Safe → Wallet',
      date: date ?? DateTime.now(),
    ));
    await _updateBalance(safe.id, -amount);
    await _updateBalance(wallet.id, amount);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final db = await DBHelper.instance.database;
    final tx = _transactions.firstWhere((t) => t.id == id);

    // Reverse balances
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

  /// Settle a debt: converts it to a transaction and removes the debt record.
  ///
  /// - iOwe   settled → expense from [accountId] (I paid someone back)
  /// - owesMe settled → income to [accountId]   (they paid me back)
  Future<void> settleDebt(String debtId, String accountId) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final acc  = accountById(accountId);
    if (acc == null) throw 'Account not found';

    if (debt.direction == DebtDirection.iOwe) {
      if (acc.type == AccountType.safe) {
        throw 'Cannot pay from Safe. Use Wallet or Bank.';
      }
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
      // owesMe → income
      if (acc.type == AccountType.wallet) {
        throw 'Income cannot go directly to Wallet. Use Bank or Safe.';
      }
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

  // -------------------- ANALYTICS --------------------
  double get totalBalance =>
      _accounts.fold(0.0, (s, a) => s + a.balance);

  double incomeForMonth(DateTime month) {
    return _transactions
        .where((t) =>
            (t.type == txm.TxType.income ||
                t.type == txm.TxType.openingBalance) &&
            t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (s, t) => s + t.amount);
  }

  double expensesForMonth(DateTime month) {
    return _transactions
        .where((t) =>
            (t.type == txm.TxType.expense || t.type == txm.TxType.debt) &&
            t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (s, t) => s + t.amount);
  }

  /// S = I − E for a given month.
  double savingsForMonth(DateTime month) =>
      incomeForMonth(month) - expensesForMonth(month);

  /// Average monthly savings across all months that have any activity.
  double get avgMonthlySavings {
    if (_transactions.isEmpty) return 0;
    final byMonth = <String, double>{};
    for (final t in _transactions) {
      final key = '${t.date.year}-${t.date.month}';
      byMonth.putIfAbsent(key, () => 0);
      if (t.type == txm.TxType.income ||
          t.type == txm.TxType.openingBalance) {
        byMonth[key] = byMonth[key]! + t.amount;
      } else if (t.type == txm.TxType.expense || t.type == txm.TxType.debt) {
        byMonth[key] = byMonth[key]! - t.amount;
      }
    }
    if (byMonth.isEmpty) return 0;
    final sum = byMonth.values.fold(0.0, (s, v) => s + v);
    return sum / byMonth.length;
  }

  /// % delta in spending vs previous month.
  double spendingDeltaPct(DateTime month) {
    final prev = DateTime(month.year, month.month - 1);
    final cur = expensesForMonth(month);
    final pre = expensesForMonth(prev);
    if (pre <= 0) return cur > 0 ? 100 : 0;
    return ((cur - pre) / pre) * 100;
  }

  /// { category : amount } for expenses & debts in a month.
  Map<String, double> categoryBreakdown(DateTime month) {
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.type != txm.TxType.expense && t.type != txm.TxType.debt) continue;
      final c = t.category ?? 'Other';
      map[c] = (map[c] ?? 0) + t.amount;
    }
    return map;
  }

  /// Compare a category between this month and last month.
  double categoryDelta(String category, DateTime month) {
    final prev = DateTime(month.year, month.month - 1);
    final cur = categoryBreakdown(month)[category] ?? 0;
    final pre = categoryBreakdown(prev)[category] ?? 0;
    return cur - pre;
  }

  /// Cash vs Card expense split for a month.
  ({double cash, double card}) cashVsCard(DateTime month) {
    double cash = 0, card = 0;
    for (final t in _transactions) {
      if (t.date.year != month.year || t.date.month != month.month) continue;
      if (t.type != txm.TxType.expense && t.type != txm.TxType.debt) continue;
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

  /// Filtered transaction list.
  List<txm.Transaction> filtered({
    DateTime? from,
    DateTime? to,
    String? category,
    bool? cashOnly,
    bool? cardOnly,
    txm.TxType? type,
  }) {
    return _transactions.where((t) {
      if (from != null && t.date.isBefore(from)) return false;
      if (to != null && t.date.isAfter(to)) return false;
      if (category != null && t.category != category) return false;
      if (type != null && t.type != type) return false;
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

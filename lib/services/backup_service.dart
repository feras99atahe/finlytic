import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/transaction.dart' as txm;

/// Firestore layout:
///   users/{uid}/accounts/{id}
///   users/{uid}/transactions/{id}
///   users/{uid}/goals/{id}
///   users/{uid}/debts/{id}
class BackupService {
  final _db = FirebaseFirestore.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw 'You must be signed in to back up or restore.';
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _db.collection('users').doc(_uid).collection('accounts');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('users').doc(_uid).collection('transactions');
  CollectionReference<Map<String, dynamic>> get _goals =>
      _db.collection('users').doc(_uid).collection('goals');
  CollectionReference<Map<String, dynamic>> get _debts =>
      _db.collection('users').doc(_uid).collection('debts');

  // -------------------- BACKUP --------------------

  Future<void> backup({
    required List<Account> accounts,
    required List<txm.Transaction> transactions,
    required List<Goal> goals,
    required List<Debt> debts,
  }) async {
    final batch = _db.batch();
    for (final a in accounts)      batch.set(_accounts.doc(a.id), a.toMap());
    for (final t in transactions)  batch.set(_transactions.doc(t.id), t.toMap());
    for (final g in goals)         batch.set(_goals.doc(g.id), g.toMap());
    for (final d in debts)         batch.set(_debts.doc(d.id), d.toMap());
    await batch.commit();
  }

  // -------------------- RESTORE --------------------

  Future<void> restore() async {
    final results = await Future.wait([
      _accounts.get(),
      _transactions.get(),
      _goals.get(),
      _debts.get(),
    ]);

    final remoteAccounts     = results[0].docs.map((d) => Account.fromMap(d.data())).toList();
    final remoteTransactions = results[1].docs.map((d) => txm.Transaction.fromMap(d.data())).toList();
    final remoteGoals        = results[2].docs.map((d) => Goal.fromMap(d.data())).toList();
    final remoteDebts        = results[3].docs.map((d) => Debt.fromMap(d.data())).toList();

    // Treat the backup as missing only if *every* collection is empty, so a
    // user who happens to have no accounts (but has other data) isn't blocked.
    if (remoteAccounts.isEmpty &&
        remoteTransactions.isEmpty &&
        remoteGoals.isEmpty &&
        remoteDebts.isEmpty) {
      throw 'No backup found for this account.';
    }

    // Wrap the wipe + re-insert in a single transaction so a failure midway
    // rolls back and the existing local data is preserved (no data loss).
    final local = await DBHelper.instance.database;
    await local.transaction((txn) async {
      await txn.delete('accounts');
      await txn.delete('transactions');
      await txn.delete('goals');
      await txn.delete('debts');

      final batch = txn.batch();
      for (final a in remoteAccounts)     batch.insert('accounts', a.toMap());
      for (final t in remoteTransactions) batch.insert('transactions', t.toMap());
      for (final g in remoteGoals)        batch.insert('goals', g.toMap());
      for (final d in remoteDebts)        batch.insert('debts', d.toMap());
      await batch.commit(noResult: true);
    });
  }

  Future<DateTime?> lastBackupTime() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (!doc.exists) return null;
    final ts = doc.data()?['lastBackup'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  Future<void> _touchLastBackup() async {
    await _db.collection('users').doc(_uid).set(
        {'lastBackup': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> backupAndTouch({
    required List<Account> accounts,
    required List<txm.Transaction> transactions,
    required List<Goal> goals,
    required List<Debt> debts,
  }) async {
    await backup(
        accounts: accounts,
        transactions: transactions,
        goals: goals,
        debts: debts);
    await _touchLastBackup();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  static Database? _db;

  static const _kDbName = 'finlytic.db';
  static const _kDbVersion = 2;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _kDbName);
    return openDatabase(
      path,
      version: _kDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE accounts (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        type        TEXT NOT NULL,
        balance     REAL NOT NULL,
        createdAt   INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id              TEXT PRIMARY KEY,
        type            TEXT NOT NULL,
        amount          REAL NOT NULL,
        fromAccountId   TEXT,
        toAccountId     TEXT,
        category        TEXT,
        contact         TEXT,
        note            TEXT,
        date            INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_type ON transactions(type)');

    await db.execute('''
      CREATE TABLE goals (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        targetAmount    REAL NOT NULL,
        savedAmount     REAL NOT NULL,
        term            TEXT NOT NULL,
        allocationPct   REAL NOT NULL,
        createdAt       INTEGER NOT NULL,
        targetDate      INTEGER
      )
    ''');

    await _createDebtsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDebtsTable(db);
    }
  }

  Future<void> _createDebtsTable(Database db) async {
    await db.execute('''
      CREATE TABLE debts (
        id          TEXT PRIMARY KEY,
        direction   TEXT NOT NULL,
        amount      REAL NOT NULL,
        contact     TEXT NOT NULL,
        description TEXT,
        createdAt   INTEGER NOT NULL,
        dueDate     INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_debt_direction ON debts(direction)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

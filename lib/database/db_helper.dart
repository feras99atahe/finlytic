import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  static Database? _db;

  static const _kDbName = 'finlytic.db';
  static const _kDbVersion = 6;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path;
    if (kIsWeb) {
      path = _kDbName; // web uses the name directly (stored in IndexedDB)
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _kDbName);
    }
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
        createdAt   INTEGER NOT NULL,
        currency    TEXT NOT NULL DEFAULT 'USD',
        bankName    TEXT,
        notes       TEXT
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
        date            INTEGER NOT NULL,
        items           TEXT
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
    await _createContactsTable(db);
    await _createEditLogsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDebtsTable(db);
    }
    if (oldVersion < 3) {
      await _createContactsTable(db);
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD'");
      await db.execute('ALTER TABLE accounts ADD COLUMN bankName TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN notes TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE transactions ADD COLUMN items TEXT');
    }
    if (oldVersion < 6) {
      await _createEditLogsTable(db);
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

  Future<void> _createEditLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE tx_edit_logs (
        id        TEXT PRIMARY KEY,
        txId      TEXT NOT NULL,
        editedAt  INTEGER NOT NULL,
        changes   TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_editlog_tx ON tx_edit_logs(txId)');
  }

  Future<void> _createContactsTable(Database db) async {
    await db.execute('''
      CREATE TABLE contacts (
        id        TEXT PRIMARY KEY,
        name      TEXT NOT NULL,
        phone     TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_contact_name ON contacts(name)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

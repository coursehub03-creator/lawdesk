import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

import 'client_db.dart';
import 'cases_db.dart';
import 'sessions_db.dart';
import 'notification_db.dart';
import 'evidence_db.dart';
import 'verdict_db.dart';
import 'witness_db.dart';

class DBHelper {
  /// Backward-compatible singleton accessor.
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;
  static final Logger _logger = Logger();

  /// تهيئة sqflite مرة واحدة
  static void initialize() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    initialize(); // تأكيد التهيئة
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    final dbDir = await databaseFactory.getDatabasesPath();
    final path = join(dbDir, 'lawdesk.db');

    return await openDatabase(
      path,
      version: 18,
      onOpen: (db) async {
        // Run lightweight migrations that must apply even when the DB version
        // didn't change (e.g., user already on the latest version).
        try {
          await WitnessDB.migrateTable(db);
        } catch (e, st) {
          _logger.w(
            'onOpen: WitnessDB.migrateTable failed',
            error: e,
            stackTrace: st,
          );
        }
      },
      onCreate: (db, version) async {
        _logger.i('onCreate: إنشاء قاعدة البيانات لأول مرة');
        await _createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        _logger.i('onUpgrade: ترقية القاعدة من $oldVersion إلى $newVersion');
        await _createAllTables(db);
        await _runMigrations(db, oldVersion, newVersion);
      },
    );
  }

  /// ✅ ترقية آمنة بدون حذف بيانات (إضافة أعمدة ناقصة فقط).
  static Future<void> _runMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // SQLite لا يدعم IF NOT EXISTS للأعمدة، لذلك نستخدم try/catch.
    try {
      await db.execute("ALTER TABLE cases ADD COLUMN firebase_client_id TEXT;");
    } catch (_) {}

    try {
      await db.execute("ALTER TABLE cases ADD COLUMN clientId INTEGER;");
    } catch (_) {}

    // vXX: أعمدة قديمة قد تكون ناقصة في بعض الأجهزة
    for (final stmt in <String>[
      "ALTER TABLE cases ADD COLUMN fileNumber TEXT;",
      "ALTER TABLE cases ADD COLUMN caseType TEXT;",
      "ALTER TABLE cases ADD COLUMN court TEXT;",
      "ALTER TABLE cases ADD COLUMN startDate TEXT;",
      "ALTER TABLE cases ADD COLUMN notes TEXT;",
      "ALTER TABLE cases ADD COLUMN isSynced INTEGER DEFAULT 0;",
      "ALTER TABLE cases ADD COLUMN firebase_id TEXT;",
    ]) {
      try {
        await db.execute(stmt);
      } catch (_) {}
    }

    // Witnesses table migrations (case_id/firebase_case_id naming fix)
    try {
      await WitnessDB.migrateTable(db);
    } catch (e, st) {
      _logger.w(
        '_runMigrations: WitnessDB.migrateTable failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _createAllTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT,
          pin TEXT,
          isSynced INTEGER DEFAULT 0
        );
      ''');
      _logger.i('تم إنشاء جدول المستخدمين');

      final users = await db.query('users');
      if (users.isEmpty) {
        await db.insert('users', {'username': 'admin', 'pin': '1234'});
        _logger.i('تم إدراج المستخدم admin');
      }

      await ClientDB.createTable(db);
      await CaseDB.createTable(db);
      await SessionDB.createTable(db);
      await NotificationDB.createTable(db);
      await EvidenceDB.createTable(db);
      await WitnessDB.createTable(db);
      await VerdictDB.createTable(db);

      // ✅ إنشاء جدول pending_actions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_actions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id TEXT,
          action TEXT
        );
      ''');
      _logger.i('تم إنشاء جدول pending_actions');

      _logger.i('تم إنشاء كل الجداول المطلوبة بنجاح');
    } catch (e, stackTrace) {
      _logger.e(
        'حدث خطأ أثناء إنشاء الجداول',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<bool> verifyPin(String pin) async {
    final db = await database;
    final result = await db.query('users', where: 'pin = ?', whereArgs: [pin]);
    return result.isNotEmpty;
  }
}

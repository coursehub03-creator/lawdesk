import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import '../model/client_model.dart';
import 'db_helper.dart';

class ClientDB {
  static final Logger _logger = Logger();

  /// إنشاء جدول العملاء في SQLite
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT, -- هذا هو localId (ID محلي أوتوماتيكي)
        firebase_id TEXT,    -- معرف Supabase
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        isSynced INTEGER DEFAULT 0
      );
    ''');
  }

  /// إدخال عميل جديد
  static Future<int> insertClient(Client client) async {
    try {
      final db = await DBHelper.database;
      return await db.insert('clients', client.toMapLocal());
    } catch (e, stackTrace) {
      _logger.e('خطأ أثناء إدخال العميل', error: e, stackTrace: stackTrace);
      return -1;
    }
  }

  /// جلب جميع العملاء
  static Future<List<Client>> getClients() async {
    final db = await DBHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('clients');
    return maps.map((map) => Client.fromMapLocal(map)).toList();
  }

  /// جلب العملاء غير المتزامنين مع Supabase
  static Future<List<Client>> getUnsyncedClients() async {
    final db = await DBHelper.database;
    final maps = await db.query(
      'clients',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return maps.map((map) => Client.fromMapLocal(map)).toList();
  }

  /// تحديث حالة العميل بأنه تم رفعه إلى Supabase
  static Future<void> markClientAsSynced(int localId) async {
    final db = await DBHelper.database;
    await db.update(
      'clients',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// تحديث بيانات العميل (محلي فقط)
 static Future<int> updateClient(Client client) async {
  final db = await DBHelper.database;
  return await db.update(
    'clients',
    client.toMapLocal(),
    where: 'id = ?',
    whereArgs: [client.localId], // ✅ استخدم localId بدل id
  );
}


  /// حذف العميل
  static Future<int> deleteClient(int localId) async {
    final db = await DBHelper.database;
    return await db.delete('clients', where: 'id = ?', whereArgs: [localId]);
  }

  /// استيراد من Supabase إذا لم يكن موجودًا محليًا (بناءً على firebase_id)
  static Future<void> importClientIfNotExists(Client client) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'clients',
      where: 'firebase_id = ?',
      whereArgs: [client.id],
    );

    if (result.isEmpty) {
      await db.insert('clients', client.toMapLocal());
    }
  }
}

// lib/local/client_dao.dart
import 'package:sqflite/sqflite.dart';
import '../database/local_db.dart';
import '../model/client_model.dart';

class ClientDao {
  /// إدخال عميل جديد
  static Future<int> insertClient(Client client) async {
    final db = await LocalDb.instance.database;
    return await db.insert(
      'clients',
      client.toMapLocal(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// تحديث عميل
  static Future<int> updateClient(Client client) async {
    final db = await LocalDb.instance.database;
    return await db.update(
      'clients',
      client.toMapLocal(),
      where: 'id = ?',
      whereArgs: [client.localId], // ✅ التحديث دايماً بالـ localId
    );
  }

  /// جلب عميل حسب الـ id السحابي (firebase_id في الجدول)
  static Future<Client?> getClientBySupabaseId(String supabaseId) async {
    final db = await LocalDb.instance.database;
    final result = await db.query(
      'clients',
      where: 'firebase_id = ?',
      whereArgs: [supabaseId],
    );
    if (result.isNotEmpty) {
      return Client.fromMapLocal(result.first);
    }
    return null;
  }

  /// حذف عميل
  static Future<int> deleteClient(int localId) async {
    final db = await LocalDb.instance.database;
    return await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// جلب كل العملاء
  static Future<List<Client>> getAllClients() async {
    final db = await LocalDb.instance.database;
    final result = await db.query('clients');
    return result.map((e) => Client.fromMapLocal(e)).toList();
  }

  /// 🔹 تحديث العميل بحيث نقدر نعلّمه كمُتزامِن بعد نجاح العملية على السحابة
  static Future<void> markClientAsSynced(int localId) async {
    final db = await LocalDb.instance.database;
    await db.update(
      'clients',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
}

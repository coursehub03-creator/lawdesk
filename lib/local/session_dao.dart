import 'package:sqflite/sqflite.dart';
import '../database/local_db.dart';
import '../model/session_model.dart';

class SessionDao {
  static Future<int> insertSession(SessionModel session) async {
    final db = await LocalDb.instance.database;
    return await db.insert(
      'sessions',
      session.toMapLocal(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updateSession(SessionModel session) async {
    final db = await LocalDb.instance.database;
    return await db.update(
      'sessions',
      session.toMapLocal(),
      where: 'local_id = ?',
      whereArgs: [session.localId],
    );
  }

  static Future<List<SessionModel>> fetchSessionsByCaseId(String caseId) async {
    final db = await LocalDb.instance.database;
    final maps = await db.query(
      'sessions',
      where: 'case_id = ?',
      whereArgs: [caseId],
    );

    return maps.map((e) => SessionModel.fromMapLocal(e)).toList();
  }
}

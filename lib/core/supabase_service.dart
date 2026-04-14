import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import '../database/local_db.dart';

import '../model/client_model.dart';
import '../model/case_model.dart';
import '../model/session_model.dart';
import '../model/verdict_model.dart';
import '../model/evidence_model.dart';
import '../model/witness_model.dart';
import '../model/notification_model.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Logger _logger = Logger();

  // === Clients ===
  static Future<void> addClient(Client client) async {
    await ClientService.addClient(client); // إعادة استخدام الخدمة
  }

  static Future<List<Client>> fetchClients() async {
    return ClientService.fetchClients();
  }

  // === Cases ===
  static Future<void> addCase(CaseModel item) async {
    final db = await LocalDb.instance.database;
    await db.insert('cases', {...item.toMapLocal(), 'is_synced': 0});

    try {
      await _client.from('cases').insert(item.toMapSupabase());
      await db.update('cases', {'is_synced': 1},
          where: 'id = ?', whereArgs: [item.id]);
    } catch (e) {
      _logger.e('إضافة قضية فشلت: $e');
    }
  }

  static Future<List<CaseModel>> fetchCases() async {
    final db = await LocalDb.instance.database;
    final local = await db.query('cases');

    try {
      final response = await _client.from('cases').select();
      final remote =
          (response as List).map((e) => CaseModel.fromMapSupabase(e)).toList();

      for (var c in remote) {
        await db.insert('cases', c.toMapLocal(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return remote;
    } catch (e) {
      _logger.w('⚠️ جلب القضايا من السحابة فشل، استخدام المحلي فقط');
      return local.map((e) => CaseModel.fromMapLocal(e)).toList();
    }
  }

  // === Sessions (مرتبطة بالقضية بـ case_id) ===
  static Future<void> addSession(SessionModel item) async {
    final db = await LocalDb.instance.database;
    await db.insert('sessions', {...item.toMapLocal(), 'is_synced': 0});

    try {
      await _client.from('sessions').insert(item.toMapSupabase());
      await db.update('sessions', {'is_synced': 1},
          where: 'id = ?', whereArgs: [item.id]);
    } catch (e) {
      _logger.e('إضافة جلسة فشلت: $e');
    }
  }

  static Future<List<SessionModel>> fetchSessions(String caseId) async {
    final db = await LocalDb.instance.database;
    final local =
        await db.query('sessions', where: 'case_id = ?', whereArgs: [caseId]);

    try {
      final response =
          await _client.from('sessions').select().eq('case_id', caseId);
      final remote = (response as List)
          .map((e) => SessionModel.fromMapSupabase(e))
          .toList();

      for (var s in remote) {
        await db.insert('sessions', s.toMapLocal(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return remote;
    } catch (e) {
      _logger.w('⚠️ جلب الجلسات من السحابة فشل، استخدام المحلي فقط');
      return local.map((e) => SessionModel.fromMapLocal(e)).toList();
    }
  }

  // باقي الجداول (Verdicts, Evidence, Witnesses, Notifications)
  // ممكن نطبق عليهم نفس النمط بنفس الكود أعلاه...
}

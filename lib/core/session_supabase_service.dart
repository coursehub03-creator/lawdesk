import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

import '../model/session_model.dart';
import '../database/sessions_db.dart'; // SQLite (DBHelper)
import '../core/id.dart';

final logger = Logger();

class SessionSupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// ✅ Offline-first (id موحّد):
  /// - إذا كانت الجلسة جديدة ولم تملك firebaseId، نولّد UUID محلياً.
  /// - نستخدم upsert حتى لا تتكرر السجلات عند إعادة المحاولة.
  static Future<SessionModel> addSession(SessionModel session) async {
    try {
      final unifiedId = (session.firebaseId == null || session.firebaseId!.trim().isEmpty)
          ? generateId()
          : session.firebaseId!.trim();

      // ✅ رفع للجلسة على Supabase (بنفس id)
      final response = await _client
          .from('sessions')
          .upsert({'id': unifiedId, ...session.toMapSupabase()}, onConflict: 'id')
          .select()
          .single();

      final updated = session.copyWith(
        firebaseId: response['id'].toString(),
        isSynced: true,
      );

      // ✅ تحديث/إدراج محلي "مرة واحدة فقط"
      if (session.localId != null) {
        await SessionDB.updateSession(
          updated.copyWith(localId: session.localId),
        );
        // (markSessionAsSynced) غالبًا زائد، لكن نخليه إذا DB عندك يحتاجه
        await SessionDB.markSessionAsSynced(session.localId!);

        logger.i('☁️✅ تم رفع الجلسة وتحديث المحلي (firebaseId=${updated.firebaseId}, localId=${session.localId})');
        return updated.copyWith(localId: session.localId);
      } else {
        final localId = await SessionDB.insertSession(
          updated.copyWith(isSynced: true),
        );

        logger.i('☁️✅ تم رفع الجلسة وإدراج نسخة واحدة محليًا (firebaseId=${updated.firebaseId}, localId=$localId)');
        return updated.copyWith(localId: localId);
      }
    } on PostgrestException catch (e) {
      logger.w('⚠️ فشل رفع الجلسة إلى Supabase: ${e.message}');

      // ✅ fallback: حفظ محلي مرة واحدة فقط إذا كانت جديدة
      if (session.localId == null) {
        final localId = await SessionDB.insertSession(
          session.copyWith(isSynced: false),
        );
        logger.i('💾 تم حفظ الجلسة محليًا فقط (localId=$localId) بسبب فشل السحابة');
        return session.copyWith(localId: localId, isSynced: false);
      }

      // إذا كانت موجودة محليًا أصلًا → نرجعها كما هي غير متزامنة
      return session.copyWith(isSynced: false);
    } catch (e, stackTrace) {
      logger.e('❌ خطأ غير متوقع أثناء رفع الجلسة', error: e, stackTrace: stackTrace);

      // ✅ fallback محلي مرة واحدة فقط إذا كانت جديدة
      if (session.localId == null) {
        final localId = await SessionDB.insertSession(
          session.copyWith(isSynced: false),
        );
        logger.i('💾 تم حفظ الجلسة محليًا فقط (localId=$localId) بسبب خطأ غير متوقع');
        return session.copyWith(localId: localId, isSynced: false);
      }

      return session.copyWith(isSynced: false);
    }
  }

  /// تحديث جلسة
  static Future<void> updateSession(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('sessions').update(data).eq('id', id);
      logger.i('☁️ تم تحديث الجلسة على Supabase');
    } catch (e) {
      logger.e('⚠️ خطأ في updateSession', error: e);
    }
  }

  /// حذف جلسة
  static Future<void> deleteSession(String id) async {
    try {
      await _client.from('sessions').delete().eq('id', id);
      logger.i('☁️ تم حذف الجلسة من Supabase');
    } catch (e) {
      logger.e('⚠️ خطأ في deleteSession', error: e);
    }
  }

  /// جلب الجلسات المرتبطة بقضية من Supabase
  static Future<List<SessionModel>> fetchSessionsByCaseId(String firebaseCaseId) async {
    try {
      final response = await _client
          .from('sessions')
          .select()
          .eq('case_id', firebaseCaseId) // ✅ فلترة إلزامية
          .order('date', ascending: true);

      logger.i('☁️ تم جلب ${(response as List).length} جلسات من Supabase');
      return (response as List)
          .map((e) => SessionModel.fromMapSupabase(e))
          .toList();
    } catch (e) {
      logger.e('⚠️ خطأ في fetchSessionsByCaseId', error: e);
      return [];
    }
  }
}

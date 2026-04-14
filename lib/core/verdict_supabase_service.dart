import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/verdict_model.dart';
import 'package:logger/logger.dart';
import 'package:lawdesk_flutter/core/id.dart';

final logger = Logger();

class VerdictSupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// إضافة منطوق جديد وإرجاع نسخة محدثة تحتوي على firebaseId
  static Future<VerdictModel?> addVerdict(VerdictModel verdict) async {
    try {
      // ✅ Offline-first stable ID: generate once and send it as `id`.
      // Without sending `id`, Supabase generates a new one every time,
      // which creates duplicates on every sync.
      final unifiedId = (verdict.firebaseId != null && verdict.firebaseId!.trim().isNotEmpty)
          ? verdict.firebaseId!.trim()
          : generateId();

      final map = <String, dynamic>{
        'id': unifiedId,
        ...verdict.toMapSupabase(),
      };

      if (verdict.firebaseSessionId == null || verdict.firebaseSessionId!.isEmpty) {
        logger.w('❌ لا يمكن رفع منطوق حكم بدون firebaseSessionId');
        return null;
      }

      final response = await _client
          .from('verdicts')
          .upsert(map, onConflict: 'id')
          .select()
          .single();

      logger.i('✅ تم إضافة منطوق الحكم إلى Supabase');
      return VerdictModel.fromMapSupabase(response);
    } catch (e, st) {
      logger.e('❌ فشل إضافة منطوق الحكم إلى Supabase', error: e, stackTrace: st);
      return null;
    }
  }

  /// تحديث منطوق حكم
  static Future<void> updateVerdict(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client.from('verdicts').update(data).eq('id', id);
      logger.i('✅ تم تحديث منطوق الحكم في Supabase');
    } catch (e, st) {
      logger.e('❌ فشل تحديث منطوق الحكم', error: e, stackTrace: st);
    }
  }

  /// حذف منطوق حكم
  static Future<void> deleteVerdict(String id) async {
    try {
      await _client.from('verdicts').delete().eq('id', id);
      logger.i('✅ تم حذف منطوق الحكم من Supabase');
    } catch (e, st) {
      logger.e('❌ فشل حذف منطوق الحكم', error: e, stackTrace: st);
    }
  }

  /// استيراد منطوقات حسب معرف الجلسة
  static Future<List<VerdictModel>> fetchVerdictsBySession(
    String sessionId,
  ) async {
    try {
      final response = await _client
          .from('verdicts')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) =>
              VerdictModel.fromMapSupabase(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e, st) {
      logger.e('❌ فشل في fetchVerdictsBySession', error: e, stackTrace: st);
      return [];
    }
  }

  /// استيراد كل منطوقات الحكم (تستخدم في المزامنة العامة)
  static Future<List<VerdictModel>> fetchVerdicts() async {
    try {
      final response = await _client
          .from('verdicts')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => VerdictModel.fromMapSupabase(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (e, st) {
      logger.e('❌ فشل استيراد جميع منطوقات الحكم', error: e, stackTrace: st);
      return [];
    }
  }

  /// بث مباشر لتغييرات منطوقات الحكم في جلسة معينة
  static Stream<List<VerdictModel>> getVerdictsStream(String sessionId) {
    return _client
        .from('verdicts')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map((rows) => rows
            .map((item) => VerdictModel.fromMapSupabase(
                  Map<String, dynamic>.from(item),
                ))
            .toList());
  }
}

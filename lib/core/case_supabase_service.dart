import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/case_model.dart';
import 'package:logger/logger.dart';

class CaseSupabaseService {
  static final Logger _logger = Logger();
  static final SupabaseClient _client = Supabase.instance.client;

  /// إضافة / تحديث قضية (Offline-first)
  static Future<CaseModel?> upsertCase(CaseModel item) async {
    try {
      final response = await _client
          .from('cases')
          .upsert(item.toMapSupabase(), onConflict: 'id')
          .select()
          .single();

      return item.copyWith(
        firebaseId: response['id'].toString(),
        isSynced: true,
      );
    } catch (e) {
      _logger.e('❌ خطأ في upsertCase: $e');
      return null;
    }
  }

  /// حذف قضية
  static Future<void> deleteCase(String firebaseId) async {
    try {
      await _client.from('cases').delete().eq('id', firebaseId);
    } catch (e) {
      _logger.e('❌ خطأ في deleteCase: $e');
    }
  }

  /// جلب القضايا حسب العميل (صحيح)
  static Future<List<CaseModel>> fetchCasesByClientId(
    String firebaseClientId,
  ) async {
    try {
      final response = await _client
          .from('cases')
          .select()
          .eq('client_id', firebaseClientId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (e) => CaseModel.fromMapSupabase(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      _logger.e('❌ خطأ في fetchCasesByClientId: $e');
      return [];
    }
  }


  // ---------------------------------------------------------------------------
  // Backward-compatible API (used by older screens / SyncService)
  // ---------------------------------------------------------------------------

  /// Legacy name: addCase -> upsertCase
  static Future<CaseModel?> addCase(CaseModel item) async {
    return upsertCase(item);
  }

  /// Legacy: fetchCases -> fetch all cases
  static Future<List<CaseModel>> fetchCases() async {
    try {
      final response = await _client
          .from('cases')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => CaseModel.fromMapSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('خطأ في fetchCases: $e');
      return [];
    }
  }

  /// Legacy: updateCase wrapper
  static Future<void> updateCase(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('cases').update(data).eq('id', id);
    } catch (e) {
      _logger.e('خطأ في updateCase: $e');
    }
  }
}

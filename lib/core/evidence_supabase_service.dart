import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/id.dart';
import '../model/evidence_model.dart';

class EvidenceSupabaseService {
  static final Logger _logger = Logger();
  static final SupabaseClient _client = Supabase.instance.client;

  /// Offline-first upsert: uses [evidence.firebaseId] (UUID).
  /// IMPORTANT: [evidence.filePath] must be the *storage path* inside the bucket
  /// when uploading to Supabase.
  static Future<EvidenceModel?> upsertEvidence(EvidenceModel evidence) async {
    final id = (evidence.firebaseId ?? '').trim().isNotEmpty ? evidence.firebaseId!.trim() : generateId();
    final caseId = (evidence.firebaseCaseId ?? '').trim();
    if (caseId.isEmpty) {
      _logger.w('رفض upsertEvidence: firebaseCaseId فارغ (Orphan)');
      return null;
    }

    try {
      final payload = evidence.copyWith(firebaseId: id).toMapSupabase();
      final res = await _client
          .from('evidence')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();

      return evidence.copyWith(
        firebaseId: res['id']?.toString() ?? id,
        firebaseCaseId: res['case_id']?.toString() ?? caseId,
        filePath: res['file_path']?.toString() ?? evidence.filePath,
        type: res['type']?.toString() ?? evidence.type,
        uploadedAt: res['uploaded_at']?.toString() ?? evidence.uploadedAt,
        description: res['description']?.toString() ?? evidence.description,
        isSynced: true,
      );
    } on PostgrestException catch (e) {
      _logger.e('Supabase upsertEvidence PostgrestException: ${e.message}', error: e);
      return null;
    } catch (e, st) {
      _logger.e('Supabase upsertEvidence error', error: e, stackTrace: st);
      return null;
    }
  }

  /// Backward-compatible name used in some screens.
  static Future<EvidenceModel?> addEvidence(EvidenceModel evidence) => upsertEvidence(evidence);

  static Future<void> deleteEvidence(String id) async {
    try {
      await _client.from('evidence').delete().eq('id', id);
    } catch (e) {
      _logger.e('خطأ في حذف الدليل: $e');
    }
  }

  static Future<List<EvidenceModel>> fetchEvidenceByCaseId(String firebaseCaseId) async {
    try {
      final response = await _client
          .from('evidence')
          .select()
          .eq('case_id', firebaseCaseId)
          .order('uploaded_at', ascending: false);

      return (response as List)
          .map((data) => EvidenceModel.fromMapSupabase(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('خطأ في جلب الأدلة: $e');
      return [];
    }
  }

  /// Backward-compatible alias used by some older screens / sync code.
  static Future<List<EvidenceModel>> fetchByCaseId(String firebaseCaseId) =>
      fetchEvidenceByCaseId(firebaseCaseId);
}
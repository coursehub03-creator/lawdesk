import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/witness_model.dart';

class WitnessSupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> upsertWitness(WitnessModel witness) async {
    final payload = witness.toMapSupabase();

    // Most common schema: primary key is `id` (uuid)
    await _client.from('witnesses').upsert(payload, onConflict: 'id');
  }

  static Future<List<WitnessModel>> fetchWitnessesByCaseId(String firebaseCaseId) async {
    final res = await _client
        .from('witnesses')
        .select()
        .eq('case_id', firebaseCaseId)
        .order('created_at', ascending: true);

    // We don't always know the local case id here; caller can overwrite after fetch.
    return (res as List<dynamic>)
        .map((e) => WitnessModel.fromMapSupabase(e as Map<String, dynamic>, fallbackCaseId: 0))
        .toList();
  }

  static Future<void> deleteWitness(String witnessId) async {
    await _client.from('witnesses').delete().eq('id', witnessId);
  }
}

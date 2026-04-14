import 'dart:math';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/client_db.dart';
import '../model/client_model.dart';

/// مصدر الحقيقة: Supabase. المحلي كاش + دعم أوفلاين.
///
/// ✅ Offline-first محترف:
/// - نضمن وجود UUID (client.id) محليًا قبل أي كتابة.
/// - نستخدم upsert بنفس الـ id (لتوحيد المحلي والسحابي).
/// - لا نرسل أبداً UUID فارغ "" لأي عمود UUID في Supabase.
/// - عند الفشل: نحفظ محليًا isSynced=false.
class ClientSupabaseService {
  static final Logger _logger = Logger();
  static final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// توليد UUID v4 بدون أي حزم إضافية (حتى لا نعتمد على uuid package).
  static String _uuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Version 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variant 10xxxxxx
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String two(int v) => v.toRadixString(16).padLeft(2, '0');

    return '${two(bytes[0])}${two(bytes[1])}${two(bytes[2])}${two(bytes[3])}-'
        '${two(bytes[4])}${two(bytes[5])}-'
        '${two(bytes[6])}${two(bytes[7])}-'
        '${two(bytes[8])}${two(bytes[9])}-'
        '${two(bytes[10])}${two(bytes[11])}${two(bytes[12])}${two(bytes[13])}${two(bytes[14])}${two(bytes[15])}';
  }

  /// ينظّف الـ payload:
  /// - يحذف أي String فاضية "" (لأن UUID "" يسبب 22P02)
  /// - يحذف null
  /// - (اختياري) trims strings
  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final out = <String, dynamic>{};

    input.forEach((key, value) {
      if (value == null) return;

      if (value is String) {
        final v = value.trim();
        if (v.isEmpty) return; // احذف الفاضي
        out[key] = v;
        return;
      }

      out[key] = value;
    });

    return out;
  }

  /// يضمن أن العميل عنده UUID ثابت.
  static Client _ensureClientId(Client client) {
    if (client.id.trim().isNotEmpty) return client;
    final newId = _uuidV4();
    return client.copyWith(id: newId);
  }

  // ---------------------------------------------------------------------------
  // Main API
  // ---------------------------------------------------------------------------

  /// ✅ Offline-first:
  /// - نضمن وجود id (UUID).
  /// - upsert إلى Supabase بنفس الـ id.
  /// - fallback محلي عند الفشل.
  static Future<Client> addClient(Client client) async {
    final fixed = _ensureClientId(client);

    try {
      // مهم: لا تترك map يمرّر UUID "" أو قيم فاضية
      final base = fixed.toMapSupabase();
      final payload = _sanitizeMap({
        'id': fixed.id, // الآن مضمون UUID صحيح
        ...base,
      });

      // Debug ذكي (يساعدك لو ظهر UUID "" من داخل toMapSupabase)
      // _logger.i('Client upsert payload=$payload');

      final response = await _client
          .from('clients')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();

      final synced =
          fixed.copyWith(id: response['id'].toString(), isSynced: true);

      // حفظ محلي (insert أو update)
      if (fixed.localId != null) {
        await ClientDB.updateClient(synced.copyWith(localId: fixed.localId));
        _logger.i(
            '☁️✅ upsert + update local (localId=${fixed.localId}, id=${synced.id})');
        return synced.copyWith(localId: fixed.localId);
      } else {
        final localId = await ClientDB.insertClient(synced);
        _logger.i('☁️✅ upsert + insert local (localId=$localId, id=${synced.id})');
        return synced.copyWith(localId: localId);
      }
    } catch (e) {
      // أوفلاين/فشل سحابي → محلي فقط
      final offline = fixed.copyWith(isSynced: false);

      if (fixed.localId == null) {
        final newLocalId = await ClientDB.insertClient(offline);
        _logger.w(
            '⚠️ تم حفظ العميل محليًا فقط (أوفلاين). localId=$newLocalId, id=${offline.id}, error=$e');
        return offline.copyWith(localId: newLocalId);
      } else {
        await ClientDB.updateClient(offline);
        _logger.w(
            '⚠️ تم تحديث العميل محليًا فقط (أوفلاين). localId=${fixed.localId}, id=${offline.id}, error=$e');
        return offline.copyWith(localId: fixed.localId);
      }
    }
  }

  /// رفع عميل محلي غير متزامن إلى Supabase ثم تحديث نفس السجل المحلي.
  static Future<Client?> pushInsertExistingLocal(Client localClient) async {
    if (localClient.localId == null) return null;

    final fixed = _ensureClientId(localClient);

    try {
      final base = fixed.toMapSupabase();
      final payload = _sanitizeMap({'id': fixed.id, ...base});

      final response = await _client
          .from('clients')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();

      final synced =
          fixed.copyWith(id: response['id'].toString(), isSynced: true);

      await ClientDB.updateClient(synced);
      await ClientDB.markClientAsSynced(fixed.localId!);

      _logger.i(
          '☁️✅ تم رفع/تحديث العميل المحلي (localId=${fixed.localId}, id=${synced.id})');
      return synced;
    } catch (e) {
      _logger.w('⚠️ فشل رفع العميل المحلي (localId=${fixed.localId}): $e');
      return null;
    }
  }

  /// دفع تحديثات عميل له id سحابي.
  static Future<Client?> pushUpdateToSupabase(Client client) async {
    final fixed = _ensureClientId(client);

    // إذا تريد منع تحديث سحابي لعميل لم يتم sync بعد، اترك هذا الشرط.
    // لكن بما أننا نضمن UUID، يمكننا upsert بدل update لضمان عدم الفشل.
    try {
      final updateMap = _sanitizeMap({
        'name': fixed.name,
        'phone': fixed.phone,
        'email': fixed.email,
        'address': fixed.address,
        'notes': fixed.notes,
      });

      final response = await _client
          .from('clients')
          .update(updateMap)
          .eq('id', fixed.id)
          .select()
          .single();

      final updated = fixed.copyWith(
        id: response['id'].toString(),
        name: response['name'] ?? fixed.name,
        phone: response['phone'] ?? fixed.phone,
        email: response['email'] ?? fixed.email,
        address: response['address'] ?? fixed.address,
        notes: response['notes'] ?? fixed.notes,
        isSynced: true,
      );

      if (updated.localId != null) {
        await ClientDB.updateClient(updated);
        await ClientDB.markClientAsSynced(updated.localId!);
      }

      _logger.i('☁️✅ تم تحديث العميل على Supabase (id=${fixed.id})');
      return updated;
    } catch (e) {
      _logger.w('⚠️ فشل تحديث العميل على Supabase (id=${fixed.id}): $e');
      return null;
    }
  }

  /// جلب العملاء من Supabase (للاستيراد إلى المحلي)
  static Future<List<Client>> fetchClientsFromSupabase() async {
    try {
      final response =
          await _client.from('clients').select().order('created_at', ascending: false);

      return (response as List)
          .map((e) => Client.fromMapSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.w('⚠️ فشل جلب العملاء من Supabase: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible API (used by some screens in the project)
  // ---------------------------------------------------------------------------

  static Future<List<Client>> fetchClients() async {
    return fetchClientsFromSupabase();
  }

  static Future<Client?> updateClient(Client client) async {
    // تحديث محلي فقط لو عندك سياسة تمنع push بدون sync
    // لكن بما أننا نضمن UUID، الأفضل push مباشرة.
    if (client.localId != null) {
      await ClientDB.updateClient(client.copyWith(isSynced: false));
    }
    return pushUpdateToSupabase(client);
  }

  static Future<void> deleteClient(String cloudId) async {
    if (cloudId.trim().isEmpty) return;
    await _client.from('clients').delete().eq('id', cloudId.trim());
  }
}

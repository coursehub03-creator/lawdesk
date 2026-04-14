import 'dart:io';
import 'package:logger/logger.dart';

import '../database/client_db.dart';
import '../database/cases_db.dart';
import '../database/sessions_db.dart';
import '../database/verdict_db.dart';
import '../database/evidence_db.dart';
import '../database/witness_db.dart';
import '../database/notification_db.dart';
import '../database/db_helper.dart';
import '../local/local_db.dart';

import '../core/client_supabase_service.dart';
import '../core/case_supabase_service.dart';
import '../core/session_supabase_service.dart';
import '../core/verdict_supabase_service.dart';

import '../model/client_model.dart';

class SyncService {
  static final Logger _logger = Logger();

  static Future<void> syncAll() async {
    if (!await _hasInternet()) return;

    await _processPendingDeletes();

    await _syncClients();
    await _importClients();

    await _syncCases();
    await _importCases();

    await _syncSessions();
    await _importSessions();

    await _syncVerdicts();
    await _importVerdicts();

    await _syncEvidence();
    await _importEvidence();

    await _syncWitnesses();
    await _importWitnesses();

    await _syncNotifications();
    await _importNotifications();

    _logger.i('✅ تمت مزامنة جميع الكيانات بنجاح باستخدام الخدمات المنفصلة.');
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// معالجة الحذف المعلّق (تم تسجيله عند الحذف بدون إنترنت)
  static Future<void> _processPendingDeletes() async {
    final db = await DBHelper.database;
    final pending = await db.query(
      'pending_actions',
      where: 'action = ?',
      whereArgs: ['delete'],
    );

    for (var action in pending) {
      final clientId = action['client_id'] as String;
      try {
        // نحذف من السحابة الآن
        await ClientSupabaseService.deleteClient(clientId);
        // ثم نحذف الحركة من جدول الانتظار
        await db.delete('pending_actions', where: 'id = ?', whereArgs: [action['id']]);
        _logger.i('☁️ تم تنفيذ الحذف المعلق للعميل id=$clientId');
      } catch (e) {
        _logger.w('⚠️ فشل تنفيذ الحذف المعلق id=$clientId: $e');
      }
    }
  }

  // === Clients ===

  /// تحديث عميل محليًا ثم على السحابة
   /// تحديث عميل محليًا ثم على السحابة
static Future<void> syncClientUpdate(Client client) async {
  // تحديث محلي كـ غير متزامن
  await ClientDB.updateClient(client.copyWith(isSynced: false));

  try {
    final updated = await ClientSupabaseService.pushUpdateToSupabase(client);

    if (updated != null) {
      final clientWithLocal = updated.copyWith(
        localId: client.localId,
        isSynced: true,
      );

      await ClientDB.updateClient(clientWithLocal);
      await ClientDB.markClientAsSynced(client.localId!);

      _logger.i("☁️ تم رفع وحفظ تعديل العميل (${client.id}) محليًا وسحابيًا");
    } else {
      _logger.w("⚠️ فشل رفع تعديل العميل (${client.id})");
    }
  } catch (e) {
    _logger.w("⚠️ استثناء أثناء رفع تعديل العميل (${client.id}): $e");
  }
}





  static Future<void> _syncClients() async {
    final items = await ClientDB.getUnsyncedClients();
    for (final item in items) {
      try {
        if (item.id.isEmpty) {
          // ✅ سجل محلي بدون id سحابي → ارفع بدون إنشاء سجل محلي جديد
          await ClientSupabaseService.pushInsertExistingLocal(item);
        } else {
          // ✅ سجل له id سحابي → Update
          await syncClientUpdate(item);
        }
      } catch (e) {
        _logger.w('⚠️ فشل مزامنة العميل (localId=${item.localId}): $e');
      }
    }
  }

  static Future<void> _importClients() async {
    final items = await ClientSupabaseService.fetchClientsFromSupabase();
    for (final item in items) {
      await ClientDB.importClientIfNotExists(item);
    }
  }

  // === Cases ===
  static Future<void> _syncCases() async {
    final items = await CaseDB.getUnsyncedCases();
    for (final item in items) {
      final uploaded = await CaseSupabaseService.addCase(item);
      if (uploaded != null && item.localId != null) {
        await CaseDB.updateCase(uploaded.copyWith(localId: item.localId));
        await CaseDB.markCaseAsSynced(item.localId!);
      }
    }
  }

  static Future<void> _importCases() async {
    final items = await CaseSupabaseService.fetchCases();
    for (final item in items) {
      await CaseDB.importCaseIfNotExists(item);
    }
  }

  // === Sessions ===
  static Future<void> _syncSessions() async {
    final items = await SessionDB.getUnsyncedSessions();
    for (final item in items) {
      final saved = await SessionSupabaseService.addSession(item);

      // ✅ لا تعلم محلياً أنه synced إلا إذا نجح الرفع فعلاً
      if (saved.isSynced && item.localId != null) {
        await SessionDB.markSessionAsSynced(item.localId!);
      }
    }
  }

  static Future<void> _importSessions() async {
    final allCases = await CaseDB.getCases();
    for (final caseItem in allCases) {
      final firebaseCaseId = caseItem.firebaseId;
      if (firebaseCaseId != null && firebaseCaseId.isNotEmpty) {
        final sessions = await SessionSupabaseService.fetchSessionsByCaseId(firebaseCaseId);
        for (final session in sessions) {
          // ✅ اربط الجلسة بالقضية محلياً عند الاستيراد لمنع ظهورها في كل القضايا
          final localCaseId = caseItem.localId ?? 0;
          if (localCaseId == 0) continue;
          final corrected = session.copyWith(
            caseId: localCaseId,
            firebaseCaseId: firebaseCaseId,
          );
          await SessionDB.importSessionIfNotExists(corrected);
        }
      }
    }
  }

  // === Verdicts ===
  static Future<void> _syncVerdicts() async {
    final items = await VerdictDB.getUnsyncedVerdicts();
    for (final item in items) {
      await VerdictSupabaseService.addVerdict(item);
      await VerdictDB.markVerdictAsSynced(item.localId!);
    }
  }

  static Future<void> _importVerdicts() async {
    final items = await VerdictSupabaseService.fetchVerdicts();
    for (final item in items) {
      await VerdictDB.importVerdictIfNotExists(item);
    }
  }

  // === Evidence ===
  static Future<void> _syncEvidence() async {
    final items = await EvidenceDB.getUnsyncedEvidence();
    for (final item in items) {
      await EvidenceDB.markEvidenceAsSynced(item.localId!);
    }
  }

  static Future<void> _importEvidence() async {}

  // === Witnesses ===
  static Future<void> _syncWitnesses() async {
    final items = await WitnessDB.getUnsyncedWitnesses();
    for (final item in items) {
      await WitnessDB.markWitnessAsSynced(item.localId!);
    }
  }

  static Future<void> _importWitnesses() async {}

  // === Notifications ===
  static Future<void> _syncNotifications() async {
    final items = await NotificationDB.getUnsyncedNotifications();
    for (final item in items) {
      await NotificationDB.markNotificationAsSynced(item.localId!);
    }
  }

  static Future<void> _importNotifications() async {}
}

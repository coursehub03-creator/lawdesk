import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/notification_db.dart';
import '../model/notification_model.dart';
import 'id.dart';
import 'settings_provider.dart';

class NotificationSupabaseService {
  static final Logger _logger = Logger();
  static final SupabaseClient _client = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'session_reminders';
  static const String _channelName = 'تذكيرات الجلسات';
  static const String _channelDescription =
      'تنبيهات الجلسات المرتبطة بالقضايا';

  static Future<void> initialize() async {
    timezone_data.initializeTimeZones();

    // Avoid LateInitializationError on some platforms (Windows).
    try {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    await _createAndroidChannel();
  }

  static Future<void> _createAndroidChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(channel);
  }

  /// Request permissions (Android 13+/iOS) in a safe way.
  static Future<void> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      _logger.w('Notification permission request failed: $e');
    }
  }

  static NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Schedule reminder(s) and also persist them locally (offline-first).
  ///
  /// Optional ids are used to link the notification to session/case.
  static Future<void> scheduleSessionReminder({
    required BuildContext context,
    required int id,
    required String title,
    required String body,
    required DateTime sessionDateTime,
    String? firebaseSessionId,
    String? firebaseCaseId,
    int? sessionId,
    int? caseId,
  }) async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    if (!settingsProvider.notificationsEnabled) return;

    final reminders = _getReminderTimes(
      sessionDateTime,
      settingsProvider.reminderTiming,
    );

    // Persist a record (one per scheduled reminder) for the in-app Notifications screen.
    for (int i = 0; i < reminders.length; i++) {
      final scheduleAt = reminders[i];
      if (scheduleAt.isBefore(DateTime.now())) {
        // Skip past reminders.
        continue;
      }

      // Local notification scheduling
      await _plugin.zonedSchedule(
        id + i,
        title,
        body,
        tz.TZDateTime.from(scheduleAt, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );

      // Local DB record (offline-first UUID)
      final notif = AppNotification(
        firebaseId: generateId(),
        title: title,
        body: body,
        timestamp: scheduleAt,
        sessionId: sessionId,
        firebaseSessionId: firebaseSessionId,
        caseId: caseId,
        firebaseCaseId: firebaseCaseId,
        isRead: false,
        isSynced: false,
      );

      final localId = await NotificationDB.insertNotification(notif);

      // Best-effort: push to Supabase (won't break if table doesn't exist)
      final pushed = await upsertNotificationToSupabase(notif);
      if (pushed != null) {
        await NotificationDB.markNotificationAsSynced(localId);
      }
    }
  }

  static List<DateTime> _getReminderTimes(DateTime sessionDateTime, String option) {
    switch (option) {
      case 'ساعة قبل':
        return [sessionDateTime.subtract(const Duration(hours: 1))];
      case '12 ساعة قبل':
        return [sessionDateTime.subtract(const Duration(hours: 12))];
      case 'يوم قبل':
        return [sessionDateTime.subtract(const Duration(days: 1))];
      case 'ثلاث أوقات':
        return [
          sessionDateTime.subtract(const Duration(days: 1)),
          sessionDateTime.subtract(const Duration(hours: 12)),
          sessionDateTime.subtract(const Duration(hours: 1)),
        ];
      default:
        return [sessionDateTime.subtract(const Duration(hours: 1))];
    }
  }

  // ---------------------------------------------------------------------------
  // Cloud (optional) - keeps UUIDs consistent across devices
  // ---------------------------------------------------------------------------

  static Future<AppNotification?> upsertNotificationToSupabase(AppNotification n) async {
    try {
      final fid = (n.firebaseId ?? '').trim();
      if (fid.isEmpty) return null;

      final response = await _client
          .from('notifications')
          .upsert(n.toMapSupabase(), onConflict: 'id')
          .select()
          .single();

      return AppNotification.fromMapSupabase(response as Map<String, dynamic>);
    } catch (e) {
      // Keep it silent-ish: table may not exist or user may be offline.
      _logger.w('Notification upsert to Supabase failed: $e');
      return null;
    }
  }

  static Future<List<AppNotification>> fetchNotificationsFromSupabase({
    String? firebaseCaseId,
    String? firebaseSessionId,
  }) async {
    try {
      var q = _client.from('notifications').select();

      if ((firebaseCaseId ?? '').trim().isNotEmpty) {
        q = q.eq('case_id', firebaseCaseId!.trim());
      }
      if ((firebaseSessionId ?? '').trim().isNotEmpty) {
        q = q.eq('session_id', firebaseSessionId!.trim());
      }

      final response = await q.order('timestamp', ascending: false);

      return (response as List)
          .map((e) => AppNotification.fromMapSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.w('Fetch notifications from Supabase failed: $e');
      return [];
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      _logger.w('Cancel notifications failed: $e');
    }
  }
}

class AppNotification {
  final int? localId; // SQLite ID
  /// Supabase ID (UUID - offline-first)
  ///
  /// ⚠️ مهم: يجب توليده محليًا (generateId) ثم Upsert للسحابة بنفس القيمة.
  final String? firebaseId;
  final String title;
  final String body;
  final DateTime timestamp;
  final int? sessionId; // SQLite
  final String? firebaseSessionId; // Supabase
  final int? caseId; // SQLite
  final String? firebaseCaseId; // Supabase
  final bool isRead;
  final bool isSynced;

  AppNotification({
    this.localId,
    this.firebaseId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.sessionId,
    this.firebaseSessionId,
    this.caseId,
    this.firebaseCaseId,
    this.isRead = false,
    this.isSynced = true,
  });

  AppNotification copyWith({
    int? localId,
    String? firebaseId,
    String? title,
    String? body,
    DateTime? timestamp,
    int? sessionId,
    String? firebaseSessionId,
    int? caseId,
    String? firebaseCaseId,
    bool? isRead,
    bool? isSynced,
  }) {
    return AppNotification(
      localId: localId ?? this.localId,
      firebaseId: firebaseId ?? this.firebaseId,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
      firebaseSessionId: firebaseSessionId ?? this.firebaseSessionId,
      caseId: caseId ?? this.caseId,
      firebaseCaseId: firebaseCaseId ?? this.firebaseCaseId,
      isRead: isRead ?? this.isRead,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // === SQLite ===
  Map<String, dynamic> toMapLocal() {
    return {
      'id': localId,
      'firebase_id': firebaseId,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId,
      'firebase_session_id': firebaseSessionId,
      'case_id': caseId,
      'firebase_case_id': firebaseCaseId,
      'is_read': isRead ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory AppNotification.fromMapLocal(Map<String, dynamic> map) {
    return AppNotification(
      localId: map['id'],
      firebaseId: map['firebase_id'],
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      sessionId: map['session_id'],
      firebaseSessionId: map['firebase_session_id'],
      caseId: map['case_id'],
      firebaseCaseId: map['firebase_case_id'],
      isRead: map['is_read'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }

  // === Supabase ===
  Map<String, dynamic> toMapSupabase() {
    return {
      // Offline-first: keep same id on cloud.
      if (firebaseId != null && firebaseId!.isNotEmpty) 'id': firebaseId,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      // In Supabase we store the PARENT cloud ids.
      'session_id': firebaseSessionId,
      'case_id': firebaseCaseId,
      'is_read': isRead,
    };
  }

  factory AppNotification.fromMapSupabase(Map<String, dynamic> map) {
    return AppNotification(
      firebaseId: map['id']?.toString(),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      firebaseSessionId: map['session_id'],
      firebaseCaseId: map['case_id'],
      isRead: map['is_read'] ?? false,
      isSynced: true,
    );
  }
}

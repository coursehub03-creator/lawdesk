class VerdictModel {
  final int? localId;
  final String? firebaseId;

  final int sessionId;
  final String? firebaseSessionId;

  final String pdfPath;
  final String description;
  final String createdAt;

  final bool isSynced;

  VerdictModel({
    this.localId,
    this.firebaseId,
    required this.sessionId,
    this.firebaseSessionId,
    required this.pdfPath,
    required this.description,
    required this.createdAt,
    this.isSynced = true,
  });

  // === من SQLite ===
  factory VerdictModel.fromMapLocal(Map<String, dynamic> map) {
    return VerdictModel(
      localId: map['id'],
      firebaseId: map['firebase_id'],
      sessionId: map['session_id'],
      firebaseSessionId: map['firebase_session_id'],
      pdfPath: map['pdf_path'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['created_at'] ?? '',
      isSynced: map['isSynced'] == 1,
    );
  }

  // === إلى SQLite ===
  Map<String, dynamic> toMapLocal() {
    return {
      'id': localId,
      'firebase_id': firebaseId,
      'session_id': sessionId,
      'firebase_session_id': firebaseSessionId,
      'pdf_path': pdfPath,
      'description': description,
      'created_at': createdAt,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // === من Supabase ===
  factory VerdictModel.fromMapSupabase(Map<String, dynamic> map) {
    return VerdictModel(
      firebaseId: map['id'],
      firebaseSessionId: map['session_id'],
      sessionId: 0, // سيتم ربطه يدويًا عند الاستيراد المحلي
      pdfPath: map['pdf_path'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['created_at'] ?? '',
      isSynced: true,
    );
  }

  // === إلى Supabase ===
  Map<String, dynamic> toMapSupabase() {
    final map = {
      // ✅ Keep offline-first stable IDs: when we have an id, send it.
      if (firebaseId != null && firebaseId!.trim().isNotEmpty) 'id': firebaseId!.trim(),
      'description': description,
      'pdf_path': pdfPath,
      'created_at': createdAt,
    };

    if (firebaseSessionId != null && firebaseSessionId!.isNotEmpty) {
      map['session_id'] = firebaseSessionId!;
    }

    return map;
  }

  VerdictModel copyWith({
    int? localId,
    String? firebaseId,
    int? sessionId,
    String? firebaseSessionId,
    String? pdfPath,
    String? description,
    String? createdAt,
    bool? isSynced,
  }) {
    return VerdictModel(
      localId: localId ?? this.localId,
      firebaseId: firebaseId ?? this.firebaseId,
      sessionId: sessionId ?? this.sessionId,
      firebaseSessionId: firebaseSessionId ?? this.firebaseSessionId,
      pdfPath: pdfPath ?? this.pdfPath,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

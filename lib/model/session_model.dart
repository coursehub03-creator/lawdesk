class SessionModel {
  final int? localId;
  final String? firebaseId;
  final int caseId; // محلي
  final String? firebaseCaseId; // سحابي
  final String date;
  final String time;
  final String location;
  final String notes;
  final bool isSynced;

  SessionModel({
    this.localId,
    this.firebaseId,
    required this.caseId,
    this.firebaseCaseId,
    required this.date,
    required this.time,
    required this.location,
    required this.notes,
    // ✅ الافتراضي: أي سجل جديد يعتبر غير متزامن حتى ينجح رفعه للسحابة.
    this.isSynced = false,
  });

  // --- من SQLite ---
  factory SessionModel.fromMapLocal(Map<String, dynamic> map) {
    return SessionModel(
      localId: map['id'] as int?,
      firebaseId: map['firebase_id'] as String?,
      caseId: (map['case_id'] as int?) ?? 0,
      firebaseCaseId: map['firebase_case_id'] as String?, // ✅ جديد
      date: (map['date'] ?? '') as String,
      time: (map['time'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      isSynced: (map['isSynced'] ?? 0) == 1,
    );
  }

  // --- إلى SQLite ---
  Map<String, dynamic> toMapLocal() {
    return {
      'id': localId,
      'firebase_id': firebaseId,
      'case_id': caseId,
      'firebase_case_id': firebaseCaseId, // ✅ جديد
      'date': date,
      'time': time,
      'location': location,
      'notes': notes,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // --- من Supabase ---
  factory SessionModel.fromMapSupabase(Map<String, dynamic> map) {
    return SessionModel(
      firebaseId: map['id'] as String?,
      firebaseCaseId: map['case_id'] as String?,
      caseId: 0, // سيُربط محليًا لاحقًا
      date: (map['date'] ?? '') as String,
      time: (map['time'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      isSynced: true,
    );
  }

  // --- إلى Supabase ---
  Map<String, dynamic> toMapSupabase() {
    // ✅ لا ترسل created_at من التطبيق إلا إذا كنت متأكد أنه مطلوب.
    // الأفضل يكون default في Supabase حتى لا تنكسر عمليات التحديث.
    return {
      // ✅ Keep offline-first stable IDs: when we have an id, send it.
      // This prevents local/remote ID mismatch that causes duplicates.
      if (firebaseId != null) 'id': firebaseId!.trim(),
      'case_id': firebaseCaseId?.trim(),
      'date': date,
      'time': time,
      'location': location,
      'notes': notes,
    };
  }

  SessionModel copyWith({
    int? localId,
    String? firebaseId,
    int? caseId,
    String? firebaseCaseId,
    String? date,
    String? time,
    String? location,
    String? notes,
    bool? isSynced,
  }) {
    return SessionModel(
      localId: localId ?? this.localId,
      firebaseId: firebaseId ?? this.firebaseId,
      caseId: caseId ?? this.caseId,
      firebaseCaseId: firebaseCaseId ?? this.firebaseCaseId,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

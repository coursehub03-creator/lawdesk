class WitnessModel {
  /// Cloud UUID (Supabase). We keep the field name `firebaseId` for compatibility
  /// with existing code/history.
  final String firebaseId;

  /// Local parent case id (SQLite integer).
  final int caseId;

  /// Cloud parent case id (Supabase UUID). Required for syncing.
  final String firebaseCaseId;

  final String name;

  /// Must not be null for Supabase (role column is typically NOT NULL).
  final String role;

  final String? notes;
  final String? phone;
  final String? address;

  /// Relationship to client/case parties.
  final String? relationship;

  /// Local auto-increment id.
  final int? localId;

  /// Whether this row is synced to Supabase.
  final bool isSynced;

  const WitnessModel({
    required this.firebaseId,
    required this.caseId,
    required this.firebaseCaseId,
    required this.name,
    required this.role,
    this.notes,
    this.phone,
    this.address,
    this.relationship,
    this.localId,
    this.isSynced = false,
  });

  WitnessModel copyWith({
    String? firebaseId,
    int? caseId,
    String? firebaseCaseId,
    String? name,
    String? role,
    String? notes,
    String? phone,
    String? address,
    String? relationship,
    int? localId,
    bool? isSynced,
  }) {
    return WitnessModel(
      firebaseId: firebaseId ?? this.firebaseId,
      caseId: caseId ?? this.caseId,
      firebaseCaseId: firebaseCaseId ?? this.firebaseCaseId,
      name: name ?? this.name,
      role: role ?? this.role,
      notes: notes ?? this.notes,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      relationship: relationship ?? this.relationship,
      localId: localId ?? this.localId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// SQLite map.
  Map<String, dynamic> toMapLocal() {
    return {
      if (localId != null) 'id': localId,
      'firebase_id': firebaseId,
      'case_id': caseId,
      'firebase_case_id': firebaseCaseId,
      'name': name,
      'role': role,
      'notes': notes,
      'phone': phone,
      'address': address,
      'relationship': relationship,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  static WitnessModel fromMapLocal(Map<String, dynamic> map) {
    return WitnessModel(
      localId: map['id'] as int?,
      firebaseId: (map['firebase_id'] ?? '') as String,
      caseId: (map['case_id'] ?? 0) as int,
      firebaseCaseId: (map['firebase_case_id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      role: (map['role'] ?? 'witness') as String,
      notes: map['notes'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      relationship: map['relationship'] as String?,
      isSynced: (map['isSynced'] ?? 0) == 1,
    );
  }

  /// Supabase map.
  Map<String, dynamic> toMapSupabase() {
    return {
      'id': firebaseId,
      'case_id': firebaseCaseId,
      'name': name,
      'role': role,
      'notes': notes,
      'phone': phone,
      'address': address,
      'relationship': relationship,
    };
  }

  static WitnessModel fromMapSupabase(Map<String, dynamic> map, {required int fallbackCaseId}) {
    return WitnessModel(
      firebaseId: (map['id'] ?? '') as String,
      caseId: fallbackCaseId,
      firebaseCaseId: (map['case_id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      role: (map['role'] ?? 'witness') as String,
      notes: map['notes'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      relationship: map['relationship'] as String?,
      isSynced: true,
    );
  }
}

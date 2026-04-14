class EvidenceModel {
  final int? localId; // SQLite ID
  final String? firebaseId; // Supabase UUID (same as local-generated UUID)

  final int caseId; // local case id (SQLite)
  final String? firebaseCaseId; // cloud case id (Supabase)

  /// For offline rows: this may temporarily be a local copied path.
  /// Once uploaded: store the Supabase storage path.
  final String filePath;

  final String type;
  final String uploadedAt;
  final String? description;

  final bool isSynced;

  EvidenceModel({
    this.localId,
    this.firebaseId,
    required this.caseId,
    required this.firebaseCaseId,
    required this.filePath,
    required this.type,
    required this.uploadedAt,
    this.description,
    this.isSynced = false,
  });

  EvidenceModel copyWith({
    int? localId,
    String? firebaseId,
    int? caseId,
    String? firebaseCaseId,
    String? filePath,
    String? type,
    String? uploadedAt,
    String? description,
    bool? isSynced,
  }) {
    return EvidenceModel(
      localId: localId ?? this.localId,
      firebaseId: firebaseId ?? this.firebaseId,
      caseId: caseId ?? this.caseId,
      firebaseCaseId: firebaseCaseId ?? this.firebaseCaseId,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      description: description ?? this.description,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMapLocal() {
    return {
      'firebase_id': firebaseId ?? '',
      'firebase_case_id': firebaseCaseId ?? '',
      'caseId': caseId,
      'filePath': filePath,
      'type': type,
      'uploadedAt': uploadedAt,
      'description': description,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory EvidenceModel.fromMapLocal(Map<String, dynamic> map) {
    return EvidenceModel(
      localId: map['id'] as int?,
      firebaseId: (map['firebase_id'] ?? '').toString(),
      firebaseCaseId: (map['firebase_case_id'] ?? '').toString(),
      caseId: (map['caseId'] ?? 0) as int,
      filePath: (map['filePath'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      uploadedAt: (map['uploadedAt'] ?? '').toString(),
      description: map['description']?.toString(),
      isSynced: (map['isSynced'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMapSupabase() {
    return {
      'id': firebaseId,
      'case_id': firebaseCaseId,
      'file_path': filePath,
      'type': type,
      'uploaded_at': uploadedAt,
      'description': description,
    };
  }

  factory EvidenceModel.fromMapSupabase(Map<String, dynamic> map) {
    return EvidenceModel(
      firebaseId: map['id']?.toString(),
      firebaseCaseId: map['case_id']?.toString(),
      filePath: (map['file_path'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      uploadedAt: (map['uploaded_at'] ?? '').toString(),
      description: map['description']?.toString(),
      caseId: 0, // bind later
      isSynced: true,
    );
  }
}
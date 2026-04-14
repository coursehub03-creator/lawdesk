class CaseModel {
  final int? localId; // SQLite
  /// معرف موحّد (UUID) يُستخدم محلياً وسحابياً.
  /// في Supabase هذا هو العمود id (uuid).
  /// يجب أن يكون موجوداً حتى في وضع الأوفلاين.
  final String firebaseId;

  final String title;
  final String fileNumber;
  final String status;

  final String? caseType;
  final String? court;
  final String? startDate;
  final String? notes;

  final int clientId; // SQLite
  /// معرف العميل السحابي (clients.id) لربط القضية بالعميل في Supabase.
  /// لا تعتمد على clientId المحلي للربط السحابي.
  final String? firebaseClientId; // Supabase

  final bool isSynced;

  CaseModel({
    this.localId,
    required this.firebaseId,
    required this.title,
    required this.fileNumber,
    required this.status,
    this.caseType,
    this.court,
    this.startDate,
    this.notes,
    required this.clientId,
    this.firebaseClientId,
    this.isSynced = true,
  });

  // ✅ دالة copyWith الجديدة
  CaseModel copyWith({
    int? localId,
    String? firebaseId,
    String? title,
    String? fileNumber,
    String? status,
    String? caseType,
    String? court,
    String? startDate,
    String? notes,
    int? clientId,
    String? firebaseClientId,
    bool? isSynced,
  }) {
    return CaseModel(
      localId: localId ?? this.localId,
      firebaseId: firebaseId ?? this.firebaseId,
      title: title ?? this.title,
      fileNumber: fileNumber ?? this.fileNumber,
      status: status ?? this.status,
      caseType: caseType ?? this.caseType,
      court: court ?? this.court,
      startDate: startDate ?? this.startDate,
      notes: notes ?? this.notes,
      clientId: clientId ?? this.clientId,
      firebaseClientId: firebaseClientId ?? this.firebaseClientId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // --- من SQLite ---
  factory CaseModel.fromMapLocal(Map<String, dynamic> map) {
    return CaseModel(
      localId: map['id'],
      firebaseId: (map['firebase_id'] ?? '').toString(), // UUID الموحّد
      title: map['title'] ?? '',
      fileNumber: map['fileNumber'] ?? '',
      status: map['status'] ?? '',
      caseType: map['caseType'],
      court: map['court'],
      startDate: map['startDate'],
      notes: map['notes'],
      clientId: map['clientId'] ?? 0,
      firebaseClientId: map['firebase_client_id']?.toString(),
      isSynced: map['isSynced'] == 1,
    );
  }

  // --- إلى SQLite ---
  Map<String, dynamic> toMapLocal() {
    return {
      'id': localId,
      'firebase_id': firebaseId,
      'title': title,
      'fileNumber': fileNumber,
      'status': status,
      'caseType': caseType,
      'court': court,
      'startDate': startDate,
      'notes': notes,
      'clientId': clientId,
      'firebase_client_id': firebaseClientId,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // --- من Supabase ---
  factory CaseModel.fromMapSupabase(Map<String, dynamic> map) {
    return CaseModel(
      firebaseId: map['id'].toString(),
      title: map['title'] ?? '',
      fileNumber: map['file_number'] ?? '',
      status: map['status'] ?? '',
      caseType: map['case_type'],
      court: map['court'],
      startDate: map['start_date'],
      notes: map['notes'],
      firebaseClientId: map['client_id'],
      clientId: 0, // يتم تجاهله من Supabase
      isSynced: true,
    );
  }

  // --- إلى Supabase ---
  Map<String, dynamic> toMapSupabase() {
    return {
      // ✅ نرسل id حتى يكون موحّد بين المحلي والسحابي.
      'id': firebaseId,
      'title': title,
      'file_number': fileNumber,
      'status': status,
      'case_type': caseType,
      'court': court,
      'start_date': startDate,
      'notes': notes,
      'client_id': firebaseClientId?.trim(),
      // created_at الأفضل يكون default في Supabase.
    };
  }
}

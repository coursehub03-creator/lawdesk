// lib/model/client.dart

class Client {
  final int? localId; // ID محلي SQLite
  final String id; // ID سحابي (Supabase)
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final bool isSynced; // هل تم مزامنته مع Supabase

  Client({
    this.localId,
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    this.notes = '',
    this.isSynced = true,
  });

  // --- copyWith ---
  Client copyWith({
    int? localId,
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isSynced,
  }) {
    return Client(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // --- من Supabase ---
  factory Client.fromMapSupabase(Map<String, dynamic> data) {
    return Client(
      id: data['id'].toString(),
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      notes: data['notes'] ?? '',
      isSynced: true,
    );
  }

  // --- من SQLite ---
  factory Client.fromMapLocal(Map<String, dynamic> map) {
    return Client(
      localId: map['id'] as int?,
      id: map['firebase_id']?.toString() ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      notes: map['notes'] ?? '',
      isSynced: (map['isSynced'] ?? 0) == 1,
    );
  }

  // --- إلى SQLite ---
  Map<String, dynamic> toMapLocal() {
    return {
      'id': localId,
      'firebase_id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // --- إلى Supabase ---
  Map<String, dynamic> toMapSupabase() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      // ما نرسل created_at هنا إلا إذا فعلاً عندك العمود
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

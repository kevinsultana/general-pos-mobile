class CustomerModel {
  final String id;
  final String tenantId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String syncStatus;
  final String? createdAt;

  CustomerModel({
    required this.id,
    required this.tenantId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.syncStatus = 'PENDING',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'sync_status': syncStatus,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING',
      createdAt: map['created_at'] as String?,
    );
  }

  CustomerModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    String? syncStatus,
    String? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CategoryModel {
  final String id;
  final String tenantId;
  final String name;
  final int sortOrder;
  final String syncStatus;
  final String? createdAt;
  final String? updatedAt;

  CategoryModel({
    required this.id,
    required this.tenantId,
    required this.name,
    this.sortOrder = 0,
    this.syncStatus = 'PENDING',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'sort_order': sortOrder,
      'sync_status': syncStatus,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    int? sortOrder,
    String? syncStatus,
    String? createdAt,
    String? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductModel {
  final String id;
  final String tenantId;
  final String? categoryId;
  final String name;
  final double price;
  final double costPrice;
  final String? imageUrl;
  final bool isActive;
  final String syncStatus;
  final String? createdAt;
  final String? updatedAt;

  ProductModel({
    required this.id,
    required this.tenantId,
    this.categoryId,
    required this.name,
    required this.price,
    this.costPrice = 0,
    this.imageUrl,
    this.isActive = true,
    this.syncStatus = 'PENDING',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'sync_status': syncStatus,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      imageUrl: map['image_url'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  ProductModel copyWith({
    String? id,
    String? tenantId,
    String? categoryId,
    String? name,
    double? price,
    double? costPrice,
    String? imageUrl,
    bool? isActive,
    String? syncStatus,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

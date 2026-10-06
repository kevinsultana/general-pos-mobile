class TenantModel {
  final String id;
  final String name;
  final String slug;
  final String plan; // 'FREE', 'PLUS', 'PRO'
  final String? planStatus;
  final String? ownerName;
  final String? branchId;
  final String? branchName;
  final String? token;
  final String? logoUrl;
  final bool receiptShowLogo;
  final int roundingMode;
  final int printerWidth;
  final String receiptFontSize;
  final String? updatedAt;

  TenantModel({
    required this.id,
    required this.name,
    required this.slug,
    this.plan = 'FREE',
    this.planStatus,
    this.ownerName,
    this.branchId,
    this.branchName,
    this.token,
    this.logoUrl,
    this.receiptShowLogo = true,
    this.roundingMode = 0,
    this.printerWidth = 58,
    this.receiptFontSize = 'NORMAL',
    this.updatedAt,
  });

  bool get isProOrPlus => plan == 'PRO' || plan == 'PLUS';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'plan': plan,
      'plan_status': planStatus,
      'owner_name': ownerName,
      'branch_id': branchId,
      'branch_name': branchName,
      'token': token,
      'logo_url': logoUrl,
      'receipt_show_logo': receiptShowLogo ? 1 : 0,
      'rounding_mode': roundingMode,
      'printer_width': printerWidth,
      'receipt_font_size': receiptFontSize,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory TenantModel.fromMap(Map<String, dynamic> map) {
    return TenantModel(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      plan: (map['plan'] as String?) ?? 'FREE',
      planStatus: map['plan_status'] as String?,
      ownerName: map['owner_name'] as String?,
      branchId: map['branch_id'] as String?,
      branchName: map['branch_name'] as String?,
      token: map['token'] as String?,
      logoUrl: map['logo_url'] as String?,
      receiptShowLogo: (map['receipt_show_logo'] is int)
          ? (map['receipt_show_logo'] as int) == 1
          : (map['receipt_show_logo'] as bool? ?? true),
      roundingMode: (map['rounding_mode'] as int?) ?? 0,
      printerWidth: (map['printer_width'] as int?) ?? 58,
      receiptFontSize: (map['receipt_font_size'] as String?) ?? 'NORMAL',
      updatedAt: map['updated_at'] as String?,
    );
  }

  TenantModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? plan,
    String? planStatus,
    String? ownerName,
    String? branchId,
    String? branchName,
    String? token,
    String? logoUrl,
    bool? receiptShowLogo,
    int? roundingMode,
    int? printerWidth,
    String? receiptFontSize,
    String? updatedAt,
  }) {
    return TenantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      plan: plan ?? this.plan,
      planStatus: planStatus ?? this.planStatus,
      ownerName: ownerName ?? this.ownerName,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      token: token ?? this.token,
      logoUrl: logoUrl ?? this.logoUrl,
      receiptShowLogo: receiptShowLogo ?? this.receiptShowLogo,
      roundingMode: roundingMode ?? this.roundingMode,
      printerWidth: printerWidth ?? this.printerWidth,
      receiptFontSize: receiptFontSize ?? this.receiptFontSize,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

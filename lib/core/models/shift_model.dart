class ShiftModel {
  final String id;
  final String tenantId;
  final String? branchId;
  final String cashierName;
  final double startingCash;
  final double cashSales;
  final double nonCashSales;
  final double totalSales;
  final int totalTransactions;
  final double? closingCash;
  final double? actualCash;
  final double? discrepancy;
  final String status; // 'OPEN' or 'CLOSED'
  final String startedAt;
  final String? endedAt;
  final String syncStatus;

  ShiftModel({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.cashierName,
    required this.startingCash,
    this.cashSales = 0,
    this.nonCashSales = 0,
    this.totalSales = 0,
    this.totalTransactions = 0,
    this.closingCash,
    this.actualCash,
    this.discrepancy,
    this.status = 'OPEN',
    required this.startedAt,
    this.endedAt,
    this.syncStatus = 'PENDING',
  });

  bool get isOpen => status == 'OPEN';
  double get expectedCash => startingCash + cashSales;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'cashier_name': cashierName,
      'starting_cash': startingCash,
      'cash_sales': cashSales,
      'non_cash_sales': nonCashSales,
      'total_sales': totalSales,
      'total_transactions': totalTransactions,
      'closing_cash': closingCash,
      'actual_cash': actualCash,
      'discrepancy': discrepancy,
      'status': status,
      'started_at': startedAt,
      'ended_at': endedAt,
      'sync_status': syncStatus,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      cashierName: (map['cashier_name'] as String?) ?? 'Kasir',
      startingCash: (map['starting_cash'] as num).toDouble(),
      cashSales: (map['cash_sales'] as num?)?.toDouble() ?? 0,
      nonCashSales: (map['non_cash_sales'] as num?)?.toDouble() ?? 0,
      totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0,
      totalTransactions: (map['total_transactions'] as num?)?.toInt() ?? 0,
      closingCash: (map['closing_cash'] as num?)?.toDouble(),
      actualCash: (map['actual_cash'] as num?)?.toDouble(),
      discrepancy: (map['discrepancy'] as num?)?.toDouble(),
      status: (map['status'] as String?) ?? 'OPEN',
      startedAt: (map['started_at'] as String?) ?? DateTime.now().toIso8601String(),
      endedAt: map['ended_at'] as String?,
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING',
    );
  }

  ShiftModel copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    String? cashierName,
    double? startingCash,
    double? cashSales,
    double? nonCashSales,
    double? totalSales,
    int? totalTransactions,
    double? closingCash,
    double? actualCash,
    double? discrepancy,
    String? status,
    String? startedAt,
    String? endedAt,
    String? syncStatus,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      cashierName: cashierName ?? this.cashierName,
      startingCash: startingCash ?? this.startingCash,
      cashSales: cashSales ?? this.cashSales,
      nonCashSales: nonCashSales ?? this.nonCashSales,
      totalSales: totalSales ?? this.totalSales,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      closingCash: closingCash ?? this.closingCash,
      actualCash: actualCash ?? this.actualCash,
      discrepancy: discrepancy ?? this.discrepancy,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

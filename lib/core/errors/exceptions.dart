class InsufficientStockException implements Exception {
  final String productId;
  final int availableStock;
  final String? productName;

  const InsufficientStockException(
    this.productId,
    this.availableStock, [
    this.productName,
  ]);

  @override
  String toString() {
    final nameInfo = productName != null ? ' ($productName)' : '';
    return 'InsufficientStockException: Stok tidak mencukupi untuk produk $productId$nameInfo. Stok tersedia: $availableStock';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsufficientStockException &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          availableStock == other.availableStock;

  @override
  int get hashCode => Object.hash(productId, availableStock);
}

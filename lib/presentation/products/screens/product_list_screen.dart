import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../inventory/widgets/stock_adjustment_dialog.dart';
import '../../inventory/widgets/stock_history_dialog.dart';
import '../../inventory/widgets/stock_in_dialog.dart';
import '../controllers/category_controller.dart';
import '../controllers/product_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../data/services/barcode_label_service.dart';
import '../../common/widgets/barcode_label_dialog.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredProducts = ref.watch(filteredProductListProvider);
    final productsAsync = ref.watch(productListStreamProvider);
    final categoriesAsync = ref.watch(categoryListStreamProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final canManageProducts = ref.watch(hasPermissionProvider(AppPermissions.manageProducts));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Katalog Produk & Inventori',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.refresh(productListStreamProvider),
          ),
        ],
      ),
      floatingActionButton: canManageProducts
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Produk'),
              onPressed: () {
                context.push('/products/new');
              },
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Search Input
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari produk, SKU, atau barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: ref.watch(productSearchQueryProvider).isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              ref.read(productSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    ref.read(productSearchQueryProvider.notifier).state = val;
                  },
                ),
                const SizedBox(height: 12),

                // Category Chips List
                categoriesAsync.maybeWhen(
                  data: (categories) {
                    return SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua Kategori'),
                            selected: selectedCategory == null,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(selectedCategoryFilterProvider.notifier)
                                    .state = null;
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ...categories.map((c) {
                            final isSelected = selectedCategory == c.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  ref
                                      .read(selectedCategoryFilterProvider.notifier)
                                      .state = selected ? c.id : null;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Product List
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (_) {
                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.accentContainer.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Produk',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mulai dengan menambahkan produk pertama ke dalam katalog POS Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Buat Produk Sekarang'),
                            onPressed: () => context.push('/products/new'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNegative = product.stock < 0;
    final isOutOfStock = product.stock == 0;
    final isLowStock =
        product.stock <= product.lowStockThreshold && product.stock > 0;

    Color stockColor = AppColors.success;
    Color stockBg = AppColors.accentContainer;
    String stockText = '${product.stock} unit';

    if (isNegative) {
      stockColor = AppColors.danger;
      stockBg = AppColors.danger.withValues(alpha: 0.15);
      stockText = '${product.stock} unit (Minus)';
    } else if (isOutOfStock) {
      stockColor = AppColors.danger;
      stockBg = AppColors.danger.withValues(alpha: 0.12);
      stockText = 'Habis';
    } else if (isLowStock) {
      stockColor = AppColors.warning;
      stockBg = AppColors.warning.withValues(alpha: 0.15);
      stockText = '${product.stock} unit (Menipis)';
    }

    final canManageProducts = ref.watch(hasPermissionProvider(AppPermissions.manageProducts));
    final canManageInventory = ref.watch(hasPermissionProvider(AppPermissions.manageInventory));
    final variantsAsync = ref.watch(productVariantsStreamProvider(product.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name and Stock Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isNegative || isLowStock || isOutOfStock) ...[
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: stockColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        stockText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: stockColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: SKU and Barcode
            Row(
              children: [
                if (product.sku != null && product.sku!.isNotEmpty) ...[
                  Text(
                    'SKU: ${product.sku}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                  Text(
                    'Barcode: ${product.barcode}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Price & Cost
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga Jual',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(product.sellingPrice),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HPP (Modal)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(product.cost),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            variantsAsync.when(
              data: (variants) {
                if (variants.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stok per Varian:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: variants.map((v) {
                          final isVarNegative = v.stock < 0;
                          final isVarEmpty = v.stock == 0;
                          Color vColor = AppColors.accent;
                          Color vBg = AppColors.accentContainer.withValues(alpha: 0.3);

                          if (isVarNegative) {
                            vColor = AppColors.danger;
                            vBg = AppColors.danger.withValues(alpha: 0.12);
                          } else if (isVarEmpty) {
                            vColor = AppColors.textSecondaryLight;
                            vBg = AppColors.backgroundLight;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: vBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isVarNegative ? AppColors.danger.withValues(alpha: 0.5) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '${v.name}: ${v.stock}${isVarNegative ? ' (Minus)' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: vColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const Divider(height: 20),

            // Row 4: Action Buttons (Stock In, Penyesuaian, Histori, Edit)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (canManageInventory) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        side: const BorderSide(color: AppColors.accent),
                        foregroundColor: AppColors.accent,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      label: const Text('Stock In'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => StockInDialog(product: product),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Sesuaikan'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => StockAdjustmentDialog(product: product),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Histori'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => StockHistoryDialog(product: product),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                    tooltip: 'Cetak Label Barcode (CODE 128)',
                    onPressed: () async {
                      final store = await ref
                          .read(storeRepositoryProvider)
                          .getStore(AppConstants.defaultStoreId);
                      if (context.mounted) {
                        final barcodeVal = product.barcode != null &&
                                product.barcode!.isNotEmpty
                            ? product.barcode!
                            : (product.sku != null && product.sku!.isNotEmpty
                                ? product.sku!
                                : product.name);
                        BarcodeLabelDialog.show(
                          context,
                          BarcodeLabelData(
                            productName: product.name,
                            barcodeValue: barcodeVal,
                            price: product.sellingPrice,
                            storeName: store?.name ?? 'TOKO UMKM POS',
                          ),
                        );
                      }
                    },
                  ),
                  if (canManageProducts) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Produk',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductFormScreen(productToEdit: product),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

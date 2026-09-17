import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../products/controllers/category_controller.dart';
import '../../products/controllers/product_controller.dart';
import '../controllers/cart_controller.dart';
import '../widgets/cart_bottom_sheet.dart';
import '../widgets/drafts_sheet.dart';
import '../widgets/variant_picker_dialog.dart';
import '../../common/widgets/barcode_scanner_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcodeWithCamera() async {
    final scanned = await BarcodeScannerScreen.scan(
      context,
      title: 'Pindai Barcode Transaksi',
    );
    if (scanned != null && scanned.isNotEmpty && mounted) {
      final found = await ref
          .read(cartControllerProvider.notifier)
          .addByBarcode(scanned);
      if (!found && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Produk dengan barcode "$scanned" tidak ditemukan'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Produk ($scanned) berhasil ditambahkan ke keranjang',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListStreamProvider);
    final categoriesAsync = ref.watch(categoryListStreamProvider);
    final draftsAsync = ref.watch(draftListStreamProvider);
    final cartState = ref.watch(cartControllerProvider);
    final cartNotifier = ref.read(cartControllerProvider.notifier);

    final draftCount = draftsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Kasir POS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          // Drafts saved badge button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.bookmark_outline_rounded),
                tooltip: 'Pesanan Tersimpan (Draft)',
                onPressed: () => DraftsSheet.show(context),
              ),
              if (draftCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$draftCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar + Barcode Scanner Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk, SKU, atau barcode...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  tooltip: 'Pindai Barcode Kamera',
                  onPressed: _scanBarcodeWithCamera,
                ),
              ],
            ),
          ),

          // Category Chips Filter
          categoriesAsync.when(
            data: (categories) {
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Semua'),
                        selected: _selectedCategoryId == null,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _selectedCategoryId == null
                              ? AppColors.primary
                              : AppColors.borderLight,
                        ),
                        labelStyle: TextStyle(
                          color: _selectedCategoryId == null
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontWeight: _selectedCategoryId == null
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                        checkmarkColor: Colors.white,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategoryId = null;
                            });
                          }
                        },
                      ),
                    ),
                    ...categories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.borderLight,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          checkmarkColor: Colors.white,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryId = selected ? cat.id : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          // Product Catalog Grid
          Expanded(
            child: productsAsync.when(
              data: (products) {
                var filtered = products;

                // Category filter
                if (_selectedCategoryId != null) {
                  filtered = filtered
                      .where((p) => p.categoryId == _selectedCategoryId)
                      .toList();
                }

                // Search query filter
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((p) {
                    final nameMatch = p.name.toLowerCase().contains(
                      _searchQuery,
                    );
                    final skuMatch =
                        p.sku?.toLowerCase().contains(_searchQuery) ?? false;
                    final barcodeMatch =
                        p.barcode?.toLowerCase().contains(_searchQuery) ??
                        false;
                    return nameMatch || skuMatch || barcodeMatch;
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak Ada Produk Ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    cartState.isNotEmpty ? 88 : 16,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final product = filtered[index];
                    final isNegativeStock = product.stock < 0;
                    final isLowStock = product.stock > 0 && product.stock <= 5;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          // Check if product has variants
                          final productRepo = ref.read(
                            productRepositoryProvider,
                          );
                          final variants = await productRepo.getVariants(
                            product.id,
                          );

                          if (variants.isNotEmpty && context.mounted) {
                            VariantPickerDialog.show(
                              context,
                              product: product,
                              variants: variants,
                            );
                          } else {
                            cartNotifier.addProduct(product);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Icon & Stock Badge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.fastfood_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isNegativeStock
                                          ? AppColors.danger.withValues(
                                              alpha: 0.1,
                                            )
                                          : isLowStock
                                          ? AppColors.warning.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.green.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isNegativeStock
                                          ? 'Habis (${product.stock})'
                                          : isLowStock
                                          ? 'Sisa ${product.stock}'
                                          : '${product.stock}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isNegativeStock
                                            ? AppColors.danger
                                            : isLowStock
                                            ? AppColors.warning
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),

                              // Name
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryLight,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Price
                              Text(
                                CurrencyFormatter.format(product.sellingPrice),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Terjadi kesalahan: $err')),
            ),
          ),
        ],
      ),

      // Floating Cart Bottom Bar
      bottomSheet: cartState.isNotEmpty
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => CartBottomSheet.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${cartState.totalItemCount} item',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Tagihan',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(cartState.grandTotal),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Keranjang',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

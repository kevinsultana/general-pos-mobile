import 'dart:math';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/thousands_separator_input_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../common/widgets/barcode_scanner_screen.dart';
import '../controllers/category_controller.dart';
import '../controllers/product_controller.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _initialStockController = TextEditingController(text: '0');
  final _lowStockController = TextEditingController(text: '5');

  String? _selectedCategoryId;
  bool _isLoading = false;

  // Variants list
  final List<_VariantFormEntry> _variants = [];

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _skuController.text = p.sku ?? '';
      _barcodeController.text = p.barcode ?? '';
      _costController.text = ThousandsSeparatorInputFormatter.format(p.cost);
      _sellingPriceController.text = ThousandsSeparatorInputFormatter.format(p.sellingPrice);
      _initialStockController.text = ThousandsSeparatorInputFormatter.format(p.stock);
      _lowStockController.text = ThousandsSeparatorInputFormatter.format(p.lowStockThreshold);
      _selectedCategoryId = p.categoryId;
      _loadExistingVariants(p.id);
    }
  }

  Future<void> _loadExistingVariants(String productId) async {
    final variants = await ref
        .read(productRepositoryProvider)
        .getVariants(productId);
    if (mounted && variants.isNotEmpty) {
      setState(() {
        _variants.clear();
        for (final v in variants) {
          final stockCtrl = TextEditingController(
            text: ThousandsSeparatorInputFormatter.format(v.stock),
          );
          stockCtrl.addListener(_syncTotalVariantStock);
          _variants.add(_VariantFormEntry(
            id: v.id,
            nameController: TextEditingController(text: v.name),
            skuController: TextEditingController(text: v.sku ?? ''),
            costController: TextEditingController(
              text: ThousandsSeparatorInputFormatter.format(v.cost),
            ),
            priceController: TextEditingController(
              text: ThousandsSeparatorInputFormatter.format(v.sellingPrice),
            ),
            stockController: stockCtrl,
          ));
        }
        _syncTotalVariantStock();
      });
    }
  }

  void _syncTotalVariantStock() {
    if (_variants.isNotEmpty) {
      final total = _variants.fold<int>(
        0,
        (sum, v) => sum + ThousandsSeparatorInputFormatter.parse(v.stockController.text),
      );
      _initialStockController.text = ThousandsSeparatorInputFormatter.format(total);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _sellingPriceController.dispose();
    _initialStockController.dispose();
    _lowStockController.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _generateSku() {
    final rand = Random().nextInt(9000) + 1000;
    final prefix = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim().replaceAll(' ', '').toUpperCase()
        : 'PRD';
    final cleanPrefix = prefix.length > 3 ? prefix.substring(0, 3) : prefix;
    _skuController.text = '$cleanPrefix-$rand';
  }

  Future<void> _scanBarcodeWithCamera() async {
    final scannedCode = await BarcodeScannerScreen.scan(
      context,
      title: 'Pindai Barcode Produk',
    );
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode berhasil dipindai: $scannedCode'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addVariant() {
    final stockCtrl = TextEditingController(text: '0');
    stockCtrl.addListener(_syncTotalVariantStock);

    setState(() {
      _variants.add(_VariantFormEntry(
        nameController: TextEditingController(),
        skuController: TextEditingController(),
        costController: TextEditingController(text: _costController.text),
        priceController: TextEditingController(text: _sellingPriceController.text),
        stockController: stockCtrl,
      ));
      _syncTotalVariantStock();
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
      _syncTotalVariantStock();
    });
  }

  void _showAddCategoryDialog() {
    final categoryNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kategori Baru'),
        content: TextField(
          controller: categoryNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama Kategori *',
            hintText: 'Misal: Makanan, Minuman, Snack',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = categoryNameController.text.trim();
              if (name.isNotEmpty) {
                try {
                  final cat = await ref
                      .read(categoryControllerProvider.notifier)
                      .addCategory(name);
                  if (mounted) {
                    setState(() {
                      _selectedCategoryId = cat.id;
                    });
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menambah kategori: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productToEdit != null;
    final categoriesAsync = ref.watch(categoryListStreamProvider);
    final canManageProducts =
        ref.watch(hasPermissionProvider(AppPermissions.manageProducts));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              const Text(
                'Informasi Utama',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: categoriesAsync.when(
                      data: (categories) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Kategori Produk *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          hint: const Text('Pilih Kategori'),
                          items: categories.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategoryId = val;
                            });
                          },
                          validator: (val) =>
                              val == null ? 'Kategori wajib dipilih' : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error: $err'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    tooltip: 'Tambah Kategori',
                    onPressed: _showAddCategoryDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Product Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk *',
                  hintText: 'Contoh: Kopi Susu Aren',
                  prefixIcon: Icon(Icons.inventory_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama produk tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SKU Field + Auto Generator Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU (Kode Barang)',
                        hintText: 'Contoh: KSA-1029',
                        prefixIcon: Icon(Icons.qr_code_2_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Auto SKU'),
                    onPressed: _generateSku,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barcode Field + Camera Scan Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Barcode / EAN-13 (Opsional)',
                        hintText: 'Scan atau ketik nomor barcode',
                        prefixIcon: Icon(Icons.barcode_reader),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Scan'),
                    onPressed: _scanBarcodeWithCamera,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Price and Cost Section
              const Text(
                'Harga & Modal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      decoration: InputDecoration(
                        labelText: _variants.isNotEmpty
                            ? 'Harga Beli (HPP) (Opsional)'
                            : 'Harga Beli (HPP) *',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                        helperText: _variants.isNotEmpty
                            ? 'Otomatis mengikuti HPP varian'
                            : null,
                      ),
                      validator: (val) {
                        if (_variants.isEmpty && (val == null || val.trim().isEmpty)) {
                          return 'HPP wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      decoration: InputDecoration(
                        labelText: _variants.isNotEmpty
                            ? 'Harga Jual (Opsional)'
                            : 'Harga Jual *',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(Icons.sell_outlined),
                        helperText: _variants.isNotEmpty
                            ? 'Otomatis mengikuti harga jual varian'
                            : null,
                      ),
                      validator: (val) {
                        if (_variants.isEmpty && (val == null || val.trim().isEmpty)) {
                          return 'Harga jual wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stock Section
              const Text(
                'Inventori & Stok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _initialStockController,
                      enabled: !isEditing && _variants.isEmpty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Stok (Saat Ini)' : 'Stok Awal *',
                        prefixIcon: const Icon(Icons.all_inbox_rounded),
                        helperText: _variants.isNotEmpty
                            ? 'Otomatis dihitung dari total stok semua varian'
                            : (isEditing
                                ? 'Ubah stok melalui Stock In / Penyesuaian'
                                : 'Stok awal otomatis tercatat di ledger'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Batas Stok Minimum',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                        helperText: 'Peringatan bila stok di bawah angka ini',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Multi-Variant Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Varian Produk (Opsional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Varian'),
                    onPressed: _addVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_variants.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Center(
                    child: Text(
                      'Produk tunggal (tanpa varian). Klik "+ Tambah Varian" jika memiliki ukuran/rasa.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _variants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final v = _variants[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: v.nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Nama Varian #${index + 1} *',
                                      hintText: 'Contoh: Regular, Large, Panas',
                                    ),
                                    validator: (val) =>
                                        val == null || val.trim().isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.danger),
                                  onPressed: () => _removeVariant(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: v.priceController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      ThousandsSeparatorInputFormatter()
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Harga Jual *',
                                      prefixText: 'Rp ',
                                    ),
                                    validator: (val) =>
                                        val == null || val.trim().isEmpty
                                            ? 'Harga wajib diisi'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: v.costController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      ThousandsSeparatorInputFormatter()
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'HPP (Modal) *',
                                      prefixText: 'Rp ',
                                    ),
                                    validator: (val) =>
                                        val == null || val.trim().isEmpty
                                            ? 'HPP wajib diisi'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: v.skuController,
                                    decoration: const InputDecoration(
                                      labelText: 'SKU Varian (Opsional)',
                                      prefixIcon: Icon(Icons.qr_code, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: v.stockController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      ThousandsSeparatorInputFormatter()
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Stok Varian *',
                                      prefixIcon: const Icon(Icons.all_inbox, size: 20),
                                      helperText: isEditing
                                          ? 'Bisa disesuaikan via Stock In'
                                          : 'Stok awal varian',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 32),

              if (!canManageProducts)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anda tidak memiliki izin untuk mengelola atau menyimpan produk.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !canManageProducts ? null : _saveProduct,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Simpan Perubahan' : 'Buat Produk Baru',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori produk')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isEditing = widget.productToEdit != null;
      int cost = ThousandsSeparatorInputFormatter.parse(_costController.text);
      int price = ThousandsSeparatorInputFormatter.parse(_sellingPriceController.text);

      // If product has variants, fallback cost and price from variants if not set on master
      if (_variants.isNotEmpty) {
        final prices = _variants
            .map((v) => ThousandsSeparatorInputFormatter.parse(v.priceController.text))
            .where((p) => p > 0)
            .toList();
        if (price == 0 && prices.isNotEmpty) {
          price = prices.reduce((a, b) => a < b ? a : b); // Lowest variant price
        }

        final costs = _variants
            .map((v) => ThousandsSeparatorInputFormatter.parse(v.costController.text))
            .where((c) => c > 0)
            .toList();
        if (cost == 0 && costs.isNotEmpty) {
          cost = costs.first;
        }
      }

      final initialStock = ThousandsSeparatorInputFormatter.parse(_initialStockController.text);
      final lowStock = ThousandsSeparatorInputFormatter.parse(_lowStockController.text);

      final uuid = const Uuid();
      final now = DateTime.now();

      final List<ProductVariantsCompanion> variantCompanions = [];
      final targetProductId = widget.productToEdit?.id ?? uuid.v4();

      for (final v in _variants) {
        final vName = v.nameController.text.trim();
        if (vName.isNotEmpty) {
          variantCompanions.add(
            ProductVariantsCompanion(
              id: Value(v.id ?? uuid.v4()),
              productId: Value(targetProductId),
              name: Value(vName),
              sku: Value(v.skuController.text.trim().isNotEmpty
                  ? v.skuController.text.trim()
                  : null),
              cost: Value(ThousandsSeparatorInputFormatter.parse(v.costController.text)),
              sellingPrice:
                  Value(ThousandsSeparatorInputFormatter.parse(v.priceController.text)),
              stock: Value(ThousandsSeparatorInputFormatter.parse(v.stockController.text)),
              active: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }

      final totalVariantStock = variantCompanions.fold<int>(
        0,
        (sum, v) => sum + v.stock.value,
      );
      final effectiveStock = variantCompanions.isNotEmpty
          ? totalVariantStock
          : (isEditing ? widget.productToEdit!.stock : initialStock);

      await ref.read(productControllerProvider.notifier).saveProduct(
            id: isEditing ? widget.productToEdit!.id : targetProductId,
            categoryId: _selectedCategoryId!,
            name: _nameController.text.trim(),
            sku: _skuController.text.trim(),
            barcode: _barcodeController.text.trim(),
            cost: cost,
            sellingPrice: price,
            initialStock: effectiveStock,
            lowStockThreshold: lowStock,
            variants: variantCompanions,
          );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Produk ${_nameController.text} berhasil diperbarui'
                  : 'Produk ${_nameController.text} berhasil dibuat',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan produk: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _VariantFormEntry {
  final String? id;
  final TextEditingController nameController;
  final TextEditingController skuController;
  final TextEditingController costController;
  final TextEditingController priceController;
  final TextEditingController stockController;

  _VariantFormEntry({
    this.id,
    required this.nameController,
    required this.skuController,
    required this.costController,
    required this.priceController,
    required this.stockController,
  });

  void dispose() {
    nameController.dispose();
    skuController.dispose();
    costController.dispose();
    priceController.dispose();
    stockController.dispose();
  }
}

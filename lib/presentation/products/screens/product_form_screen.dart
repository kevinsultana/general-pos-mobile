import 'dart:math';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart';
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
      _costController.text = p.cost.toString();
      _sellingPriceController.text = p.sellingPrice.toString();
      _initialStockController.text = p.stock.toString();
      _lowStockController.text = p.lowStockThreshold.toString();
      _selectedCategoryId = p.categoryId;
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

  void _addVariant() {
    setState(() {
      _variants.add(_VariantFormEntry(
        nameController: TextEditingController(),
        skuController: TextEditingController(),
        costController: TextEditingController(text: _costController.text),
        priceController: TextEditingController(text: _sellingPriceController.text),
        stockController: TextEditingController(text: '0'),
      ));
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
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

              // Barcode Field
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Barcode / EAN-13 (Opsional)',
                  hintText: 'Scan atau ketik nomor barcode',
                  prefixIcon: Icon(Icons.barcode_reader),
                ),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Harga Beli (HPP) *',
                        prefixText: 'Rp ',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Harga Jual *',
                        prefixText: 'Rp ',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
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
                      enabled: !isEditing, // Initial stock only on creation
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Stok (Saat Ini)' : 'Stok Awal *',
                        prefixIcon: const Icon(Icons.all_inbox_rounded),
                        helperText: isEditing
                            ? 'Ubah stok melalui Stock In / Penyesuaian'
                            : 'Stok awal otomatis tercatat di ledger',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Harga Jual *',
                                      prefixText: 'Rp ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: v.costController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'HPP *',
                                      prefixText: 'Rp ',
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

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
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
      final cost = int.tryParse(_costController.text) ?? 0;
      final price = int.tryParse(_sellingPriceController.text) ?? 0;
      final initialStock = int.tryParse(_initialStockController.text) ?? 0;
      final lowStock = int.tryParse(_lowStockController.text) ?? 0;

      final uuid = const Uuid();
      final now = DateTime.now();

      final List<ProductVariantsCompanion> variantCompanions = [];
      final targetProductId = widget.productToEdit?.id ?? uuid.v4();

      for (final v in _variants) {
        final vName = v.nameController.text.trim();
        if (vName.isNotEmpty) {
          variantCompanions.add(
            ProductVariantsCompanion(
              id: Value(uuid.v4()),
              productId: Value(targetProductId),
              name: Value(vName),
              sku: Value(v.skuController.text.trim().isNotEmpty
                  ? v.skuController.text.trim()
                  : null),
              cost: Value(int.tryParse(v.costController.text) ?? cost),
              sellingPrice:
                  Value(int.tryParse(v.priceController.text) ?? price),
              stock: Value(int.tryParse(v.stockController.text) ?? 0),
              active: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }

      await ref.read(productControllerProvider.notifier).saveProduct(
            id: isEditing ? widget.productToEdit!.id : targetProductId,
            categoryId: _selectedCategoryId!,
            name: _nameController.text.trim(),
            sku: _skuController.text.trim(),
            barcode: _barcodeController.text.trim(),
            cost: cost,
            sellingPrice: price,
            initialStock: isEditing ? widget.productToEdit!.stock : initialStock,
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
  final TextEditingController nameController;
  final TextEditingController skuController;
  final TextEditingController costController;
  final TextEditingController priceController;
  final TextEditingController stockController;

  _VariantFormEntry({
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

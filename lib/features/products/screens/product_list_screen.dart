import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../pos/controllers/pos_controller.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final LocalRepository _repo = LocalRepository();
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant != null) {
      _products = await _repo.getProducts(tenant.id);
    }
    setState(() => _isLoading = false);
  }

  void _showAddEditProductDialog([ProductModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toInt().toString() : '');
    final costCtrl = TextEditingController(text: existing != null ? existing.costPrice.toInt().toString() : '');
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Tambah Produk Baru' : 'Edit Produk',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Misal: Kopi Susu',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Harga Jual (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '15000',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Harga Modal (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '8000',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Tersedia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Switch(
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setDialogState(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0;
                final cost = double.tryParse(costCtrl.text) ?? 0;
                if (name.isEmpty || price <= 0) return;

                final tenant = context.read<AuthController>().currentTenant;
                if (tenant == null) return;

                if (existing == null) {
                  final newProduct = ProductModel(
                    id: IdGenerator.v4(),
                    tenantId: tenant.id,
                    name: name,
                    price: price,
                    costPrice: cost,
                    isActive: isActive,
                    syncStatus: 'PENDING',
                  );
                  await _repo.insertProduct(newProduct);
                } else {
                  final updated = existing.copyWith(
                    name: name,
                    price: price,
                    costPrice: cost,
                    isActive: isActive,
                    syncStatus: 'PENDING',
                  );
                  await _repo.updateProduct(updated);
                }

                if (!mounted) return;
                Navigator.pop(ctx);
                _loadProducts();
                // Refresh catalog in POS controller
                context.read<PosController>().loadCatalog(tenant.id);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Kelola Menu & Produk',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditProductDialog(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.slate300),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada produk tersimpan',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tekan tombol Tambah Menu untuk membuat produk lokal.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate400),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
                  itemCount: _products.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final p = _products[idx];
                    return GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(14),
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.slate400),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(p.price),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryDark),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.slate600),
                            onPressed: () => _showAddEditProductDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Hapus Produk?'),
                                  content: Text('Yakin ingin menghapus ${p.name}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _repo.deleteProduct(p.id);
                                _loadProducts();
                                final tenant = context.read<AuthController>().currentTenant;
                                if (tenant != null) {
                                  context.read<PosController>().loadCatalog(tenant.id);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

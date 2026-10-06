import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/held_cart_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../history/screens/transaction_history_screen.dart';
import '../../products/screens/product_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../shifts/controllers/shift_controller.dart';
import '../../sync/controllers/sync_controller.dart';
import '../../sync/widgets/sync_status_badge.dart';
import '../controllers/pos_controller.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';

class PosCatalogScreen extends StatefulWidget {
  const PosCatalogScreen({super.key});

  @override
  State<PosCatalogScreen> createState() => _PosCatalogScreenState();
}

class _PosCatalogScreenState extends State<PosCatalogScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCtrl = context.read<AuthController>();
      final tenant = authCtrl.currentTenant;
      if (tenant != null) {
        context.read<PosController>().loadCatalog(tenant.id);
        context.read<SyncController>().checkPendingSyncCount(tenant.id);
        context.read<ShiftController>().checkActiveShift(tenant.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showHeldCartsModal(BuildContext context) {
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant == null) return;
    final posCtrl = context.read<PosController>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pesanan Ditahan (Hold Carts)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.slate900),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih pesanan yang ingin dipanggil kembali untuk melanjutkan transaksi.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            const Divider(height: 20),
            Expanded(
              child: posCtrl.heldCarts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pause_circle_outline_rounded, size: 48, color: AppColors.slate300),
                          const SizedBox(height: 12),
                          const Text('Tidak ada pesanan yang ditahan',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: posCtrl.heldCarts.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (c, i) {
                        final held = posCtrl.heldCarts[i];
                        return GlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(14),
                          backgroundColor: Colors.white,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      held.label,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate900),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${held.totalItems} item • ${CurrencyFormatter.format(held.totalAmount)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600),
                                    ),
                                    if (held.customerName != null)
                                      Text(
                                        'Pelanggan: ${held.customerName}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                onPressed: () async {
                                  await posCtrl.deleteHeldCart(tenant.id, held.id);
                                  if (posCtrl.heldCarts.isEmpty && context.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  await posCtrl.recallHeldCart(tenant.id, held);
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    Navigator.push(context, MaterialPageRoute(builder: (c) => const CartScreen()));
                                  }
                                },
                                child: const Text('Buka', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final posCtrl = context.watch<PosController>();
    final shiftCtrl = context.watch<ShiftController>();
    final tenant = authCtrl.currentTenant;
    final products = posCtrl.filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tenant?.name ?? 'OmniPOS Toko',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(width: 8),
                const SyncStatusBadge(),
              ],
            ),
            Text(
              shiftCtrl.hasActiveShift
                  ? 'Shift Aktif • Kas: ${CurrencyFormatter.format(shiftCtrl.activeShift!.startingCash)}'
                  : 'Shift Kasir Ditutup',
              style: TextStyle(
                fontSize: 11,
                color: shiftCtrl.hasActiveShift ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Hold Carts Button with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.slate700),
                tooltip: 'Pesanan Ditahan (Hold)',
                onPressed: () => _showHeldCartsModal(context),
              ),
              if (posCtrl.heldCarts.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${posCtrl.heldCarts.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: AppColors.slate700),
            tooltip: 'Riwayat Transaksi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const TransactionHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFBEB), // Amber 50
                    Color(0xFFF8FAFC), // Slate 50
                  ],
                ),
              ),
            ),
          ),

          // Main Column: Search + Category Tabs + 2-Column Product Grid
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  backgroundColor: Colors.white.withOpacity(0.9),
                  borderColor: Colors.white,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Cari menu di katalog kasir...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate400),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.slate400),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.slate400),
                              onPressed: () {
                                _searchCtrl.clear();
                                posCtrl.setSearchQuery('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => posCtrl.setSearchQuery(val),
                  ),
                ),
              ),

              // Category Pills (Horizontal Scroll)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryPill(
                      id: 'ALL',
                      name: 'Semua Menu',
                      isSelected: posCtrl.selectedCategoryId == 'ALL',
                      onTap: () => posCtrl.selectCategory('ALL'),
                    ),
                    ...posCtrl.categories.map((cat) {
                      return _buildCategoryPill(
                        id: cat.id,
                        name: cat.name,
                        isSelected: posCtrl.selectedCategoryId == cat.id,
                        onTap: () => posCtrl.selectCategory(cat.id),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Product Grid 2-Kolom (Identik Web App)
              Expanded(
                child: posCtrl.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: AppColors.slate300),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tidak ada produk ditemukan',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, // 2-Kolom
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.74,
                            ),
                            itemCount: products.length,
                            itemBuilder: (ctx, idx) {
                              final p = products[idx];
                              final cartIndex = posCtrl.cart.indexWhere((c) => c.product.id == p.id);
                              final qty = cartIndex >= 0 ? posCtrl.cart[cartIndex].quantity : 0;

                              return ProductCard(
                                product: p,
                                cartQuantity: qty,
                                onAddToCart: () => posCtrl.addToCart(p),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Floating Cart Bar (Muncul bila cart > 0)
          if (posCtrl.totalCartItems > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 80,
              child: GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: AppColors.slate900.withOpacity(0.92),
                borderColor: AppColors.slate800,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const CartScreen()),
                  );
                },
                child: Row(
                  children: [
                    // Badge Jumlah Item
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${posCtrl.totalCartItems} Item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Total Tagihan
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total Pesanan',
                            style: TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            CurrencyFormatter.format(posCtrl.totalCartAmount),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tombol Lihat Keranjang
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Keranjang',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String id,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.slate900 : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.slate900 : AppColors.slate200,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.slate900.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.slate700,
            ),
          ),
        ),
      ),
    );
  }
}

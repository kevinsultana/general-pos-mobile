import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/promotion_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/pos_controller.dart';
import '../widgets/payment_modal.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _openPaymentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentModal(
        onPaymentSuccess: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCustomerPicker(BuildContext context) async {
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant == null) return;
    final repo = LocalRepository();
    final customers = await repo.getCustomers(tenant.id);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Pelanggan', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Pelanggan Umum (Tanpa Nama)', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                context.read<PosController>().selectCustomer(null);
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            if (customers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada pelanggan tersimpan. Tambahkan di menu Pelanggan.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: customers.length,
                  itemBuilder: (c, idx) {
                    final cust = customers[idx];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primary50,
                        child: Icon(Icons.person, color: AppColors.primaryDark),
                      ),
                      title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(cust.phone ?? '-'),
                      onTap: () {
                        context.read<PosController>().selectCustomer(cust);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPromoPicker(BuildContext context) async {
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant == null) return;
    final repo = LocalRepository();
    final promos = await repo.getPromotions(tenant.id);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Kupon Diskon', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            if (promos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada kupon promo aktif.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
              )
            else
              ...promos.map((pr) {
                return ListTile(
                  leading: const Icon(Icons.confirmation_num_outlined, color: AppColors.primaryDark),
                  title: Text('${pr.code} - ${pr.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    pr.discountType == 'PERCENTAGE'
                        ? 'Diskon ${pr.discountValue.toInt()}%'
                        : 'Potongan ${CurrencyFormatter.format(pr.discountValue)}',
                  ),
                  onTap: () {
                    context.read<PosController>().applyPromo(pr);
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showHoldCartDialog(BuildContext context) {
    final labelCtrl = TextEditingController(text: 'Meja / Pelanggan');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Simpan Keranjang Sementara (Hold)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catatan / Label Keranjang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                hintText: 'Misal: Meja 4 / Kak Budi',
                filled: true,
                fillColor: AppColors.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final tenant = context.read<AuthController>().currentTenant;
              if (tenant == null) return;
              await context.read<PosController>().holdCurrentCart(tenant.id, labelCtrl.text.trim());
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pesanan berhasil disimpan sementara (Hold Cart).')),
              );
            },
            child: const Text('Simpan Pesanan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();
    final cartItems = posCtrl.cart;
    final selectedCustomer = posCtrl.selectedCustomer;
    final appliedPromo = posCtrl.appliedPromo;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Keranjang Pesanan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.slate900,
          ),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.slate700),
              tooltip: 'Simpan Keranjang (Hold)',
              onPressed: () => _showHoldCartDialog(context),
            ),
          if (cartItems.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Kosongkan Keranjang?'),
                    content: const Text('Semua item pesanan yang dipilih akan dihapus.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      TextButton(
                        onPressed: () {
                          posCtrl.clearCart();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Kosongkan', style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, size: 36, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keranjang Belanja Kosong',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Silakan pilih produk dari katalog kasir untuk mulai bertransaksi.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali ke Katalog'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 180),
              children: [
                // Pelanggan & Promo Bar
                Row(
                  children: [
                    // Customer Chip
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showCustomerPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.slate600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedCustomer?.name ?? 'Pilih Pelanggan',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.slate400),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Promo Chip
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showPromoPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: appliedPromo != null ? AppColors.primary50 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: appliedPromo != null ? AppColors.primary : AppColors.slate200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.confirmation_num_outlined,
                                  size: 18, color: appliedPromo != null ? AppColors.primaryDark : AppColors.slate600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  appliedPromo?.code ?? 'Kupon Promo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: appliedPromo != null ? AppColors.primaryDark : AppColors.slate800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (appliedPromo != null)
                                GestureDetector(
                                  onTap: () => posCtrl.removePromo(),
                                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                                )
                              else
                                const Icon(Icons.arrow_drop_down, color: AppColors.slate400),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // List Items
                ...cartItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(14),
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.format(item.product.price),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 16, color: AppColors.slate700),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => posCtrl.updateQuantity(item.product.id, item.quantity - 1),
                                    ),
                                    Text('${item.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 16, color: AppColors.slate700),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => posCtrl.updateQuantity(item.product.id, item.quantity + 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Catatan Khusus Menu Ini
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.slate50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.slate200.withOpacity(0.8)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primaryDark),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item.notes,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      hintText: 'Catatan menu (misal: Sedikit pedas, tanpa es)...',
                                      hintStyle: TextStyle(fontSize: 11, color: AppColors.slate400),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onChanged: (val) => posCtrl.updateItemNotes(item.product.id, val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Subtotal: ${CurrencyFormatter.format(item.subtotal)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
      bottomSheet: cartItems.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (posCtrl.discountAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Diskon Kupon (${appliedPromo?.code}):',
                                style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
                            Text('- ${CurrencyFormatter.format(posCtrl.discountAmount)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total (${posCtrl.totalCartItems} Item):',
                                style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                CurrencyFormatter.format(posCtrl.totalCartAmount),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate900),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () => _openPaymentModal(context),
                          child: const Row(
                            children: [
                              Text('Bayar Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/pos_controller.dart';

class PaymentModal extends StatefulWidget {
  final VoidCallback onPaymentSuccess;

  const PaymentModal({super.key, required this.onPaymentSuccess});

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final _customerNameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  double _cashPaid = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final posCtrl = context.read<PosController>();
    _cashPaid = posCtrl.totalCartAmount;
    _cashCtrl.text = _cashPaid.toInt().toString();
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  void _setExactAmount(double amount) {
    setState(() {
      _cashPaid = amount;
      _cashCtrl.text = amount.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();
    final authCtrl = context.watch<AuthController>();
    final total = posCtrl.totalCartAmount;
    final change = _cashPaid - total;
    final isSufficient = change >= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pembayaran Kasir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.slate500),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total Tagihan Card
            GlassCard(
              borderRadius: 18,
              padding: const EdgeInsets.all(16),
              backgroundColor: AppColors.slate900,
              borderColor: AppColors.slate800,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Tagihan',
                        style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Metode: Tunai (Cash)',
                        style: TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Input Nama Pelanggan (General)
            const Text(
              'Nama Pelanggan (Opsional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _customerNameCtrl,
              decoration: InputDecoration(
                hintText: 'Contoh: Kak Budi / Pelanggan Umum',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.slate400),
                filled: true,
                fillColor: AppColors.slate50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            // Input Uang Tunai Diterima
            const Text(
              'Uang Tunai Diterima (Rp)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _cashCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate900),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate500),
                filled: true,
                fillColor: AppColors.slate50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                setState(() {
                  _cashPaid = double.tryParse(val) ?? 0;
                });
              },
            ),
            const SizedBox(height: 10),

            // Quick Shortcut Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickButton('Uang Pas', total),
                  const SizedBox(width: 8),
                  if (total < 20000) _buildQuickButton('20.000', 20000),
                  if (total < 20000) const SizedBox(width: 8),
                  if (total < 50000) _buildQuickButton('50.000', 50000),
                  if (total < 50000) const SizedBox(width: 8),
                  if (total < 100000) _buildQuickButton('100.000', 100000),
                  if (total < 100000) const SizedBox(width: 8),
                  _buildQuickButton('150.000', 150000),
                  const SizedBox(width: 8),
                  _buildQuickButton('200.000', 200000),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kembalian Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSufficient ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSufficient ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSufficient ? 'Kembalian:' : 'Uang Kurang:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSufficient ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(change.abs()),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSufficient ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Selesaikan Transaksi Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSufficient ? AppColors.primary : AppColors.slate300,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (!isSufficient || _isProcessing)
                    ? null
                    : () async {
                        setState(() {
                          _isProcessing = true;
                        });

                        final tenant = authCtrl.currentTenant;
                        if (tenant == null) return;

                        final trx = await posCtrl.processCheckout(
                          tenantId: tenant.id,
                          branchId: tenant.branchId,
                          customerName: _customerNameCtrl.text.trim(),
                          cashPaid: _cashPaid,
                          changeAmount: change,
                        );

                        if (!mounted) return;
                        Navigator.pop(context); // Tutup modal bayar
                        _showSuccessDialog(trx);
                        widget.onPaymentSuccess();
                      },
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Selesaikan Transaksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, double amount) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _setExactAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cashPaid == amount ? AppColors.primary : AppColors.slate100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _cashPaid == amount ? AppColors.primaryDark : AppColors.slate200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _cashPaid == amount ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(TransactionModel trx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transaksi Berhasil!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate900),
            ),
            const SizedBox(height: 6),
            Text(
              trx.receiptNumber,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 12, color: AppColors.slate600)),
                      Text(CurrencyFormatter.format(trx.totalAmount),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bayar Tunai:', style: TextStyle(fontSize: 12, color: AppColors.slate600)),
                      Text(CurrencyFormatter.format(trx.cashPaid),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembalian:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(trx.changeAmount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Transaksi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

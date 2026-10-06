import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../settings/services/printer_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final LocalRepository _repo = LocalRepository();
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant != null) {
      _transactions = await _repo.getTransactions(tenant.id);
    }
    setState(() => _isLoading = false);
  }

  void _showDetailModal(TransactionModel trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trx.receiptNumber,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(DateTime.tryParse(trx.createdAt) ?? DateTime.now()),
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trx.syncStatus == 'SYNCED' ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: trx.syncStatus == 'SYNCED' ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    trx.syncStatus == 'SYNCED' ? 'Cloud Synced' : 'Lokal (Pending)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: trx.syncStatus == 'SYNCED' ? AppColors.success : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Daftar Menu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...trx.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity}x ${item.productName}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 16),
                        child: Text(
                          'Catatan: ${item.notes}',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.slate500),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                Text(
                  CurrencyFormatter.format(trx.totalAmount),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.slate900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Cetak Struk Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final tenant = context.read<AuthController>().currentTenant;
                  PrinterService.instance.printReceipt(
                    storeName: tenant?.name ?? 'OmniPOS Toko',
                    transaction: trx,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mengirim data struk ke printer...')),
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
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Riwayat Transaksi Lokal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.slate300),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada transaksi',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Transaksi kasir akan tersimpan di database lokal SQLite.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate400),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transactions.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final trx = _transactions[idx];
                    final date = DateTime.tryParse(trx.createdAt) ?? DateTime.now();

                    return GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(14),
                      backgroundColor: Colors.white.withOpacity(0.9),
                      onTap: () => _showDetailModal(trx),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_rounded, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trx.receiptNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${trx.items.length} item • ${DateFormat('dd/MM HH:mm').format(date)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(trx.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate900),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: trx.syncStatus == 'SYNCED' ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  trx.syncStatus == 'SYNCED' ? 'Cloud' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: trx.syncStatus == 'SYNCED' ? AppColors.success : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../shifts/controllers/shift_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocalRepository _repo = LocalRepository();
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant != null) {
      final res = await _repo.getDashboardMetrics(tenant.id);
      setState(() {
        _metrics = res;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final shiftCtrl = context.watch<ShiftController>();
    final tenant = authCtrl.currentTenant;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Ringkasan & Analytics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate700),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Store & Shift Status Banner
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(18),
                    backgroundColor: AppColors.slate900,
                    borderColor: AppColors.slate800,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tenant?.name ?? 'Toko OmniPOS',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: shiftCtrl.hasActiveShift ? const Color(0xFF064E3B) : const Color(0xFF881337),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: shiftCtrl.hasActiveShift ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    shiftCtrl.hasActiveShift ? 'Shift Kasir Aktif' : 'Shift Belum Dibuka',
                                    style: TextStyle(
                                      color: shiftCtrl.hasActiveShift ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Total Penjualan Hari Ini',
                          style: TextStyle(fontSize: 12, color: AppColors.slate400, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(_metrics?['totalSales'] ?? 0),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tunai', style: TextStyle(color: AppColors.slate400, fontSize: 10)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(_metrics?['cashSales'] ?? 0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Non-Tunai', style: TextStyle(color: AppColors.slate400, fontSize: 10)),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(_metrics?['nonCashSales'] ?? 0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Transaksi', style: TextStyle(color: AppColors.slate400, fontSize: 10)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_metrics?['totalTrx'] ?? 0}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Top 5 Produk Terlaris
                  const Text(
                    'Menu Terlaris (Berdasarkan Kuantitas Terjual)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 10),
                  if ((_metrics?['topProducts'] as List?)?.isEmpty ?? true)
                    GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(24),
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: const Center(
                        child: Text(
                          'Belum ada data penjualan tercatat.',
                          style: TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ),
                    )
                  else
                    ...((_metrics?['topProducts'] as List).asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: idx == 1 ? AppColors.primary : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$idx',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: idx == 1 ? Colors.white : AppColors.slate700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['product_name'] ?? 'Produk',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate900),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item['total_qty']} terjual',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item['total_revenue'] ?? 0),
                                    style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    })),
                ],
              ),
            ),
    );
  }
}

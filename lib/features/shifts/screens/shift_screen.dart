import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/shift_controller.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenant = context.read<AuthController>().currentTenant;
      if (tenant != null) {
        context.read<ShiftController>().checkActiveShift(tenant.id);
      }
    });
  }

  void _showStartShiftDialog() {
    final cashCtrl = TextEditingController(text: '100000');
    final cashierCtrl = TextEditingController(
      text: context.read<AuthController>().currentTenant?.ownerName ?? 'Kasir Utama',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buka Shift Kasir Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nama Kasir Bertugas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: cashierCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.slate100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Modal Kas Awal di Laci (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.slate100,
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final startingCash = double.tryParse(cashCtrl.text) ?? 0;
              final cashierName = cashierCtrl.text.trim();
              final tenant = context.read<AuthController>().currentTenant;
              if (tenant == null) return;

              await context.read<ShiftController>().startShift(
                tenantId: tenant.id,
                branchId: tenant.branchId,
                cashierName: cashierName.isNotEmpty ? cashierName : 'Kasir',
                startingCash: startingCash,
              );

              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Shift kasir berhasil dibuka!')),
              );
            },
            child: const Text('Buka Shift'),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog(ShiftModel activeShift) {
    final actualCashCtrl = TextEditingController(text: activeShift.expectedCash.toInt().toString());
    double actualCash = activeShift.expectedCash;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final discrepancy = actualCash - activeShift.expectedCash;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Tutup Shift Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Modal Awal:', style: TextStyle(fontSize: 12)),
                            Text(CurrencyFormatter.format(activeShift.startingCash),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Penjualan Tunai:', style: TextStyle(fontSize: 12)),
                            Text(CurrencyFormatter.format(activeShift.cashSales),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Uang Seharusnya:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(CurrencyFormatter.format(activeShift.expectedCash),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Hitung Uang Fisik Aktual di Laci (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: actualCashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.slate50,
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setDState(() {
                        actualCash = double.tryParse(val) ?? 0;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: discrepancy == 0
                          ? const Color(0xFFECFDF5)
                          : (discrepancy > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1F2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          discrepancy == 0 ? 'Status: Kas Pas' : (discrepancy > 0 ? 'Selisih Lebih:' : 'Selisih Kurang:'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: discrepancy == 0
                                ? AppColors.success
                                : (discrepancy > 0 ? AppColors.info : AppColors.danger),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(discrepancy.abs()),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: discrepancy == 0
                                ? AppColors.success
                                : (discrepancy > 0 ? AppColors.info : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  await context.read<ShiftController>().closeShift(actualCash: actualCash);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift kasir berhasil ditutup dan direkap.')),
                  );
                },
                child: const Text('Konfirmasi Tutup Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftCtrl = context.watch<ShiftController>();
    final active = shiftCtrl.activeShift;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Manajemen Shift Kasir',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active Shift Banner / Card
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            backgroundColor: active != null ? AppColors.slate900 : Colors.white.withOpacity(0.9),
            borderColor: active != null ? AppColors.slate800 : Colors.white,
            child: active != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                              ),
                              const SizedBox(width: 8),
                              const Text('Shift Kasir Sedang Berjalan',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            ],
                          ),
                          Text(
                            DateFormat('HH:mm').format(DateTime.tryParse(active.startedAt) ?? DateTime.now()),
                            style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Kasir Bertugas: ${active.cashierName}',
                          style: const TextStyle(color: AppColors.slate300, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Modal Kas Awal', style: TextStyle(color: AppColors.slate400, fontSize: 10)),
                                Text(CurrencyFormatter.format(active.startingCash),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Penjualan Tunai', style: TextStyle(color: AppColors.slate400, fontSize: 10)),
                                Text(CurrencyFormatter.format(active.cashSales),
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Uang Seharusnya', style: TextStyle(color: AppColors.slate400, fontSize: 10)),
                                Text(CurrencyFormatter.format(active.expectedCash),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.lock_clock_rounded, size: 18),
                          label: const Text('Tutup Shift & Rekap Kas', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showCloseShiftDialog(active),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Icon(Icons.lock_open_rounded, size: 40, color: AppColors.primary),
                      const SizedBox(height: 10),
                      const Text('Belum Ada Shift Kasir yang Dibuka',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.slate900)),
                      const SizedBox(height: 4),
                      const Text(
                        'Buka shift kasir untuk mulai merekam transaksi dan kas masuk hari ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showStartShiftDialog,
                        child: const Text('Buka Shift Kasir Sekarang'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // Riwayat Shift Kasir
          const Text('Riwayat Shift Sebelumnya',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900)),
          const SizedBox(height: 10),
          if (shiftCtrl.shiftHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada riwayat shift.', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
              ),
            )
          else
            ...shiftCtrl.shiftHistory.map((s) {
              final started = DateTime.tryParse(s.startedAt) ?? DateTime.now();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(14),
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: s.isOpen ? const Color(0xFFECFDF5) : AppColors.slate100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          s.isOpen ? Icons.timer_outlined : Icons.check_circle_outline_rounded,
                          color: s.isOpen ? AppColors.success : AppColors.slate500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shift ${s.cashierName}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(started),
                              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(s.totalSales),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate900),
                          ),
                          Text(
                            '${s.totalTransactions} transaksi',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/promotion_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  final LocalRepository _repo = LocalRepository();
  List<PromotionModel> _promos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    setState(() => _isLoading = true);
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant != null) {
      _promos = await _repo.getPromotions(tenant.id);
    }
    setState(() => _isLoading = false);
  }

  void _showAddPromoDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController(text: '0');
    String discountType = 'PERCENTAGE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Buat Kupon Promo Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Promo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Misal: Promo Weekend 10%',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Kode Kupon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'DISKON10',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Tipe Diskon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Persentase (%)'),
                        selected: discountType == 'PERCENTAGE',
                        onSelected: (val) => setDState(() => discountType = 'PERCENTAGE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Nominal (Rp)'),
                        selected: discountType == 'FIXED',
                        onSelected: (val) => setDState(() => discountType = 'FIXED'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  discountType == 'PERCENTAGE' ? 'Besar Diskon (%)' : 'Besar Diskon (Rp)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: discountType == 'PERCENTAGE' ? '10' : '5000',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Minimal Belanja (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: minOrderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    fillColor: AppColors.slate100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
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
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim().toUpperCase();
                final value = double.tryParse(valueCtrl.text) ?? 0;
                final minOrder = double.tryParse(minOrderCtrl.text) ?? 0;

                if (name.isEmpty || code.isEmpty || value <= 0) return;
                final tenant = context.read<AuthController>().currentTenant;
                if (tenant == null) return;

                final promo = PromotionModel(
                  id: IdGenerator.v4(),
                  tenantId: tenant.id,
                  name: name,
                  code: code,
                  discountType: discountType,
                  discountValue: value,
                  minOrderAmount: minOrder,
                );

                await _repo.insertPromotion(promo);
                if (!mounted) return;
                Navigator.pop(ctx);
                _loadPromotions();
              },
              child: const Text('Simpan Promo'),
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
        title: const Text('Kupon & Promo Diskon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900)),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Promo', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddPromoDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _promos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.discount_outlined, size: 48, color: AppColors.slate300),
                      const SizedBox(height: 12),
                      const Text('Belum ada kupon promo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
                  itemCount: _promos.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final promo = _promos[idx];
                    return GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(14),
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.confirmation_num_outlined, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      promo.code,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate900),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        promo.discountType == 'PERCENTAGE'
                                            ? '${promo.discountValue.toInt()}% OFF'
                                            : CurrencyFormatter.format(promo.discountValue),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(promo.name, style: const TextStyle(fontSize: 12, color: AppColors.slate600)),
                                if (promo.minOrderAmount > 0)
                                  Text(
                                    'Min. Belanja: ${CurrencyFormatter.format(promo.minOrderAmount)}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                            onPressed: () async {
                              await _repo.deletePromotion(promo.id);
                              _loadPromotions();
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

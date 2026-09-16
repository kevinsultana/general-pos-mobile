import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../widgets/promotion_form_dialog.dart';

class PromotionListScreen extends ConsumerWidget {
  const PromotionListScreen({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Promotion promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Promosi'),
        content: Text(
          'Yakin ingin menghapus promosi "${promo.name}"? Transaksi yang sudah menggunakan promo ini tidak akan terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(promotionRepositoryProvider).deletePromotion(promo.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Promosi berhasil dihapus'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(promotionListStreamProvider);
    final canManagePromotions =
        ref.watch(hasPermissionProvider(AppPermissions.managePromotions));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Promosi & Voucher',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (canManagePromotions) ...[
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Buat Promo Baru',
              onPressed: () => PromotionFormDialog.show(context),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      floatingActionButton: canManagePromotions
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => PromotionFormDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Promo Baru'),
            )
          : null,
      body: Column(
        children: [
          // Banner Notice (PRD: Owner configuration)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Promosi & voucher otomatis divalidasi oleh sistem kasir saat transaksi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: promotionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (promotions) {
                if (promotions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Promosi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Buat voucher diskon atau promosi belanja untuk menarik pelanggan toko Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                PromotionFormDialog.show(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tambah Promosi Pertama'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: promotions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final promo = promotions[index];

                    final discountText = promo.discountType == 'PERCENTAGE'
                        ? '${promo.discountValue}%'
                        : CurrencyFormatter.format(promo.discountValue);

                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: promo.active
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    promo.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: promo.active,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: canManagePromotions
                                      ? (val) {
                                          ref
                                              .read(promotionRepositoryProvider)
                                              .togglePromotionActive(promo.id, val);
                                        }
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Tags row (Discount amount & Voucher code)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.discount_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Diskon $discountText',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (promo.code != null &&
                                    promo.code!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.amber.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 14,
                                          color: Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          promo.code!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Min spend info
                            if (promo.minSpend > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Min. Belanja: ${CurrencyFormatter.format(promo.minSpend)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),

                            // Action buttons (Only if user has permission)
                            if (canManagePromotions) ...[
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => PromotionFormDialog.show(
                                      context,
                                      promotion: promo,
                                    ),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 16),
                                    label: const Text('Ubah'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                    ),
                                    onPressed: () =>
                                        _confirmDelete(context, ref, promo),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16),
                                    label: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

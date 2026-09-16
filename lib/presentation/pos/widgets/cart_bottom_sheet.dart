import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/app_database.dart';
import '../controllers/cart_controller.dart';
import '../../payment/widgets/payment_sheet.dart';
import 'customer_picker_sheet.dart';
import 'discount_dialog.dart';
import 'voucher_dialog.dart';

class CartBottomSheet extends ConsumerStatefulWidget {
  const CartBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CartBottomSheet(),
    );
  }

  @override
  ConsumerState<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends ConsumerState<CartBottomSheet> {
  late final TextEditingController _queueController;

  @override
  void initState() {
    super.initState();
    final cartState = ref.read(cartControllerProvider);
    _queueController = TextEditingController(text: cartState.queueNumber ?? '');
  }

  @override
  void dispose() {
    _queueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final cartNotifier = ref.read(cartControllerProvider.notifier);
    final store = ref.watch(currentStoreStreamProvider).valueOrNull;
    final canCreateTransaction =
        ref.watch(hasPermissionProvider(AppPermissions.createTransaction));

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Keranjang Pesanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cartState.totalItemCount} item',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (cartState.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger),
                        onPressed: () {
                          cartNotifier.clearCart();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Kosongkan'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Order Configuration (Order Type & Queue Number & Customer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.backgroundLight,
            child: Column(
              children: [
                Row(
                  children: [
                    // Order Type Selector
                    Expanded(
                      flex: 3,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'DINE_IN',
                            label: Text('Dine In', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.restaurant_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'TAKEAWAY',
                            label: Text('Takeaway', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.takeout_dining_rounded, size: 16),
                          ),
                        ],
                        selected: {cartState.orderType},
                        onSelectionChanged: (val) {
                          cartNotifier.setOrderType(val.first);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Queue Number Input
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _queueController,
                        decoration: const InputDecoration(
                          hintText: 'No. Antrian (cth: #05)',
                          prefixIcon: Icon(Icons.confirmation_number_outlined,
                              size: 18),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          cartNotifier.setQueueNumber(val);
                        },
                      ),
                    ),
                  ],
                ),

                // Customer Selector (PRD 26: Only if customerEnabled)
                if (store?.customerEnabled == true) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<Customer?>(
                    future: cartState.customerId != null
                        ? ref
                            .read(customerRepositoryProvider)
                            .getCustomerById(cartState.customerId!)
                        : Future.value(null),
                    builder: (context, snapshot) {
                      final customer = snapshot.data;
                      if (customer != null) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pelanggan: ${customer.name}${customer.phone != null && customer.phone!.isNotEmpty ? ' (${customer.phone})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => cartNotifier.clearCustomer(),
                                child: const Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.danger),
                              ),
                            ],
                          ),
                        );
                      }

                      return InkWell(
                        onTap: () async {
                          final selected = await CustomerPickerSheet.show(
                            context,
                            selectedCustomerId: cartState.customerId,
                          );
                          if (selected != null) {
                            cartNotifier.setCustomer(selected.id);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_alt_1_outlined,
                                  size: 16, color: AppColors.textSecondaryLight),
                              SizedBox(width: 6),
                              Text(
                                '+ Tetapkan Pelanggan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Items List
          Expanded(
            child: cartState.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Keranjang Masih Kosong',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pilih produk dari katalog untuk memulai pesanan',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    itemCount: cartState.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (ctx, index) {
                      final item = cartState.items[index];
                      final hasDiscount = item.discountAmount > 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product & Variant Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(item.unitPrice),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Stepper buttons (- / count / +)
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: AppColors.borderLight),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => cartNotifier
                                          .decrementQuantity(item.uniqueKey),
                                      borderRadius: const BorderRadius.horizontal(
                                          left: Radius.circular(8)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        child: Icon(Icons.remove, size: 16),
                                      ),
                                    ),
                                    Container(
                                      constraints:
                                          const BoxConstraints(minWidth: 32),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => cartNotifier
                                          .incrementQuantity(item.uniqueKey),
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              right: Radius.circular(8)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        child: Icon(Icons.add, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Item Total Price
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(item.total),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  if (hasDiscount)
                                    Text(
                                      CurrencyFormatter.format(item.subtotal),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Line Discount Button / Tag
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  DiscountDialog.show(
                                    context,
                                    title: 'Diskon Item: ${item.displayName}',
                                    baseAmount: item.subtotal,
                                    initialType: item.discountType,
                                    initialValue: item.discountValue,
                                    onApply: (type, val) {
                                      cartNotifier.setItemDiscount(
                                          item.uniqueKey, type, val);
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: hasDiscount
                                        ? AppColors.danger.withValues(alpha: 0.1)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: hasDiscount
                                          ? AppColors.danger.withValues(alpha: 0.3)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasDiscount
                                            ? Icons.discount_rounded
                                            : Icons.add_circle_outline_rounded,
                                        size: 13,
                                        color: hasDiscount
                                            ? AppColors.danger
                                            : AppColors.textSecondaryLight,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hasDiscount
                                            ? 'Diskon: -${CurrencyFormatter.format(item.discountAmount)} (${item.discountType == 'PERCENTAGE' ? '${item.discountValue}%' : 'Nominal'})'
                                            : '+ Diskon Item',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: hasDiscount
                                              ? AppColors.danger
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Colors.grey),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    cartNotifier.removeItem(item.uniqueKey),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Price Calculation Summary & Actions
          if (cartState.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondaryLight),
                      ),
                      Text(
                        CurrencyFormatter.format(cartState.rawSubtotal),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Line Discounts Total
                  if (cartState.itemDiscountsTotal > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Diskon Item',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.danger),
                        ),
                        Text(
                          '-${CurrencyFormatter.format(cartState.itemDiscountsTotal)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Order Discount & Voucher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Diskon Transaksi',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight),
                          ),
                          if (cartState.voucherCode != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cartState.voucherCode!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              VoucherDialog.show(
                                context,
                                baseAmount: cartState.orderSubtotal,
                                cartItems: cartState.items,
                                currentVoucherCode: cartState.voucherCode,
                                currentPromotionId: cartState.promotionId,
                                initialType: cartState.orderDiscountType,
                                initialValue: cartState.orderDiscountValue,
                                onApply: ({
                                  required discountType,
                                  required discountValue,
                                  promotionId,
                                  voucherCode,
                                }) {
                                  if (promotionId != null) {
                                    cartNotifier.setPromotion(
                                      promotionId: promotionId,
                                      voucherCode: voucherCode,
                                      discountType: discountType!,
                                      discountValue: discountValue!,
                                    );
                                  } else {
                                    cartNotifier.setOrderDiscount(
                                      discountType,
                                      discountValue,
                                    );
                                  }
                                },
                              );
                            },
                            child: Icon(
                              cartState.orderDiscountAmount > 0
                                  ? Icons.edit_rounded
                                  : Icons.add_circle_outline_rounded,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        cartState.orderDiscountAmount > 0
                            ? '-${CurrencyFormatter.format(cartState.orderDiscountAmount)}'
                            : 'Rp 0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cartState.orderDiscountAmount > 0
                              ? AppColors.danger
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Tagihan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(cartState.grandTotal),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons (Simpan Draft & Bayar)
                  Column(
                    children: [
                      if (!canCreateTransaction) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 14, color: AppColors.warning),
                              SizedBox(width: 6),
                              Text(
                                'Akses kasir terbatas (perlu izin create_transaction)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          // Simpan Draft
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimaryLight,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: !canCreateTransaction
                                  ? null
                                  : () async {
                                      try {
                                        final draftId =
                                            await cartNotifier.saveAsDraft();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              content: Text(
                                                'Draft pesanan berhasil disimpan (ID: ${draftId.substring(0, 8)}...)',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppColors.danger,
                                              content: Text(
                                                  'Gagal menyimpan draft: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Simpan Draft'),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Bayar
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: !canCreateTransaction
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      PaymentSheet.show(context);
                                    },
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text(
                                'Bayar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

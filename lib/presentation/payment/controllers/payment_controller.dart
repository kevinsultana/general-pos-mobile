import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../domain/models/payment_input.dart';
import '../../../domain/repositories/i_store_repository.dart';
import '../../../domain/repositories/i_transaction_repository.dart';
import '../../../domain/services/cash_rounding_calculator.dart';
import '../../pos/controllers/cart_controller.dart';

final paymentControllerProvider =
    StateNotifierProvider<PaymentController, AsyncValue<String?>>((ref) {
  final trxRepo = ref.watch(transactionRepositoryProvider);
  final storeRepo = ref.watch(storeRepositoryProvider);
  return PaymentController(ref, trxRepo, storeRepo);
});

class PaymentController extends StateNotifier<AsyncValue<String?>> {
  final Ref _ref;
  final ITransactionRepository _trxRepo;
  final IStoreRepository _storeRepo;

  PaymentController(this._ref, this._trxRepo, this._storeRepo)
      : super(const AsyncValue.data(null));

  /// Completes a transaction with one or more payments
  Future<String> completePayment({
    required List<PaymentInput> payments,
    String storeId = AppConstants.defaultStoreId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final cartState = _ref.read(cartControllerProvider);
      if (cartState.isEmpty) {
        throw Exception('Keranjang belanja kosong');
      }

      // Validate PRD Bab 21 & INV-013: Non-cash payments cannot have rounding
      for (final p in payments) {
        if (p.paymentType != 'CASH' && p.roundingAmount != 0) {
          throw ArgumentError(
            'Cash rounding hanya berlaku untuk metode pembayaran CASH, namun tipe ${p.paymentType} memiliki roundingAmount: ${p.roundingAmount}',
          );
        }
      }

      // Calculate total rounding amount strictly from cash payments
      final roundingAmount = payments
          .where((p) => p.paymentType == 'CASH')
          .fold<int>(0, (sum, p) => sum + p.roundingAmount);

      final totalPayable = cartState.grandTotal + roundingAmount;

      final transactionId = await _trxRepo.completeTransaction(
        storeId: storeId,
        orderType: cartState.orderType,
        queueNumber: cartState.queueNumber,
        customerId: cartState.customerId,
        promotionId: cartState.promotionId,
        subtotal: cartState.orderSubtotal,
        discountType: cartState.orderDiscountType,
        discountValue: cartState.orderDiscountValue,
        discountTotal: cartState.orderDiscountAmount,
        roundingAmount: roundingAmount,
        total: totalPayable,
        items: cartState.items,
        payments: payments,
        draftId: cartState.loadedDraftId,
      );

      // Reset cart after successful transaction
      _ref.read(cartControllerProvider.notifier).clearCart();

      // Trigger automatic background push in Cloud Mode
      if (_ref.read(isCloudModeProvider)) {
        _ref.read(syncCoordinatorProvider).triggerImmediatePush();
      }

      state = AsyncValue.data(transactionId);
      return transactionId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Cancels a completed transaction with stock reversal
  Future<void> cancelTransaction({
    required String transactionId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _trxRepo.cancelTransaction(
        transactionId: transactionId,
        reason: reason,
      );

      // Trigger automatic background push in Cloud Mode
      if (_ref.read(isCloudModeProvider)) {
        _ref.read(syncCoordinatorProvider).triggerImmediatePush();
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Refunds a transaction with stock reversal
  Future<String> refundTransaction({
    required String transactionId,
    required String reason,
    required List<RefundItemInput> items,
    required int totalRefundAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final refundId = await _trxRepo.refundTransaction(
        transactionId: transactionId,
        reason: reason,
        items: items,
        totalRefundAmount: totalRefundAmount,
      );

      // Trigger automatic background push in Cloud Mode
      if (_ref.read(isCloudModeProvider)) {
        _ref.read(syncCoordinatorProvider).triggerImmediatePush();
      }

      state = const AsyncValue.data(null);
      return refundId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Fetches cash rounding settings for the store
  Future<CashRoundingResult> calculateCashRounding(int rawAmount) async {
    final store = await _storeRepo.getStore(AppConstants.defaultStoreId);
    final enabled = store?.cashRoundingEnabled ?? true;
    final increment = store?.cashRoundingIncrement ?? 1000;
    final modeStr = store?.cashRoundingMode ?? 'ROUND_NEAREST';

    final mode = CashRoundingMode.fromString(modeStr);
    const calculator = CashRoundingCalculator();

    return calculator.calculate(
      amount: rawAmount,
      mode: mode,
      increment: increment,
      enabled: enabled,
    );
  }
}

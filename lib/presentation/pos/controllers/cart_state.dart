import '../../../domain/models/cart_item.dart';
import '../../../domain/services/transaction_calculator.dart';

class CartState {
  final List<CartItem> items;
  final String orderType; // 'DINE_IN' or 'TAKEAWAY'
  final String? queueNumber;
  final String? customerId;
  final String? orderDiscountType; // 'PERCENTAGE' or 'FIXED_AMOUNT'
  final int? orderDiscountValue;
  final String? loadedDraftId;
  final String? promotionId;
  final String? voucherCode;

  const CartState({
    this.items = const [],
    this.orderType = 'DINE_IN',
    this.queueNumber,
    this.customerId,
    this.orderDiscountType,
    this.orderDiscountValue,
    this.loadedDraftId,
    this.promotionId,
    this.voucherCode,
  });

  static const _calculator = TransactionCalculator();

  TransactionCalculationResult get calculation => _calculator.calculate(
        items: items,
        orderDiscountType: orderDiscountType,
        orderDiscountValue: orderDiscountValue,
      );

  int get rawSubtotal => calculation.rawSubtotal;
  int get itemDiscountsTotal => calculation.itemDiscountsTotal;
  int get orderSubtotal => calculation.orderSubtotal;
  int get orderDiscountAmount => calculation.orderDiscountAmount;
  int get grandTotal => calculation.grandTotal;
  int get totalCost => calculation.totalCost;
  int get grossProfit => calculation.grossProfit;
  int get totalItemCount => calculation.totalItemCount;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? orderType,
    String? queueNumber,
    String? customerId,
    String? orderDiscountType,
    int? orderDiscountValue,
    String? loadedDraftId,
    String? promotionId,
    String? voucherCode,
    bool clearOrderDiscount = false,
    bool clearLoadedDraft = false,
    bool clearQueueNumber = false,
    bool clearCustomer = false,
    bool clearPromotion = false,
  }) {
    return CartState(
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      queueNumber: clearQueueNumber ? null : (queueNumber ?? this.queueNumber),
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      orderDiscountType: clearOrderDiscount || clearPromotion
          ? null
          : (orderDiscountType ?? this.orderDiscountType),
      orderDiscountValue: clearOrderDiscount || clearPromotion
          ? null
          : (orderDiscountValue ?? this.orderDiscountValue),
      loadedDraftId: clearLoadedDraft ? null : (loadedDraftId ?? this.loadedDraftId),
      promotionId: clearPromotion ? null : (promotionId ?? this.promotionId),
      voucherCode: clearPromotion ? null : (voucherCode ?? this.voucherCode),
    );
  }
}


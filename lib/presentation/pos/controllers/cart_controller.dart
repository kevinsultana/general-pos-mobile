import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_providers.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/models/cart_item.dart';
import '../../../domain/repositories/i_draft_repository.dart';
import '../../../domain/repositories/i_product_repository.dart';
import 'cart_state.dart';

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
  final draftRepo = ref.watch(draftRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  return CartController(draftRepo, productRepo, ref);
});

class CartController extends StateNotifier<CartState> {
  final IDraftRepository _draftRepo;
  final IProductRepository _productRepo;
  final Ref? _ref;

  CartController(this._draftRepo, this._productRepo, [this._ref])
      : super(const CartState());

  /// Adds a product to the cart. If the product/variant already exists, increments quantity.
  void addProduct(Product product, {ProductVariant? variant, double quantity = 1}) {
    if (quantity <= 0) return;

    final key = variant != null ? '${product.id}:${variant.id}' : product.id;
    final index = state.items.indexWhere((i) => i.uniqueKey == key);

    if (index >= 0) {
      final existing = state.items[index];
      final updated = existing.copyWith(quantity: existing.quantity + quantity);
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = updated;
      state = state.copyWith(items: newItems);
    } else {
      final newItem = CartItem(
        productId: product.id,
        variantId: variant?.id,
        productName: product.name,
        variantName: variant?.name,
        sku: variant?.sku ?? product.sku,
        barcode: variant?.barcode ?? product.barcode,
        quantity: quantity,
        unitPrice: variant?.sellingPrice ?? product.sellingPrice,
        unitCostSnapshot: variant?.cost ?? product.cost,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  /// Looks up a product or variant by barcode and adds it to the cart.
  Future<bool> addByBarcode(String barcode, {String? storeId}) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return false;

    final String effectiveStoreId =
        storeId ?? _ref?.read(activeStoreIdProvider) ?? AppConstants.defaultStoreId;

    // Search product
    final product =
        await _productRepo.getProductByBarcode(effectiveStoreId, cleanBarcode);
    if (product != null) {
      addProduct(product);
      return true;
    }

    // Search variant
    final variant = await _productRepo.getVariantByBarcode(cleanBarcode);
    if (variant != null) {
      final parent = await _productRepo.getProductById(variant.productId);
      if (parent != null) {
        addProduct(parent, variant: variant);
        return true;
      }
    }

    return false;
  }

  /// Updates quantity of an item. Removes the item if newQuantity <= 0.
  void updateQuantity(String key, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(key);
      return;
    }

    final newItems = state.items.map((item) {
      if (item.uniqueKey == key) {
        return item.copyWith(quantity: newQuantity.toDouble());
      }
      return item;
    }).toList();

    state = state.copyWith(items: newItems);
  }

  void incrementQuantity(String key) {
    final item = state.items.firstWhere((i) => i.uniqueKey == key,
        orElse: () => throw Exception('Item not found'));
    updateQuantity(key, item.quantity.round() + 1);
  }

  void decrementQuantity(String key) {
    final item = state.items.firstWhere((i) => i.uniqueKey == key,
        orElse: () => throw Exception('Item not found'));
    updateQuantity(key, item.quantity.round() - 1);
  }

  /// Removes a single item from the cart
  void removeItem(String key) {
    state = state.copyWith(
      items: state.items.where((i) => i.uniqueKey != key).toList(),
    );
  }

  /// Clears the entire cart
  void clearCart() {
    state = const CartState();
  }

  /// Applies a line item discount
  void setItemDiscount(String key, String? type, int? value) {
    final newItems = state.items.map((item) {
      if (item.uniqueKey == key) {
        return item.copyWith(
          discountType: type,
          discountValue: value,
          clearDiscount: type == null || value == null || value <= 0,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: newItems);
  }

  /// Applies an order-level discount
  void setOrderDiscount(String? type, int? value) {
    if (type == null || value == null || value <= 0) {
      state = state.copyWith(clearOrderDiscount: true);
    } else {
      state = state.copyWith(
        orderDiscountType: type,
        orderDiscountValue: value,
      );
    }
  }

  /// Sets the order type (DINE_IN or TAKEAWAY)
  void setOrderType(String type) {
    state = state.copyWith(orderType: type);
  }

  /// Sets queue number
  void setQueueNumber(String? queueNumber) {
    if (queueNumber == null || queueNumber.trim().isEmpty) {
      state = state.copyWith(clearQueueNumber: true);
    } else {
      state = state.copyWith(queueNumber: queueNumber.trim());
    }
  }

  /// Sets customer ID
  void setCustomer(String? customerId) {
    if (customerId == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(customerId: customerId);
    }
  }

  /// Clears assigned customer
  void clearCustomer() {
    state = state.copyWith(clearCustomer: true);
  }

  /// Sets promotion/voucher on cart
  void setPromotion({
    required String promotionId,
    required String? voucherCode,
    required String discountType,
    required int discountValue,
  }) {
    state = state.copyWith(
      promotionId: promotionId,
      voucherCode: voucherCode,
      orderDiscountType: discountType,
      orderDiscountValue: discountValue,
    );
  }

  /// Clears active promotion from cart
  void clearPromotion() {
    state = state.copyWith(clearPromotion: true, clearOrderDiscount: true);
  }

  /// Saves the current cart state as a draft in the database.
  /// PRD rule: Draft transactions must NOT affect stock!
  Future<String> saveAsDraft({String? storeId}) async {
    if (state.isEmpty) {
      throw Exception('Keranjang belanja kosong');
    }

    final String effectiveStoreId =
        storeId ?? _ref?.read(activeStoreIdProvider) ?? AppConstants.defaultStoreId;

    final draftId = await _draftRepo.saveDraft(
      existingDraftId: state.loadedDraftId,
      storeId: effectiveStoreId,
      orderType: state.orderType,
      queueNumber: state.queueNumber,
      customerId: state.customerId,
      discountType: state.orderDiscountType,
      discountValue: state.orderDiscountValue,
      subtotal: state.orderSubtotal,
      discountTotal: state.orderDiscountAmount,
      total: state.grandTotal,
      items: state.items,
    );

    // Clear cart after saving
    clearCart();

    return draftId;
  }

  /// Loads a saved draft and populates the cart
  Future<void> loadDraft(Transaction draft) async {
    final rawItems = await _draftRepo.getDraftItems(draft.id);

    final cartItems = rawItems.map((item) {
      return CartItem(
        productId: item.productId,
        variantId: item.variantId,
        productName: item.productNameSnapshot,
        variantName: item.variantNameSnapshot,
        sku: item.skuSnapshot,
        barcode: item.barcodeSnapshot,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        unitCostSnapshot: item.unitCostSnapshot,
        discountType: item.discountType,
        discountValue: item.discountValue,
      );
    }).toList();

    state = CartState(
      items: cartItems,
      orderType: draft.orderType ?? 'DINE_IN',
      queueNumber: draft.queueNumber,
      customerId: draft.customerId,
      orderDiscountType: draft.discountType,
      orderDiscountValue: draft.discountValue,
      loadedDraftId: draft.id,
    );
  }
}

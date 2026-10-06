import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/cart_item_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/held_cart_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/promotion_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/id_generator.dart';

class PosController with ChangeNotifier {
  final LocalRepository _localRepo = LocalRepository();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  String _selectedCategoryId = 'ALL';
  String _searchQuery = '';
  final List<CartItemModel> _cart = [];
  bool _isLoading = false;

  CustomerModel? _selectedCustomer;
  PromotionModel? _appliedPromo;
  List<HeldCartModel> _heldCarts = [];

  List<CategoryModel> get categories => _categories;
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  List<CartItemModel> get cart => List.unmodifiable(_cart);
  bool get isLoading => _isLoading;
  CustomerModel? get selectedCustomer => _selectedCustomer;
  PromotionModel? get appliedPromo => _appliedPromo;
  List<HeldCartModel> get heldCarts => _heldCarts;

  int get totalCartItems => _cart.fold(0, (sum, item) => sum + item.quantity);
  double get rawCartAmount => _cart.fold(0, (sum, item) => sum + item.subtotal);

  double get discountAmount {
    if (_appliedPromo == null) return 0;
    return _appliedPromo!.calculateDiscount(rawCartAmount);
  }

  double get totalCartAmount {
    final net = rawCartAmount - discountAmount;
    return net > 0 ? net : 0;
  }

  List<ProductModel> get filteredProducts {
    return _products.where((p) {
      final matchesCategory = _selectedCategoryId == 'ALL' || p.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> loadCatalog(String tenantId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _localRepo.getCategories(tenantId);
      _products = await _localRepo.getProducts(tenantId);
      _heldCarts = await _localRepo.getHeldCarts(tenantId);

      // Jika database lokal masih kosong pertama kali, seed beberapa menu contoh awal
      if (_products.isEmpty) {
        await _seedInitialMenu(tenantId);
        _categories = await _localRepo.getCategories(tenantId);
        _products = await _localRepo.getProducts(tenantId);
      }
    } catch (e) {
      debugPrint('Error loading catalog: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _seedInitialMenu(String tenantId) async {
    final catCoffee = CategoryModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      name: 'Kopi & Minuman',
      sortOrder: 1,
    );
    final catFood = CategoryModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      name: 'Makanan & Snack',
      sortOrder: 2,
    );

    await _localRepo.insertCategory(catCoffee);
    await _localRepo.insertCategory(catFood);

    final p1 = ProductModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      categoryId: catCoffee.id,
      name: 'Kopi Susu Gula Aren',
      price: 18000,
      costPrice: 8000,
    );
    final p2 = ProductModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      categoryId: catCoffee.id,
      name: 'Americano Ice',
      price: 15000,
      costPrice: 5000,
    );
    final p3 = ProductModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      categoryId: catFood.id,
      name: 'Croissant Butter',
      price: 20000,
      costPrice: 10000,
    );

    await _localRepo.insertProduct(p1);
    await _localRepo.insertProduct(p2);
    await _localRepo.insertProduct(p3);

    // Seed contoh promo diskon awal
    final promo10 = PromotionModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      name: 'Diskon Grand Opening 10%',
      code: 'OPENING10',
      discountType: 'PERCENTAGE',
      discountValue: 10,
      minOrderAmount: 20000,
    );
    await _localRepo.insertPromotion(promo10);
  }

  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ================= CART OPERATIONS =================
  void addToCart(ProductModel product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _cart[index].quantity += 1;
    } else {
      _cart.add(CartItemModel(product: product, quantity: 1, notes: ''));
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int newQuantity) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (newQuantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = newQuantity;
      }
      notifyListeners();
    }
  }

  void updateItemNotes(String productId, String notes) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cart[index].notes = notes;
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    _appliedPromo = null;
    _selectedCustomer = null;
    notifyListeners();
  }

  // ================= CUSTOMER & PROMO =================
  void selectCustomer(CustomerModel? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void applyPromo(PromotionModel promo) {
    _appliedPromo = promo;
    notifyListeners();
  }

  void removePromo() {
    _appliedPromo = null;
    notifyListeners();
  }

  // ================= HOLD CART =================
  Future<void> holdCurrentCart(String tenantId, String label) async {
    if (_cart.isEmpty) return;

    final cartListMap = _cart.map((item) => {
      'product': item.product.toMap(),
      'quantity': item.quantity,
      'notes': item.notes,
    }).toList();

    final held = HeldCartModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      label: label.isNotEmpty ? label : 'Pesanan ${DateTime.now().hour}:${DateTime.now().minute}',
      cartJson: jsonEncode(cartListMap),
      customerName: _selectedCustomer?.name,
      totalAmount: totalCartAmount,
      totalItems: totalCartItems,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _localRepo.saveHeldCart(held);
    _heldCarts = await _localRepo.getHeldCarts(tenantId);
    clearCart();
    notifyListeners();
  }

  Future<void> recallHeldCart(String tenantId, HeldCartModel heldCart) async {
    try {
      final List<dynamic> decoded = jsonDecode(heldCart.cartJson);
      _cart.clear();
      for (final item in decoded) {
        final prod = ProductModel.fromMap(item['product']);
        final qty = (item['quantity'] as num).toInt();
        final notes = (item['notes'] as String?) ?? '';
        _cart.add(CartItemModel(product: prod, quantity: qty, notes: notes));
      }

      await _localRepo.deleteHeldCart(heldCart.id);
      _heldCarts = await _localRepo.getHeldCarts(tenantId);
      notifyListeners();
    } catch (e) {
      debugPrint('Recall cart error: $e');
    }
  }

  Future<void> deleteHeldCart(String tenantId, String heldCartId) async {
    await _localRepo.deleteHeldCart(heldCartId);
    _heldCarts = await _localRepo.getHeldCarts(tenantId);
    notifyListeners();
  }

  // ================= CHECKOUT =================
  Future<TransactionModel> processCheckout({
    required String tenantId,
    String? branchId,
    String? shiftId,
    String? customerName,
    String? customerPhone,
    required double cashPaid,
    required double changeAmount,
    double? customTotalAmount,
  }) async {
    final trxId = IdGenerator.v4();
    final receiptNum = IdGenerator.receiptNumber();
    final nowIso = DateTime.now().toIso8601String();

    final List<TransactionItemModel> items = _cart.map((cartItem) {
      return TransactionItemModel(
        id: IdGenerator.v4(),
        transactionId: trxId,
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        price: cartItem.product.price,
        quantity: cartItem.quantity,
        subtotal: cartItem.subtotal,
        notes: cartItem.notes,
      );
    }).toList();

    final transaction = TransactionModel(
      id: trxId,
      tenantId: tenantId,
      branchId: branchId,
      shiftId: shiftId,
      customerId: _selectedCustomer?.id,
      receiptNumber: receiptNum,
      customerName: customerName?.isNotEmpty == true
          ? customerName
          : (_selectedCustomer?.name ?? 'Pelanggan Umum'),
      customerPhone: customerPhone ?? _selectedCustomer?.phone,
      totalAmount: customTotalAmount ?? totalCartAmount,
      discountAmount: discountAmount,
      promoCode: _appliedPromo?.code,
      cashPaid: cashPaid,
      changeAmount: changeAmount,
      paymentMethod: 'CASH',
      syncStatus: 'PENDING',
      createdAt: nowIso,
      items: items,
    );

    // Simpan ke SQLite lokal & update penjualan shift
    await _localRepo.createTransaction(transaction, items);

    // Reset keranjang
    clearCart();

    return transaction;
  }
}

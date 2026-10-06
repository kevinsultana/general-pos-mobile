import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;
  String notes;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.notes = '',
  });

  double get subtotal => product.price * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    String? notes,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}

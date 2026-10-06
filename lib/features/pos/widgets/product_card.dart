import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/glass_card.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final int cartQuantity;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.cartQuantity,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      backgroundColor: Colors.white.withOpacity(0.85),
      borderColor: Colors.white.withOpacity(0.95),
      onTap: product.isActive ? onAddToCart : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar / Placeholder dengan AspectRatio 4:3 (identik web apps)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.slate100,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),

                  // Badge Habis / Nonaktif jika ada
                  if (!product.isActive)
                    Container(
                      color: AppColors.slate900.withOpacity(0.6),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HABIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // Badge Kuantitas di Keranjang jika > 0
                  if (cartQuantity > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$cartQuantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Nama Produk
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
              height: 1.25,
            ),
          ),
          const Spacer(),

          // Harga & Tombol Tambah
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  CurrencyFormatter.format(product.price),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: product.isActive ? AppColors.primary : AppColors.slate300,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: product.isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: 32,
        color: AppColors.slate300,
      ),
    );
  }
}

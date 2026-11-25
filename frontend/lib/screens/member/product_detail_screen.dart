import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/screens/member/cart_screen.dart';

import '../../core/format.dart';
import '../../models/cart_models.dart';
import '../../models/product_models.dart';
import '../../providers/cart_provider.dart';
import '../../services/product_service.dart';

import 'package:http/http.dart' as http;
import '../../widgets/top_notice.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;

  ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final ProductService _productService = ProductService(client: http.Client());

  ProductDetail? _product;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedImageIndex = 0;
  ProductVariant? _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final product = await _productService.getProductById(widget.productId, useOffline: true);
      if (!mounted) return;
      setState(() {
        _product = product;
        _isLoading = false;
        if (product.variants.isNotEmpty) {
          _selectedVariant = product.variants.firstWhere(
            (v) => v.isActive,
            orElse: () => product.variants.first,
          );
        }
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Tồn kho của biến thể đang chọn.
  int get _stock => _selectedVariant?.stockQuantity ?? 0;

  /// Số lượng biến thể đang chọn đã có trong giỏ.
  int get _inCart {
    final cart = ref.read(cartProvider);
    final vid = _selectedVariant?.id;
    return cart.items
        .where((i) => i.product.id == _product?.id && i.variant?.id == vid)
        .fold(0, (sum, i) => sum + i.quantity);
  }

  bool get _canBuy =>
      (_selectedVariant?.isActive ?? false) && _stock > 0 && _inCart < _stock;

  double get _currentPrice =>
      _selectedVariant?.price ?? _product?.variants.first.price ?? 0.0;

  bool get _isInStock =>
      _selectedVariant?.isActive ?? _product?.isActive ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _product != null
            ? Text(_product!.name, maxLines: 1, overflow: TextOverflow.ellipsis)
            : const Text('Chi tiết sản phẩm'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildError()
          : _product == null
          ? const Center(child: Text('Không tìm thấy sản phẩm'))
          : _buildProductDetail(),
      bottomNavigationBar: _product != null && _isInStock
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadProduct, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetail() {
    final product = _product!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDiscount = product.variants.isNotEmpty
        ? _selectedVariant != null &&
              _selectedVariant!.compareAtPrice != null &&
              _selectedVariant!.compareAtPrice! > _selectedVariant!.price
        : false;

    final images = product.images.where((img) => img.isPrimary).toList();
    if (images.isEmpty && product.images.isNotEmpty) {
      images.addAll(product.images);
    }

    return RefreshIndicator(
      onRefresh: _loadProduct,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageGallery(images),
                if (product.variants.length > 1) _buildVariantSelector(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${product.categoryName} · ${product.brandName}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatVnd(_currentPrice),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 12),
                            Text(
                              formatVnd(_selectedVariant!.compareAtPrice!),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildQuantitySelector(),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        Text(
                          'Mô tả sản phẩm',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (product.variants.isNotEmpty) _buildVariantDetails(),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Space for bottom bar
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<ProductImage> images) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.devices, size: 80, color: scheme.outline),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) =>
                setState(() => _selectedImageIndex = index),
            itemBuilder: (context, index) {
              final img = images[index];
              return Image.network(
                img.fullImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.devices, size: 80, color: scheme.outline),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedImageIndex == index
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantSelector() {
    final product = _product!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phiên bản',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: product.variants.map((variant) {
              final isSelected = _selectedVariant?.id == variant.id;
              final isActive = variant.isActive;

              return FilterChip(
                label: Text(_getVariantLabel(variant)),
                selected: isSelected,
                onSelected: isActive
                    ? (_) => setState(() {
                        _selectedVariant = variant;
                        _quantity = 1;
                      })
                    : null,
                selectedColor: scheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Nhãn tồn kho ngắn gọn. Giỏ hàng không giữ hàng (kho chỉ bị trừ khi đặt đơn),
  /// nên hiển thị cả tồn thật lẫn số đã chọn trong giỏ.
  String _stockLabel(ProductVariant variant) {
    if (!variant.inStock) return 'Hết hàng';
    final inCart = variant.id == _selectedVariant?.id ? _inCart : 0;
    if (inCart <= 0) return 'Còn ${variant.stockQuantity} sản phẩm';
    if (inCart >= variant.stockQuantity) return 'Đã chọn hết số còn lại';
    return 'Còn ${variant.stockQuantity} (đã chọn $inCart)';
  }

  String _getVariantLabel(ProductVariant variant) {
    final parts = <String>[];
    if (variant.color != null) parts.add(variant.color!);
    if (variant.storage != null) parts.add(variant.storage!);
    if (parts.isEmpty) return variant.sku;
    return parts.join(' / ');
  }

  Widget _buildVariantDetails() {
    final product = _product!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông số kỹ thuật',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: product.variants.map((variant) {
                final hasDiscount =
                    variant.compareAtPrice != null &&
                    variant.compareAtPrice! > variant.price;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getVariantLabel(variant),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'SKU: ${variant.sku}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatVnd(variant.price),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            if (hasDiscount)
                              Text(
                                formatVnd(variant.compareAtPrice!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: variant.inStock
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : scheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _stockLabel(variant),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: variant.inStock
                                      ? Colors.green
                                      : scheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          'Số lượng:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 50),
                alignment: Alignment.center,
                child: Text(
                  '$_quantity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _quantity < (_stock - _inCart)
                    ? () => setState(() => _quantity++)
                    : null,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Add to wishlist - future feature
                  showTopNotice(context, 'Đã thêm vào danh sách yêu thích');
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('Yêu thích'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _canBuy ? _addToCart : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  _stock <= 0 || !(_selectedVariant?.isActive ?? false)
                      ? 'Hết hàng'
                      : (_inCart >= _stock ? 'Đã hết hàng' : 'Thêm vào giỏ'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart() {
    final product = _product!;

    // Kiểm tra tồn kho: số lượng thêm + số đã có trong giỏ không vượt quá tồn
    final available = _stock - _inCart;
    if (_quantity > available) {
      showTopNotice(context, available <= 0
                ? 'Bạn đã thêm tối đa số lượng còn trong kho ($_stock).'
                : 'Chỉ còn thêm được $available sản phẩm (kho còn $_stock).');
      setState(() => _quantity = available > 0 ? available : 1);
      return;
    }
    final cartItem = CartItem(
      product: ProductListItem(
        id: product.id,
        name: product.name,
        categoryId: product.categoryId,
        categoryName: product.categoryName,
        brandId: product.brandId,
        brandName: product.brandName,
        price: _currentPrice,
        compareAtPrice: _selectedVariant?.compareAtPrice,
        primaryImageUrl: product.images.isNotEmpty
            ? product.images.first.imageUrl
            : null,
        stockQuantity: _stock,
        isActive: product.isActive,
        createdAt: product.createdAt,
      ),
      variant: _selectedVariant,
      quantity: _quantity,
    );

    ref.read(cartProvider.notifier).addItem(cartItem);
    final addedQuantity = _quantity;
    setState(() => _quantity = 1);

    // Lấy trước navigator: nếu người dùng đã rời màn này thì `context` của State
    // đã bị hủy và bấm "Xem giỏ" sẽ ném lỗi "unmounted".
    final navigator = Navigator.of(context);
    showTopNotice(
      context,
      'Đã thêm $addedQuantity "${product.name}" vào giỏ hàng',
      actionLabel: 'Xem giỏ',
      onAction: () => navigator.push(
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ),
    );
  }
}

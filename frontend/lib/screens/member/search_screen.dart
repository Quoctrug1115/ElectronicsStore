import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../models/cart_models.dart';
import '../../models/product_models.dart';
import '../../providers/cart_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/error_banner.dart';
import '../member/product_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final ProductService _productService = ProductService(client: http.Client());

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ProductListItem> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _pageIndex = 1;
  final int _pageSize = 10;
  String? _errorMessage;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (_isLoading || (!_hasMore && !reset)) return;
    if (_currentQuery.trim().isEmpty) return;

    if (reset) {
      _pageIndex = 1;
      _hasMore = true;
      _products.clear();
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _productService.getProducts(
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        search: _currentQuery.trim(),
        sortBy: 'newest',
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _products.clear();
        }
        _products.addAll(result.items);
        _pageIndex++;
        _hasMore = result.hasNextPage;
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchSubmitted(String query) {
    final trimmed = query.trim();
    if (trimmed == _currentQuery) return;
    _currentQuery = trimmed;
    _loadProducts(reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    _currentQuery = '';
    setState(() {
      _products.clear();
      _hasMore = true;
      _pageIndex = 1;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartQuantity = ref.watch(cartTotalQuantityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm sản phẩm'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: cartQuantity > 99 ? const Text('99+') : Text('$cartQuantity'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () {
              DefaultTabController.of(context)?.animateTo(1);
            },
            tooltip: 'Giỏ hàng',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _onSearchSubmitted,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          if (_currentQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kết quả cho: "$_currentQuery"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _currentQuery.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => _loadProducts(reset: true),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (_isLoading && _products.isEmpty)
                          const SliverFillRemaining(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_errorMessage != null && _products.isEmpty)
                          SliverFillRemaining(
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              children: [
                                const SizedBox(height: 96),
                                ErrorBanner(message: _errorMessage!),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _loadProducts(reset: true),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        else if (_products.isEmpty)
                          SliverFillRemaining(
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 96),
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                const Center(
                                    child: Text('Không tìm thấy sản phẩm nào.')),
                              ],
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 280,
                              ),
                              itemCount: _products.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _products.length) {
                                  return _buildLoadingCard();
                                }
                                return _buildProductCard(_products[index]);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_outlined,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Tìm kiếm sản phẩm',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập từ khóa để tìm sản phẩm bạn muốn',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductListItem p) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDiscount = p.compareAtPrice != null && p.compareAtPrice! > p.price;
    final isOutOfStock = !p.isActive;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: p.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: p.fullPrimaryImageUrl.isNotEmpty
                          ? Image.network(
                              p.fullPrimaryImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.devices,
                                size: 40,
                                color: scheme.outline,
                              ),
                            )
                          : Icon(Icons.devices, size: 40, color: scheme.outline),
                    ),
                  ),
                  if (isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Hết hàng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: isOutOfStock
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: isOutOfStock
                            ? null
                            : () {
                                ref.read(cartProvider.notifier).addItem(
                                  CartItem(product: p, quantity: 1),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã thêm "${p.name}" vào giỏ hàng'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                                color: isOutOfStock
                                    ? scheme.surface
                                    : scheme.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Thêm',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOutOfStock
                                      ? scheme.surface
                                      : scheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.categoryName} · ${p.brandName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatVnd(p.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: scheme.primary,
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      formatVnd(p.compareAtPrice!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 100,
                  color: scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 12),
                Container(
                  height: 20,
                  width: 80,
                  color: scheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
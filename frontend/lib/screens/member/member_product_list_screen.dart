import 'package:flutter/material.dart';
import 'package:frontend/screens/member/cart_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/cart_models.dart';
import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../providers/cart_provider.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/error_banner.dart';
import 'product_detail_screen.dart';

class MemberProductListScreen extends ConsumerStatefulWidget {
  final String? initialSortBy;

  MemberProductListScreen({super.key, this.initialSortBy});

  @override
  ConsumerState<MemberProductListScreen> createState() =>
      _MemberProductListScreenState();
}

class _MemberProductListScreenState extends ConsumerState<MemberProductListScreen> {
  final ProductService _productService = ProductService(client: http.Client());
  final CategoryService _categoryService = CategoryService(
    client: http.Client(),
  );

  final List<ProductListItem> _products = [];
  List<CategoryResponse> _categories = [];
  bool _isLoadingCategories = true;
  bool _isLoadingProducts = true;
  bool _hasMoreProducts = true;
  int _pageIndex = 1;
  final int _pageSize = 10;
  String? _errorMessage;

  String _search = '';
  int? _categoryId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadProducts();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories(isActive: true);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (_isLoadingProducts || (!_hasMoreProducts && !reset)) return;

    if (reset) {
      _pageIndex = 1;
      _hasMoreProducts = true;
      _products.clear();
    }

    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });

    try {
      final result = await _productService.getProducts(
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        search: _search.isEmpty ? null : _search,
        categoryId: _categoryId,
        sortBy: widget.initialSortBy ?? 'newest',
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _products.clear();
        }
        _products.addAll(result.items);
        _pageIndex++;
        _hasMoreProducts = result.hasNextPage;
        _isLoadingProducts = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadCategories();
    await _loadProducts(reset: true);
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim();
    if (trimmed == _search) return;
    setState(() => _search = trimmed);
    _loadProducts(reset: true);
  }

  void _onCategoryChanged(int? categoryId) {
    if (categoryId == _categoryId) return;
    setState(() => _categoryId = categoryId);
    _loadProducts(reset: true);
  }

  void _clearSearch() {
    if (_search.isEmpty) return;
    setState(() => _search = '');
    _loadProducts(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final cartQuantity = ref.watch(cartTotalQuantityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: cartQuantity > 99 ? const Text('99+') : Text('$cartQuantity'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            },
            tooltip: 'Giỏ hàng',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _buildFilterBar(),
            ),
            if (_isLoadingProducts && _products.isEmpty)
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
                    FilledButton(onPressed: () => _loadProducts(reset: true), child: const Text('Thử lại')),
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
                    const Center(child: Text('Không có sản phẩm nào.')),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 280,
                  ),
                  itemCount: _products.length + (_hasMoreProducts ? 1 : 0),
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
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            enabled: !_isLoadingProducts,
            textInputAction: TextInputAction.search,
            controller: TextEditingController(text: _search),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sản phẩm',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
            onSubmitted: _onSearchChanged,
            onChanged: (v) {
              _onSearchChanged(v);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: _isLoadingCategories
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (_, __) => _buildCategoryShimmer(),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _categoryChip('Tất cả', null),
                      for (final c in _categories) _categoryChip(c.name, c.id),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Container(
          width: 60,
          height: 20,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        selected: false,
        onSelected: null,
      ),
    );
  }

  Widget _categoryChip(String label, int? id) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _categoryId == id,
        onSelected: _isLoadingProducts
            ? null
            : (_) => _onCategoryChanged(id),
      ),
    );
  }

  Widget _buildProductCard(ProductListItem p) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDiscount = p.compareAtPrice != null && p.compareAtPrice! > p.price;
    final isOutOfStock = !p.inStock;

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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../models/cart_models.dart';
import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../providers/cart_provider.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/error_banner.dart';
import '../member/product_detail_screen.dart';
import '../member/category_products_screen.dart';
import '../member/search_screen.dart';
import '../member/member_product_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ProductService _productService = ProductService(client: http.Client());
  final CategoryService _categoryService = CategoryService(client: http.Client());

  List<CategoryResponse> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoriesError;

  final List<ProductListItem> _latestProducts = [];
  bool _isLoadingLatest = true;
  bool _hasMoreLatest = true;
  int _latestPage = 1;
  final int _pageSize = 10;
  String? _latestError;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadLatestProducts();
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
      _loadLatestProducts();
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
        _categoriesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadLatestProducts({bool reset = false}) async {
    if (_isLoadingLatest || (!_hasMoreLatest && !reset)) return;

    if (reset) {
      _latestPage = 1;
      _hasMoreLatest = true;
      _latestProducts.clear();
    }

    setState(() {
      _isLoadingLatest = true;
      _latestError = null;
    });

    try {
      final result = await _productService.getProducts(
        pageIndex: _latestPage,
        pageSize: _pageSize,
        sortBy: 'newest',
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _latestProducts.clear();
        }
        _latestProducts.addAll(result.items);
        _latestPage++;
        _hasMoreLatest = result.hasNextPage;
        _isLoadingLatest = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLatest = false;
        _latestError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadCategories();
    await _loadLatestProducts(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final cartQuantity = ref.watch(cartTotalQuantityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Electronics Store'),
        actions: [
          IconButton(
            icon: _buildCartBadge(cartQuantity),
            onPressed: () {
              DefaultTabController.of(context)?.animateTo(1);
            },
            tooltip: 'Giỏ hàng',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SearchScreen()),
              );
            },
            tooltip: 'Tìm kiếm',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (_isLoadingCategories && _categories.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SliverToBoxAdapter(
                child: _buildCategoryBar(),
              ),
              SliverToBoxAdapter(
                child: _buildSectionHeader('Sản phẩm mới nhất', onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberProductListScreen(initialSortBy: 'newest'),
                    ),
                  );
                }),
              ),
              _isLoadingLatest && _latestProducts.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _latestError != null && _latestProducts.isEmpty
                      ? SliverFillRemaining(
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 96),
                              ErrorBanner(message: _latestError!),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _loadLatestProducts(reset: true),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      : _latestProducts.isEmpty
                          ? SliverFillRemaining(
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 96),
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  const Center(child: Text('Chưa có sản phẩm nào.')),
                                ],
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              sliver: SliverGrid.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 280,
                                ),
                                itemCount: _latestProducts.length +
                                    (_hasMoreLatest ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _latestProducts.length) {
                                    return _buildLoadingCard();
                                  }
                                  return _buildProductCard(_latestProducts[index]);
                                },
                              ),
                            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartBadge(int quantity) {
    return Badge(
      isLabelVisible: quantity > 0,
      label: quantity > 99 ? const Text('99+') : Text('$quantity'),
      child: const Icon(Icons.shopping_cart_outlined),
    );
  }

  Widget _buildCategoryBar() {
    if (_isLoadingCategories) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          itemBuilder: (_, __) => _buildCategoryShimmer(),
        ),
      );
    }

    if (_categoriesError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(message: _categoriesError!),
      );
    }

    final allCategories = <CategoryResponse>[
      CategoryResponse(
        id: 0,
        name: 'Tất cả',
        isActive: true,
        createdAt: DateTime.now(),
      ),
      ..._categories,
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          return _CategoryChip(
            category: category,
            onTap: () {
              if (category.id == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberProductListScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryProductsScreen(category: category),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    final theme = Theme.of(context);
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('Xem tất cả')),
        ],
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

class _CategoryChip extends StatelessWidget {
  final CategoryResponse category;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainerHighest,
                image: category.fullImageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(category.fullImageUrl),
                        fit: BoxFit.cover,
                        onError: (_, __) {},
                      )
                    : null,
              ),
              child: category.fullImageUrl.isEmpty
                  ? Icon(Icons.category_outlined,
                      size: 32, color: scheme.outline)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
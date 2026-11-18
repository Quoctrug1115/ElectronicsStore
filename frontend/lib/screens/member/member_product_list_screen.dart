import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/error_banner.dart';

class MemberProductListScreen extends StatefulWidget {
  const MemberProductListScreen({super.key});

  @override
  State<MemberProductListScreen> createState() =>
      _MemberProductListScreenState();
}

class _MemberProductListScreenState extends State<MemberProductListScreen> {
  final ProductService _productService = ProductService(client: http.Client());
  final CategoryService _categoryService = CategoryService(
    client: http.Client(),
  );

  PagedResult<ProductListItem>? _paged;
  List<CategoryResponse> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  int _pageIndex = 1;
  final int _pageSize = 10;
  String _search = '';
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool resetPage = true}) async {
    if (resetPage) _pageIndex = 1;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final futures = <Future>[];
      futures.add(
        _productService.getProducts(
          pageIndex: _pageIndex,
          pageSize: _pageSize,
          search: _search.isEmpty ? null : _search,
          categoryId: _categoryId,
        ),
      );
      futures.add(_categoryService.getCategories());
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _paged = results[0] as PagedResult<ProductListItem>;
        _categories = results[1] as List<CategoryResponse>;
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm')),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _paged == null
                  ? _buildError()
                  : _buildProductGrid(),
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        ErrorBanner(message: _errorMessage!),
        const SizedBox(height: 16),
        FilledButton(onPressed: _loadData, child: const Text('Thử lại')),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            enabled: !_isLoading,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sản phẩm',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _search = '');
                        _loadData();
                      },
                    )
                  : null,
            ),
            onSubmitted: (v) {
              setState(() => _search = v.trim());
              _loadData();
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
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

  Widget _categoryChip(String label, int? id) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _categoryId == id,
        onSelected: _isLoading
            ? null
            : (_) async {
                setState(() => _categoryId = id);
                await _loadData();
              },
      ),
    );
  }

  Widget _buildProductGrid() {
    final items = _paged!.items;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Center(child: Text('Không có sản phẩm.')),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const hPadding = 16.0, gap = 12.0;
        final cardWidth = (constraints.maxWidth - hPadding * 2 - gap) / 2;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final extent = cardWidth / 1.15 + 140 * textScale;
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(hPadding, 4, hPadding, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: extent,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildProductCard(items[index]),
        );
      },
    );
  }

  Widget _buildProductCard(ProductListItem p) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDiscount = p.compareAtPrice != null && p.compareAtPrice! > p.price;

    return Card(
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
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
                  if (!p.isActive)
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

  Widget _buildPagination() {
    final paged = _paged;
    if (paged == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Trang ${paged.pageIndex}/${paged.totalPages} '
              '(${paged.totalCount} sản phẩm)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Trang trước',
                onPressed: (_isLoading || !paged.hasPreviousPage)
                    ? null
                    : () {
                        setState(() => _pageIndex--);
                        _loadData(resetPage: false);
                      },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Trang sau',
                onPressed: (_isLoading || !paged.hasNextPage)
                    ? null
                    : () {
                        setState(() => _pageIndex++);
                        _loadData(resetPage: false);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

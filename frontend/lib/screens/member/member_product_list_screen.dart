import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/error_banner.dart';

class MemberProductListScreen extends StatefulWidget {
  const MemberProductListScreen({super.key});

  @override
  State<MemberProductListScreen> createState() => _MemberProductListScreenState();
}

class _MemberProductListScreenState extends State<MemberProductListScreen> {
  final ProductService _productService = ProductService(client: http.Client());
  final CategoryService _categoryService = CategoryService(client: http.Client());

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
      futures.add(_productService.getProducts(
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        search: _search.isEmpty ? null : _search,
        categoryId: _categoryId,
      ));
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
      appBar: AppBar(
        title: const Text('Danh sách Sản phẩm'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _paged == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ErrorBanner(message: _errorMessage!),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadData,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      : _buildProductList(),
            ),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Tìm kiếm sản phẩm',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
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
          DropdownButtonFormField<int?>(
            decoration: const InputDecoration(
              labelText: 'Lọc theo danh mục',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            value: _categoryId,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Tất cả danh mục'),
              ),
            ]..addAll(
                _categories.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.name),
                  ),
                ),
              ),
            onChanged: _isLoading
                ? null
                : (v) async {
                    setState(() => _categoryId = v);
                    await _loadData();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final items = _paged!.items;
    if (items.isEmpty) {
      return const Center(child: Text('Không có sản phẩm.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: p.fullPrimaryImageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      p.fullPrimaryImageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.devices, size: 40),
                    ),
                  )
                : const Icon(Icons.devices, size: 40),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${p.categoryName} · ${p.brandName}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${p.price.toStringAsFixed(0)} đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    if (p.compareAtPrice != null &&
                        p.compareAtPrice! > p.price) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${p.compareAtPrice!.toStringAsFixed(0)} đ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: p.isActive
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        p.isActive ? 'Còn hàng' : 'Hết hàng',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.isActive
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Chi tiết sản phẩm (có thể mở màn hình chi tiết sau)
            },
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    final paged = _paged;
    if (paged == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trang ${paged.pageIndex}/${paged.totalPages} '
            '(${paged.totalCount} sản phẩm)',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

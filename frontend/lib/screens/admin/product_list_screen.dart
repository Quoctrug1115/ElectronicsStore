import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../services/brand_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../core/format.dart';
import '../../widgets/admin_widgets.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService(client: http.Client());
  final CategoryService _categoryService = CategoryService(client: http.Client());
  final BrandService _brandService = BrandService(client: http.Client());

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

  Future<void> _deleteProduct(int id, String name) async {
    final confirmed = await confirmDelete(
      context,
      entity: 'sản phẩm',
      name: name,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _productService.deleteProduct(id);
      if (!mounted) return;
      await _loadData(resetPage: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa sản phẩm thành công.')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _openForm({ProductListItem? product}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          productService: _productService,
          brandService: _brandService,
          product: product,
        ),
      ),
    );
    if (!mounted) return;
    _loadData(resetPage: false);
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
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ErrorRetry(
                              message: _errorMessage!,
                              onRetry: _loadData,
                            ),
                          ],
                        )
                      : _buildProductList(),
            ),
          ),
        ],
      ),
      // Đặt thanh phân trang ở bottomNavigationBar để nút "Thêm sản phẩm"
      // tự nổi phía trên, không che nút chuyển trang.
      bottomNavigationBar: _buildPagination(),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag riêng: các tab nằm cùng IndexedStack nên tag mặc định sẽ bị trùng.
        heroTag: 'fab_product',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
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
            enabled: !_isLoading,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm theo tên',
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

  Widget _buildProductList() {
    final items = _paged!.items;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'Không có sản phẩm.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildRow(items[index]),
    );
  }

  Widget _buildRow(ProductListItem p) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final hasDiscount =
        p.compareAtPrice != null && p.compareAtPrice! > p.price;

    return Card(
      child: InkWell(
        onTap: () => _openForm(product: p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              AdminThumb(
                url: p.fullPrimaryImageUrl,
                icon: Icons.devices_outlined,
                size: 68,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.categoryName} · ${p.brandName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatVnd(p.price),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                        if (hasDiscount)
                          Text(
                            formatVnd(p.compareAtPrice!),
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(isActive: p.isActive),
                        Text(
                          p.stockQuantity > 0 ? 'Tồn: ${p.stockQuantity}' : 'Hết hàng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.stockQuantity > 0
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        Text(
                          formatDate(p.createdAt),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              RowMenu(
                onEdit: () => _openForm(product: p),
                onDelete: () => _deleteProduct(p.id, p.name),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final paged = _paged;
    if (paged == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
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
    );
  }
}

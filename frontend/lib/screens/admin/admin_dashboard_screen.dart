import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../models/brand_models.dart';
import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../models/revenue_models.dart';
import '../../services/brand_service.dart';
import '../../services/admin_stats_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/revenue_section.dart';
import 'brand_form_screen.dart';
import 'category_form_screen.dart';
import 'product_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenCategories,
    required this.onOpenBrands,
    required this.onDataChanged,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenBrands;

  final VoidCallback onDataChanged;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ProductService _productService = ProductService(client: http.Client());
  final CategoryService _categoryService = CategoryService(
    client: http.Client(),
  );
  final BrandService _brandService = BrandService(client: http.Client());
  final AdminStatsService _statsService = AdminStatsService(client: http.Client());

  RevenueStats? _revenue;
  bool _revenueLoading = true;
  String? _revenueError;

  PagedResult<ProductListItem>? _products;
  List<CategoryResponse> _categories = [];
  List<BrandResponse> _brands = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loadRevenue();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _productService.getProducts(pageIndex: 1, pageSize: 5),
        _categoryService.getCategories(),
        _brandService.getBrands(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as PagedResult<ProductListItem>;
        _categories = results[1] as List<CategoryResponse>;
        _brands = results[2] as List<BrandResponse>;
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

  /// Doanh thu tải riêng: nếu lỗi (ví dụ backend cũ chưa có API) thì các phần còn lại của Tổng quan vẫn hiện.
  Future<void> _loadRevenue() async {
    setState(() {
      _revenueLoading = true;
      _revenueError = null;
    });
    try {
      final stats = await _statsService.getRevenue();
      if (!mounted) return;
      setState(() {
        _revenue = stats;
        _revenueLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _revenueLoading = false;
        _revenueError = e.toString();
      });
    }
  }

  Widget _buildRevenue() {
    final stats = _revenue;
    if (stats != null) return RevenueSection(stats: stats);
    if (_revenueLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_revenueError ?? 'Không tải được doanh thu.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadRevenue, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAdd(Widget form) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => form));
    if (!mounted) return;
    widget.onDataChanged();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tổng quan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _sectionTitle(context, 'Doanh thu'),
            const SizedBox(height: 8),
            _buildRevenue(),
            const SizedBox(height: 20),
            if (_isLoading && _products == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _products == null)
              ErrorRetry(message: _errorMessage!, onRetry: _load)
            else ...[
              _buildStats(),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Thao tác nhanh'),
              const SizedBox(height: 8),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Sản phẩm mới nhất'),
              const SizedBox(height: 8),
              _buildRecent(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, size: 40, color: scheme.onPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, Admin',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hôm nay ${formatDate(DateTime.now())}',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final activeCats = _categories.where((c) => c.isActive).length;
    final activeBrands = _brands.where((b) => b.isActive).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            value: '${_products?.totalCount ?? 0}',
            label: 'Sản phẩm',
            caption: 'Tổng số',
            onTap: () => widget.onNavigate(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.category_outlined,
            value: '${_categories.length}',
            label: 'Danh mục',
            caption: '$activeCats hoạt động',
            onTap: widget.onOpenCategories,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.storefront_outlined,
            value: '${_brands.length}',
            label: 'Thương hiệu',
            caption: '$activeBrands hoạt động',
            onTap: widget.onOpenBrands,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, VoidCallback onTap) => ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(icon, color: scheme.onPrimaryContainer),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: onTap,
    );

    return Card(
      child: Column(
        children: [
          action(
            Icons.inventory_2_outlined,
            'Thêm sản phẩm',
            () => _quickAdd(
              ProductFormScreen(
                productService: _productService,
                brandService: _brandService,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          action(
            Icons.category_outlined,
            'Thêm danh mục',
            () => _quickAdd(
              CategoryFormScreen(categoryService: _categoryService),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          action(
            Icons.storefront_outlined,
            'Thêm thương hiệu',
            () => _quickAdd(BrandFormScreen(brandService: _brandService)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent() {
    final items = _products?.items ?? const <ProductListItem>[];
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return const Card(
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          message: 'Chưa có sản phẩm nào.',
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: AdminThumb(
                url: items[i].fullPrimaryImageUrl,
                icon: Icons.devices_outlined,
                size: 48,
              ),
              title: Text(
                items[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                formatVnd(items[i].price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: StatusPill(isActive: items[i].isActive),
              onTap: () => widget.onNavigate(1),
            ),
          ],
          const Divider(height: 1),
          TextButton(
            onPressed: () => widget.onNavigate(1),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: scheme.primary,
            ),
            child: const Text('Xem tất cả sản phẩm'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

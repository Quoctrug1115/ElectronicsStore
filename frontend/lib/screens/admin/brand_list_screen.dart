import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/brand_models.dart';
import '../../services/brand_service.dart';
import '../../widgets/admin_widgets.dart';
import 'brand_form_screen.dart';

class BrandListScreen extends StatefulWidget {
  const BrandListScreen({super.key});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
  final BrandService _brandService = BrandService(client: http.Client());

  List<BrandResponse> _brands = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  bool? _status; // null = tất cả

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final brands = await _brandService.getBrands();
      if (!mounted) return;
      setState(() {
        _brands = brands;
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

  Future<void> _deleteBrand(int id, String name) async {
    final confirmed = await confirmDelete(
      context,
      entity: 'thương hiệu',
      name: name,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _brandService.deleteBrand(id);
      if (!mounted) return;
      await _loadBrands();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa thương hiệu thành công.')),
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

  Future<void> _openForm({BrandResponse? brand}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BrandFormScreen(
          brandService: _brandService,
          brand: brand,
        ),
      ),
    );
    if (!mounted) return;
    _loadBrands();
  }

  List<BrandResponse> get _filtered {
    final q = _query.trim().toLowerCase();
    return _brands.where((b) {
      if (_status != null && b.isActive != _status) return false;
      return q.isEmpty || b.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Thương hiệu')),
      body: Column(
        children: [
          StatusFilterBar(
            hint: 'Tìm thương hiệu',
            status: _status,
            onQueryChanged: (v) => setState(() => _query = v),
            onStatusChanged: (v) => setState(() => _status = v),
          ),
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${items.length} thương hiệu',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBrands,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _brands.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ErrorRetry(
                              message: _errorMessage!,
                              onRetry: _loadBrands,
                            ),
                          ],
                        )
                      : items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                EmptyState(
                                  icon: Icons.storefront_outlined,
                                  message: 'Không có thương hiệu phù hợp.',
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _buildRow(items[i]),
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag riêng: các tab nằm cùng IndexedStack nên tag mặc định sẽ bị trùng.
        heroTag: 'fab_brand',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thương hiệu'),
      ),
    );
  }

  Widget _buildRow(BrandResponse b) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        onTap: () => _openForm(brand: b),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              AdminThumb(url: b.fullLogoUrl, icon: Icons.storefront_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (b.description != null && b.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          b.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(isActive: b.isActive),
                        Text(
                          '${b.productCount} sản phẩm',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              RowMenu(
                onEdit: () => _openForm(brand: b),
                onDelete: () => _deleteBrand(b.id, b.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

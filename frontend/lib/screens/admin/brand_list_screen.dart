import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/brand_models.dart';
import '../../services/brand_service.dart';
import '../../widgets/error_banner.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa thương hiệu "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thương hiệu'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadBrands,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _brands.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadBrands,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _brands.length,
                    itemBuilder: (context, index) {
                      final b = _brands[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: b.fullLogoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    b.fullLogoUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.business, size: 40),
                                  ),
                                )
                              : const Icon(Icons.business, size: 40),
                          title: Text(
                            b.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (b.description != null &&
                                  b.description!.isNotEmpty)
                                Text(
                                  b.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: b.isActive
                                          ? Colors.green.shade100
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      b.isActive ? 'Hoạt động' : 'Khóa',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: b.isActive
                                            ? Colors.green.shade800
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${b.productCount} sản phẩm',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Sửa',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openForm(brand: b),
                              ),
                              IconButton(
                                tooltip: 'Xóa',
                                icon: const Icon(Icons.delete),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => _deleteBrand(b.id, b.name),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thương hiệu'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/category_models.dart';
import '../../services/category_service.dart';
import '../../widgets/admin_widgets.dart';
import 'category_form_screen.dart';
import '../../widgets/top_notice.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final CategoryService _categoryService = CategoryService(
    client: http.Client(),
  );

  List<CategoryResponse> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  bool? _status; // null = tất cả

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final categories = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
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

  Future<void> _deleteCategory(int id, String name) async {
    final confirmed = await confirmDelete(
      context,
      entity: 'danh mục',
      name: name,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _categoryService.deleteCategory(id);
      if (!mounted) return;
      await _loadCategories();
      showTopNotice(context, 'Xóa danh mục thành công.');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showTopNotice(context, e.toString(), isError: true);
    }
  }

  Future<void> _openForm({CategoryResponse? category}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(
          categoryService: _categoryService,
          category: category,
        ),
      ),
    );
    if (!mounted) return;
    _loadCategories();
  }

  List<CategoryResponse> get _filtered {
    final q = _query.trim().toLowerCase();
    return _categories.where((c) {
      if (_status != null && c.isActive != _status) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục')),
      body: Column(
        children: [
          StatusFilterBar(
            hint: 'Tìm danh mục',
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
                  '${items.length} danh mục',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCategories,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _categories.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ErrorRetry(
                              message: _errorMessage!,
                              onRetry: _loadCategories,
                            ),
                          ],
                        )
                      : items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                EmptyState(
                                  icon: Icons.category_outlined,
                                  message: 'Không có danh mục phù hợp.',
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
        heroTag: 'fab_category',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
    );
  }

  Widget _buildRow(CategoryResponse c) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final meta = <String>[
      '${c.productCount} sản phẩm',
      if (c.parentName != null && c.parentName!.isNotEmpty)
        'Cha: ${c.parentName}',
    ].join(' · ');

    return Card(
      child: InkWell(
        onTap: () => _openForm(category: c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              AdminThumb(url: c.fullImageUrl, icon: Icons.category_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (c.description != null && c.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          c.description!,
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
                        StatusPill(isActive: c.isActive),
                        Text(meta, style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              RowMenu(
                onEdit: () => _openForm(category: c),
                onDelete: () => _deleteCategory(c.id, c.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

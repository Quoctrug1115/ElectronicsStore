import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/category_models.dart';
import '../../services/category_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/top_notice.dart';

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({
    super.key,
    required this.categoryService,
    this.category,
  });

  final CategoryService categoryService;
  final CategoryResponse? category;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<CategoryResponse> _parentCategories = [];
  bool _isLoading = true;
  bool _saving = false;
  String? _errorMessage;
  bool _isActive = true;
  int? _parentId;
  File? _pickedImage;
  String? _pickedImagePreviewUrl;

  bool get _isEdit => widget.category != null;
  CategoryService get _service => widget.categoryService;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    if (_isEdit) {
      final c = widget.category!;
      _nameController.text = c.name;
      _descriptionController.text = c.description ?? '';
      _isActive = c.isActive;
      _parentId = c.parentId;
      _pickedImagePreviewUrl = c.fullImageUrl;
    }

    try {
      final parents = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _parentCategories = _isEdit
            ? parents.where((c) => c.id != widget.category!.id).toList()
            : parents;
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

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedImage = File(picked.path);
      _pickedImagePreviewUrl = null;
    });
  }

  String? _currentImageUrl() {
    if (_pickedImage != null) return null;
    if (_pickedImagePreviewUrl != null) return _pickedImagePreviewUrl!;
    if (_isEdit) return widget.category!.fullImageUrl;
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final request = CategoryRequest(
      name: _nameController.text.trim(),
      parentId: _parentId,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isActive: _isActive,
    );

    try {
      if (_isEdit) {
        await _service.updateCategory(
          widget.category!.id,
          request,
          imageFile: _pickedImage,
        );
      } else {
        await _service.createCategory(
          request,
          imageFile: _pickedImage,
        );
      }
      if (!mounted) return;
      showTopNotice(context, _isEdit ? 'Cập nhật danh mục thành công.' : 'Thêm danh mục thành công.');
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa danh mục' : 'Thêm danh mục'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEdit ? 'Sửa danh mục' : 'Thêm danh mục mới',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Tên danh mục',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Vui lòng nhập tên danh mục'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Danh mục cha (trống nếu là danh mục gốc)',
                        prefixIcon: Icon(Icons.outlined_flag),
                        border: OutlineInputBorder(),
                      ),
                      value: _parentId,
                      items: _parentCategories
                          .map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList()
                        ..insert(
                          0,
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('(Không có - danh mục gốc)'),
                          ),
                        ),
                      onChanged:
                          _saving ? null : (v) => setState(() => _parentId = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isActive,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _isActive = v ?? true),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hoạt động',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Hình ảnh danh mục',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _buildImagePicker(),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.image),
                      label: Text(_pickedImage == null
                          ? 'Chọn hình ảnh'
                          : 'Chọn ảnh khác'),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(_isEdit ? 'Cập nhật' : 'Thêm'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    final currentUrl = _currentImageUrl();
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _pickedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _pickedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : currentUrl != null && currentUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          currentUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported, size: 40),
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có ảnh',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          if (currentUrl != null && currentUrl.isNotEmpty)
            Positioned(
              right: -6,
              top: -6,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  onPressed: () => setState(() => _pickedImagePreviewUrl = null),
                  tooltip: 'Xóa ảnh',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

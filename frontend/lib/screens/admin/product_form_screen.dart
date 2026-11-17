import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../models/brand_models.dart';
import '../../models/category_models.dart';
import '../../models/product_models.dart';
import '../../services/brand_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/error_banner.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.productService,
    required this.brandService,
    this.product,
  });

  final ProductService productService;
  final BrandService brandService;
  final ProductListItem? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _colorController = TextEditingController();
  final _storageController = TextEditingController();
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();

  List<CategoryResponse> _categories = [];
  List<BrandResponse> _brands = [];
  bool _isLoading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEdit => widget.product != null;

  int? _categoryId;
  int? _brandId;
  BrandService get _brandService => widget.brandService;
  bool _isActive = true;
  double _price = 0;
  double? _compareAtPrice;

  final List<File> _newImages = [];
  List<ProductImage> _existingImages = [];

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    if (_isEdit) {
      try {
        final detail = await widget.productService.getProductById(
          widget.product!.id,
        );
        if (!mounted) return;
        _nameController.text = detail.name;
        _descriptionController.text = detail.description ?? '';
        _skuController.text = detail.variants.isNotEmpty
            ? detail.variants.first.sku
            : '';
        _colorController.text = detail.variants.isNotEmpty
            ? (detail.variants.first.color ?? '')
            : '';
        _storageController.text = detail.variants.isNotEmpty
            ? (detail.variants.first.storage ?? '')
            : '';
        final firstVariant = detail.variants.isNotEmpty
            ? detail.variants.first
            : null;
        _price = firstVariant?.price ?? 0;
        _priceController.text = _price.toStringAsFixed(0);
        _compareAtPrice = firstVariant?.compareAtPrice;
        _compareAtPriceController.text =
            _compareAtPrice != null ? _compareAtPrice!.toStringAsFixed(0) : '';
        _brandId = detail.brandId;
        _isActive = detail.isActive;
        _existingImages = detail.images;
      } catch (_) {}
    }

    try {
      await _loadCategories();
      await _loadBrands();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    final categoryService = CategoryService(client: http.Client());
    final categories = await categoryService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (_isEdit && _categoryId == null) {
        _categoryId = widget.product!.categoryId;
      }
    });
  }

  Future<void> _loadBrands() async {
    final brands = await _brandService.getBrands();
    if (!mounted) return;
    setState(() {
      _brands = brands;
      if (_isEdit && _brandId == null) {
        _brandId = widget.product!.brandId;
      }
    });
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _newImages.addAll(picked.map((p) => File(p.path)));
    });
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  String _existingImageUrl(ProductImage img) {
    final base = 'http://localhost:5202';
    if (img.imageUrl.isEmpty) return '';
    return '$base${img.imageUrl}';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final compareAtPrice =
        _compareAtPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_compareAtPriceController.text.trim());

    setState(() {
      _saving = true;
      _errorMessage = null;
      _price = price;
      _compareAtPrice = compareAtPrice;
    });

    final request = ProductRequest(
      categoryId: _categoryId!,
      brandId: _brandId!,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isActive: _isActive,
      sku: _skuController.text.trim(),
      color: _colorController.text.trim().isEmpty
          ? null
          : _colorController.text.trim(),
      storage: _storageController.text.trim().isEmpty
          ? null
          : _storageController.text.trim(),
      price: price,
      compareAtPrice: compareAtPrice,
    );

    try {
      if (_isEdit) {
        await widget.productService.updateProduct(
          widget.product!.id,
          request,
          imageFiles: _newImages,
        );
      } else {
        await widget.productService.createProduct(
          request,
          imageFiles: _newImages,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Cập nhật sản phẩm thành công.' : 'Thêm sản phẩm thành công.',
          ),
        ),
      );
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
        title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm'),
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
                      _isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm mới',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Danh mục',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      value: _categoryId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('(Chọn danh mục)'),
                        ),
                      ]..addAll(
                          _categories.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null
                          ? 'Vui lòng chọn danh mục'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Thương hiệu',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      value: _brandId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('(Chọn thương hiệu)'),
                        ),
                      ]..addAll(
                          _brands.map(
                            (b) => DropdownMenuItem<int?>(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          ),
                        ),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _brandId = v),
                      validator: (v) => v == null
                          ? 'Vui lòng chọn thương hiệu'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm',
                        prefixIcon: Icon(Icons.devices),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Vui lòng nhập tên sản phẩm'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _skuController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Mã SKU',
                        prefixIcon: Icon(Icons.label_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Vui lòng nhập mã SKU'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Giá bán (đ)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (double.tryParse(value?.trim() ?? '') == null)
                              ? 'Vui lòng nhập giá bán hợp lệ'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _compareAtPriceController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Giá gốc/kmã (đ) (tùy chọn)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _colorController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Màu sắc (tùy chọn)',
                        prefixIcon: Icon(Icons.color_lens),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _storageController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Dung lượng (tùy chọn)',
                        prefixIcon: Icon(Icons.memory),
                        border: OutlineInputBorder(),
                      ),
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
                      'Hình ảnh sản phẩm',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (_existingImages.isNotEmpty) ...[
                      const Text(
                        'Ảnh hiện tại (giữ lại khi không upload ảnh mới)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _existingImages.length,
                          itemBuilder: (_, i) {
                            final img = _existingImages[i];
                            final url = _existingImageUrl(img);
                            return Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                  errorBuilder: (_, __, ___) =>
                                      const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Ảnh mới chọn',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (_newImages.isEmpty)
                      const Text(
                        'Chưa chọn ảnh nào',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      )
                    else
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _newImages.length,
                          itemBuilder: (_, i) {
                            final file = _newImages[i];
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _removeNewImage(i),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Chọn ảnh sản phẩm'),
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
}

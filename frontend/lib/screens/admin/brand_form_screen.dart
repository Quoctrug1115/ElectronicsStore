import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/brand_models.dart';
import '../../services/brand_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/top_notice.dart';

class BrandFormScreen extends StatefulWidget {
  const BrandFormScreen({
    super.key,
    required this.brandService,
    this.brand,
  });

  final BrandService brandService;
  final BrandResponse? brand;

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _saving = false;
  String? _errorMessage;
  bool _isActive = true;
  File? _pickedLogo;
  String? _pickedLogoPreviewUrl;
  bool _removeExistingLogo = false;

  bool get _isEdit => widget.brand != null;
  BrandService get _service => widget.brandService;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initForm() {
    if (_isEdit) {
      final b = widget.brand!;
      _nameController.text = b.name;
      _descriptionController.text = b.description ?? '';
      _isActive = b.isActive;
      _pickedLogoPreviewUrl = b.fullLogoUrl;
    }
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedLogo = File(picked.path);
      _pickedLogoPreviewUrl = null;
      _removeExistingLogo = false;
    });
  }

  String? _currentLogoUrl() {
    if (_pickedLogo != null || _removeExistingLogo) return null;
    if (_pickedLogoPreviewUrl != null) return _pickedLogoPreviewUrl!;
    if (_isEdit) return widget.brand!.fullLogoUrl;
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final request = BrandRequest(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isActive: _isActive,
    );

    try {
      if (_isEdit) {
        await _service.updateBrand(
          widget.brand!.id,
          request,
          logoFile: _pickedLogo,
          removeLogo: _removeExistingLogo,
        );
      } else {
        await _service.createBrand(
          request,
          logoFile: _pickedLogo,
        );
      }
      if (!mounted) return;
      showTopNotice(
        context,
        _isEdit
            ? 'Cập nhật thương hiệu thành công.'
            : 'Thêm thương hiệu thành công.',
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
        title: Text(_isEdit ? 'Sửa thương hiệu' : 'Thêm thương hiệu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Sửa thương hiệu' : 'Thêm thương hiệu mới',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Tên thương hiệu',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Vui lòng nhập tên thương hiệu'
                    : null,
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
                'Logo thương hiệu',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildLogoPicker(),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _pickLogo,
                icon: const Icon(Icons.image),
                label: Text(
                  _pickedLogo == null ? 'Chọn logo' : 'Chọn ảnh khác',
                ),
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

  Widget _buildLogoPicker() {
    final currentUrl = _currentLogoUrl();
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
            child: _pickedLogo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _pickedLogo!,
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
                              'Chưa có logo',
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
                  onPressed: () => setState(() {
                    _pickedLogoPreviewUrl = null;
                    _removeExistingLogo = true;
                  }),
                  tooltip: 'Xóa logo',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
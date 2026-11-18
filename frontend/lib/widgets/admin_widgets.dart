import 'package:flutter/material.dart';

import 'error_banner.dart';

/// Nhãn trạng thái "Hoạt động" / "Khóa".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? Colors.green.shade800 : Colors.grey.shade700;
    final bg = isActive ? Colors.green.shade50 : Colors.grey.shade200;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Hoạt động' : 'Khóa',
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh thu nhỏ vuông bo góc, có icon dự phòng khi chưa có ảnh / lỗi tải.
class AdminThumb extends StatelessWidget {
  const AdminThumb({
    super.key,
    required this.url,
    required this.icon,
    this.size = 60,
  });

  final String url;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(icon, size: size * 0.45, color: scheme.outline);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: url.isEmpty
              ? placeholder
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// Menu ⋮ (Sửa / Xóa) cho mỗi dòng.
class RowMenu extends StatelessWidget {
  const RowMenu({super.key, required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      tooltip: 'Thao tác',
      icon: const Icon(Icons.more_vert),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Sửa'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: error),
            title: Text('Xóa', style: TextStyle(color: error)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}

/// Hộp thoại xác nhận xóa. Trả về true nếu người dùng đồng ý.
Future<bool> confirmDelete(
  BuildContext context, {
  required String entity,
  required String name,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xác nhận xóa'),
      content: Text('Bạn có chắc chắn muốn xóa $entity "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            minimumSize: const Size(88, 44),
          ),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Trạng thái trống (dùng trong ListView để vẫn kéo-làm-mới được).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Thông báo lỗi kèm nút "Thử lại".
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          ErrorBanner(message: message),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

/// Ô tìm kiếm + hàng chip lọc trạng thái dùng cho Danh mục / Thương hiệu.
class StatusFilterBar extends StatelessWidget {
  const StatusFilterBar({
    super.key,
    required this.hint,
    required this.status,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String hint;

  /// null = tất cả, true = hoạt động, false = khóa.
  final bool? status;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool? value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: status == value,
        onSelected: (_) => onStatusChanged(value),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip('Tất cả', null),
                chip('Hoạt động', true),
                chip('Khóa', false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

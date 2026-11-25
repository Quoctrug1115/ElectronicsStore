import 'package:flutter/material.dart';

/// Thanh phân trang dùng chung (Sản phẩm, Đơn hàng, Người dùng).
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.pageIndex,
    required this.totalPages,
    required this.totalCount,
    required this.unit,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int totalPages;
  final int totalCount;

  /// Đơn vị hiển thị, ví dụ "đơn hàng".
  final String unit;

  /// null = nút bị khóa.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Trang $pageIndex/$totalPages ($totalCount $unit)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Trang trước',
            onPressed: onPrevious,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Trang sau',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

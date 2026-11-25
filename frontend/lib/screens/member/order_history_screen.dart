import 'package:flutter/material.dart';

import '../../models/order_models.dart';
import '../../services/order_service.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/order_widgets.dart';
import '../../widgets/pagination_bar.dart';
import 'order_detail_screen.dart';

/// Danh sách đơn hàng có phân trang + lọc trạng thái / mã đơn / ngày đặt.
/// [admin] = false: lịch sử đơn của khách; true: toàn bộ đơn cho Admin.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, this.admin = false});

  final bool admin;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  static const _pageSize = 10;

  final OrderService _orderService = OrderService();

  PagedResultOrder? _paged;
  bool _isLoading = true;
  String? _errorMessage;

  int _pageIndex = 1;
  String _status = '';
  String _keyword = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool resetPage = true}) async {
    if (resetPage) _pageIndex = 1;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _orderService.getOrders(
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        status: _status,
        keyword: _keyword,
        fromDate: _dateRange?.start,
        toDate: _dateRange?.end,
        admin: widget.admin,
      );
      if (!mounted) return;
      setState(() {
        _paged = result;
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

  Future<void> _openDetail(OrderResponse order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderDetailScreen(orderId: order.id, admin: widget.admin),
      ),
    );
    // Có thể đã đổi trạng thái / hủy bên trong chi tiết.
    if (mounted) _load(resetPage: false);
  }

  @override
  Widget build(BuildContext context) {
    final paged = _paged;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.admin ? 'Quản lý đơn hàng' : 'Lịch sử đơn hàng'),
      ),
      body: Column(
        children: [
          OrderFilterBar(
            status: _status,
            dateRange: _dateRange,
            hint: widget.admin
                ? 'Tìm theo mã đơn, tên khách, email'
                : 'Tìm theo mã đơn',
            onKeyword: (v) {
              _keyword = v;
              _load();
            },
            onStatus: (v) {
              _status = v;
              _load();
            },
            onDateRange: (v) {
              _dateRange = v;
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && paged == null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ErrorRetry(message: _errorMessage!, onRetry: _load),
                      ],
                    )
                  : _buildList(),
            ),
          ),
          if (paged != null)
            PaginationBar(
              pageIndex: paged.pageIndex,
              totalPages: paged.totalPages,
              totalCount: paged.totalCount,
              unit: 'đơn hàng',
              onPrevious: (_isLoading || !paged.hasPreviousPage)
                  ? null
                  : () {
                      _pageIndex--;
                      _load(resetPage: false);
                    },
              onNext: (_isLoading || !paged.hasNextPage)
                  ? null
                  : () {
                      _pageIndex++;
                      _load(resetPage: false);
                    },
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = _paged?.items ?? [];
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'Không có đơn hàng nào.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => OrderCard(
        order: items[i],
        showCustomer: widget.admin,
        onTap: () => _openDetail(items[i]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/admin_user_models.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_widgets.dart';
import '../../widgets/pagination_bar.dart';
import 'user_detail_screen.dart';
import '../../widgets/top_notice.dart';

/// Admin: danh sách thành viên, khóa/mở khóa, đổi quyền Member <-> Admin.
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  static const _pageSize = 10;

  final _service = AdminUserService();

  PagedAdminUsers? _paged;
  bool _isLoading = true;
  String? _errorMessage;
  int _pageIndex = 1;
  String _search = '';
  String _role = '';

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
      final result = await _service.getUsers(
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        search: _search,
        role: _role,
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

  void _toast(String message) {
    showTopNotice(context, message);
  }

  Future<void> _run(Future<String> Function() action) async {
    try {
      final msg = await action();
      if (!mounted) return;
      _toast(msg);
      await _load(resetPage: false);
    } on Exception catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  Future<void> _toggleLock(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.isLocked ? 'Mở khóa tài khoản?' : 'Khóa tài khoản?'),
        content: Text(
          user.isLocked
              ? '${user.fullName} sẽ đăng nhập lại được.'
              : '${user.fullName} sẽ không đăng nhập được cho tới khi được mở khóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(user.isLocked ? 'Mở khóa' : 'Khóa'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.toggleLock(user.id));
  }

  Future<void> _changeRole(AdminUser user) async {
    final target = user.isAdmin ? 'Member' : 'Admin';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chuyển thành $target?'),
        content: Text('Đổi quyền của ${user.fullName} (${user.email}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đổi quyền'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.changeRole(user.id, target));
  }

  Widget _roleChip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _role == value,
      onSelected: (_) {
        _role = value;
        _load();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final paged = _paged;
    return Scaffold(
      appBar: AppBar(title: const Text('Người dùng')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên, email, số điện thoại',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (v) {
                    _search = v;
                    _load();
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _roleChip('Tất cả', ''),
                      _roleChip('Member', 'Member'),
                      _roleChip('Admin', 'Admin'),
                    ],
                  ),
                ),
              ],
            ),
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
              unit: 'người dùng',
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
            icon: Icons.people_outline,
            message: 'Không có người dùng nào.',
          ),
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = items[i];
        final theme = Theme.of(context);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    UserDetailScreen(userId: u.id, title: u.fullName),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: u.isAdmin
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    child: Icon(
                      u.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(isActive: !u.isLocked),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${u.role} · '
                          '${u.emailConfirmed ? 'Đã xác thực email' : 'Chưa xác thực email'}'
                          ' · ${formatDate(u.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Thao tác',
                    onSelected: (v) =>
                        v == 'lock' ? _toggleLock(u) : _changeRole(u),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'lock',
                        child: Text(u.isLocked ? 'Mở khóa' : 'Khóa tài khoản'),
                      ),
                      PopupMenuItem(
                        value: 'role',
                        child: Text(
                          u.isAdmin ? 'Hạ xuống Member' : 'Nâng lên Admin',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

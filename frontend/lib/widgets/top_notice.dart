import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _currentEntry;

/// Đóng thông báo đang hiện (nếu có).
void hideTopNotice() {
  _currentEntry?.remove();
  _currentEntry = null;
}

/// Hiện thông báo nổi ở **đầu màn hình** (thay cho SnackBar vốn dính đáy màn hình).
/// Tự tắt sau [duration]; chạm vào hoặc vuốt lên để tắt ngay. Chỉ có một thông báo tại một thời điểm.
void showTopNotice(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  hideTopNotice();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotice(
      message: message,
      isError: isError,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      onClosed: () {
        if (identical(_currentEntry, entry)) _currentEntry = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _currentEntry = entry;
  overlay.insert(entry);
}

class _TopNotice extends StatefulWidget {
  const _TopNotice({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool isError;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClosed;

  @override
  State<_TopNotice> createState() => _TopNoticeState();
}

class _TopNoticeState extends State<_TopNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = widget.isError ? scheme.error : scheme.inverseSurface;
    final foreground = widget.isError
        ? scheme.onError
        : scheme.onInverseSurface;
    final top = MediaQuery.paddingOf(context).top + 8;

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: FadeTransition(
          opacity: _controller,
          child: GestureDetector(
            onTap: _close,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) _close();
            },
            child: Material(
              color: background,
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: foreground,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(color: foreground, fontSize: 14),
                      ),
                    ),
                    if (widget.actionLabel != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _close();
                          widget.onAction?.call();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

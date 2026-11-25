String formatVnd(num value) {
  final digits = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '$buf ₫';
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}';
}

String formatDateTime(DateTime d) {
  final l = d.toLocal();
  return '${formatDate(l)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// Đọc ngày giờ từ API. Backend lưu giờ UTC nhưng trả JSON không có hậu tố múi giờ
/// (ví dụ `2026-11-25T13:40:00`), nên nếu để Dart tự parse sẽ bị hiểu là giờ địa phương
/// và lệch 7 tiếng. Chuỗi thiếu múi giờ được coi là UTC.
DateTime? parseServerDate(Object? value) {
  if (value == null) return null;
  var text = value.toString().trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(text)) {
    text = '${text}Z';
  }
  return DateTime.tryParse(text);
}

/// Số tiền rút gọn cho chỗ hẹp (nhãn biểu đồ): 1,2 tỷ / 3,5 tr / 800k / 500.
String formatVndShort(num value) {
  String trim(double v) {
    final text = v.toStringAsFixed(1).replaceAll('.', ',');
    return text.endsWith(',0') ? text.substring(0, text.length - 2) : text;
  }

  final v = value.toDouble();
  if (v >= 1e9) return '${trim(v / 1e9)} tỷ';
  if (v >= 1e6) return '${trim(v / 1e6)} tr';
  if (v >= 1e3) return '${trim(v / 1e3)}k';
  return v.round().toString();
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../core/local_database.dart';

/// Đọc/ghi bộ nhớ đệm SQLite cho danh mục, sản phẩm và chi tiết sản phẩm.
/// Mọi hàm đều nuốt lỗi SQLite: bộ nhớ đệm hỏng hay không hỗ trợ thì app vẫn chạy bình thường.
class LocalCache {
  LocalCache._();

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Lỗi do mất mạng / không tới được máy chủ (khác với lỗi nghiệp vụ như 400, 404).
  static bool isNetworkError(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException;

  // ---------- Danh mục ----------

  /// [replaceAll] = true khi vừa tải đủ toàn bộ danh mục: xóa các danh mục không còn trên server.
  static Future<void> saveCategories(
    List<Map<String, dynamic>> items, {
    required bool replaceAll,
  }) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return;
      await db.transaction((txn) async {
        if (replaceAll) await txn.delete('categories');
        var position = 0;
        for (final c in items) {
          await txn.insert('categories', {
            'id': (c['id'] as num).toInt(),
            'name': c['name'] as String? ?? '',
            'is_active': (c['isActive'] as bool? ?? true) ? 1 : 0,
            'position': position++,
            'json': jsonEncode(c),
            'saved_at': _now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadCategories({
    bool? isActive,
  }) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return [];
      final rows = await db.query(
        'categories',
        where: isActive == null ? null : 'is_active = ?',
        whereArgs: isActive == null ? null : [isActive ? 1 : 0],
        orderBy: 'position ASC',
      );
      return rows
          .map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- Sản phẩm (danh sách) ----------

  static Future<void> saveProducts(List<Map<String, dynamic>> items) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return;
      final batch = db.batch();
      for (final p in items) {
        batch.insert('products', {
          'id': (p['id'] as num).toInt(),
          'name': p['name'] as String? ?? '',
          'category_id': (p['categoryId'] as num?)?.toInt() ?? 0,
          'brand_id': (p['brandId'] as num?)?.toInt() ?? 0,
          'price': (p['price'] as num?)?.toDouble() ?? 0,
          'created_at': p['createdAt'] as String? ?? '',
          'json': jsonEncode(p),
          'saved_at': _now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// Truy vấn lại danh sách sản phẩm đã lưu với cùng bộ lọc/sắp xếp/phân trang như API.
  /// Trả về null nếu không có dữ liệu để hiển thị.
  static Future<({List<Map<String, dynamic>> items, int total})?> queryProducts({
    required int pageIndex,
    required int pageSize,
    String? search,
    int? categoryId,
    int? brandId,
    String sortBy = 'newest',
  }) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return null;

      final where = <String>[];
      final args = <Object?>[];
      if (search != null && search.trim().isNotEmpty) {
        where.add('name LIKE ?');
        args.add('%${search.trim()}%');
      }
      if (categoryId != null) {
        where.add('category_id = ?');
        args.add(categoryId);
      }
      if (brandId != null) {
        where.add('brand_id = ?');
        args.add(brandId);
      }
      final whereSql = where.isEmpty ? null : where.join(' AND ');

      final total = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM products'
              '${whereSql == null ? '' : ' WHERE $whereSql'}',
              args,
            ),
          ) ??
          0;
      if (total == 0) return null;

      final orderBy = switch (sortBy) {
        'price_asc' => 'price ASC',
        'price_desc' => 'price DESC',
        'name_asc' => 'name ASC',
        _ => 'created_at DESC',
      };
      final rows = await db.query(
        'products',
        where: whereSql,
        whereArgs: args.isEmpty ? null : args,
        orderBy: '$orderBy, id DESC',
        limit: pageSize,
        offset: (pageIndex - 1) * pageSize,
      );
      return (
        items: rows
            .map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>)
            .toList(),
        total: total,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------- Chi tiết sản phẩm ----------

  static Future<void> saveProductDetail(
    int id,
    Map<String, dynamic> json,
  ) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return;
      await db.insert('product_details', {
        'id': id,
        'json': jsonEncode(json),
        'saved_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadProductDetail(int id) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return null;
      final rows = await db.query(
        'product_details',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------- Giỏ hàng (theo từng tài khoản) ----------

  /// Ghi đè toàn bộ giỏ của [userId] bằng [items] (giỏ nhỏ nên xóa rồi chèn lại trong một transaction).
  /// Mỗi phần tử: `productId`, `variantId` (0 nếu không có), `quantity`, `product` (Map), `variant` (Map?).
  static Future<void> saveCart(
    int userId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return;
      await db.transaction((txn) async {
        await txn.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
        var position = 0;
        for (final i in items) {
          await txn.insert('cart_items', {
            'user_id': userId,
            'product_id': i['productId'],
            'variant_id': i['variantId'] ?? 0,
            'quantity': i['quantity'],
            'position': position++,
            'product_json': jsonEncode(i['product']),
            'variant_json': i['variant'] == null ? null : jsonEncode(i['variant']),
            'saved_at': _now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadCart(int userId) async {
    try {
      final db = await LocalDatabase.open();
      if (db == null) return [];
      final rows = await db.query(
        'cart_items',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'position ASC',
      );
      return rows
          .map(
            (r) => {
              'quantity': r['quantity'] as int,
              'product': jsonDecode(r['product_json'] as String),
              'variant': r['variant_json'] == null
                  ? null
                  : jsonDecode(r['variant_json'] as String),
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}

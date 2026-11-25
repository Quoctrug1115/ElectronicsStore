import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite lưu trên điện thoại (yêu cầu của đề). Dùng làm bộ nhớ đệm để xem danh mục,
/// sản phẩm khi mất mạng. Dữ liệu chính vẫn nằm ở SQL Server phía backend.
///
/// `sqflite` chỉ chạy trên Android/iOS/macOS; Chrome và Linux desktop không hỗ trợ nên
/// mọi thao tác ở đó tự bỏ qua (không ném lỗi).
class LocalDatabase {
  LocalDatabase._();

  static const _dbName = 'electronics_store.db';
  static const _version = 2;

  static Database? _db;

  /// true khi lần gọi API gần nhất thất bại vì mất mạng và app đang hiển thị dữ liệu đã lưu.
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Mở (và tạo bảng ở lần đầu). Trả về null nếu nền tảng không hỗ trợ SQLite.
  static Future<Database?> open() async {
    if (!supported) return null;
    final existing = _db;
    if (existing != null) return existing;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            is_active INTEGER NOT NULL,
            position INTEGER NOT NULL,
            json TEXT NOT NULL,
            saved_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            category_id INTEGER NOT NULL,
            brand_id INTEGER NOT NULL,
            price REAL NOT NULL,
            created_at TEXT NOT NULL,
            json TEXT NOT NULL,
            saved_at INTEGER NOT NULL
          )''');
        await db.execute(
          'CREATE INDEX idx_products_category ON products(category_id)',
        );
        await db.execute('''
          CREATE TABLE product_details(
            id INTEGER PRIMARY KEY,
            json TEXT NOT NULL,
            saved_at INTEGER NOT NULL
          )''');
        await _createCartTable(db);
      },
      // Máy đã cài bản cũ (version 1) chưa có bảng giỏ hàng.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCartTable(db);
      },
    );
    return _db;
  }

  /// Giỏ hàng lưu theo từng tài khoản (user_id) để hai người dùng chung máy không thấy giỏ của nhau.
  static Future<void> _createCartTable(Database db) => db.execute('''
    CREATE TABLE cart_items(
      user_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      variant_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      position INTEGER NOT NULL,
      product_json TEXT NOT NULL,
      variant_json TEXT,
      saved_at INTEGER NOT NULL,
      PRIMARY KEY(user_id, product_id, variant_id)
    )''');

  /// Xóa toàn bộ dữ liệu đã lưu (dùng khi cần làm sạch bộ nhớ đệm).
  static Future<void> clear() async {
    final db = await open();
    if (db == null) return;
    await db.delete('categories');
    await db.delete('products');
    await db.delete('product_details');
    await db.delete('cart_items');
  }
}

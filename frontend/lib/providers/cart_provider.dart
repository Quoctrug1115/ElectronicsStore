import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/jwt_helper.dart';
import '../core/token_storage.dart';
import '../models/cart_models.dart';
import '../models/product_models.dart';
import '../services/local_cache.dart';

class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(const Cart());

  /// Chủ của giỏ đang hiển thị; null khi chưa nạp (chưa đăng nhập) nên chưa ghi xuống SQLite.
  int? _userId;

  // Ghi xuống SQLite tuần tự để các thay đổi liên tiếp không bị ghi đè sai thứ tự.
  Future<void> _pendingWrite = Future.value();

  /// Mọi thay đổi giỏ đều đi qua setter này: cập nhật bộ nhớ rồi lưu vào SQLite.
  @override
  set state(Cart value) {
    super.state = value;
    _persist(value);
  }

  void _persist(Cart cart) {
    final userId = _userId;
    if (userId == null) return;
    final rows = [
      for (final i in cart.items)
        {
          'productId': i.product.id,
          'variantId': i.variant?.id ?? 0,
          'quantity': i.quantity,
          'product': i.product.toJson(),
          'variant': i.variant?.toJson(),
        },
    ];
    _pendingWrite = _pendingWrite.then((_) => LocalCache.saveCart(userId, rows));
  }

  /// Nạp giỏ của người dùng đang đăng nhập từ SQLite (gọi khi vào trang chủ của khách).
  /// Thay thế hẳn giỏ trong bộ nhớ nên giỏ của tài khoản trước không lẫn sang tài khoản sau.
  Future<void> loadForCurrentUser() async {
    final token = await TokenStorage.getToken();
    final userId = token == null ? null : JwtHelper.getUserId(token);
    _userId = userId;
    if (userId == null) {
      super.state = const Cart();
      return;
    }
    final rows = await LocalCache.loadCart(userId);
    if (_userId != userId) return; // đã đổi tài khoản trong lúc nạp
    final items = <CartItem>[];
    for (final r in rows) {
      try {
        items.add(CartItem(
          product: ProductListItem.fromJson(r['product'] as Map<String, dynamic>),
          variant: r['variant'] == null
              ? null
              : ProductVariant.fromJson(r['variant'] as Map<String, dynamic>),
          quantity: r['quantity'] as int,
        ));
      } catch (_) {}
    }
    super.state = Cart(items: items); // nạp từ DB: không cần ghi lại
  }

  /// Đăng xuất: bỏ giỏ khỏi bộ nhớ nhưng giữ nguyên trong SQLite để lần đăng nhập sau còn.
  void resetInMemory() {
    _userId = null;
    super.state = const Cart();
  }

  void addItem(CartItem item) {
    final existingIndex = state.items.indexWhere(
      (i) => i.product.id == item.product.id && i.variant?.id == item.variant?.id,
    );

    if (existingIndex >= 0) {
      final updatedItems = [...state.items];
      updatedItems[existingIndex].quantity += item.quantity;
      state = Cart(items: updatedItems);
    } else {
      state = Cart(items: [...state.items, item]);
    }
  }

  void removeItem(int productId, [int? variantId]) {
    final updatedItems = state.items
        .where((i) => !(i.product.id == productId && i.variant?.id == variantId))
        .toList();
    state = Cart(items: updatedItems);
  }

  void updateQuantity(int productId, int quantity, [int? variantId]) {
    if (quantity <= 0) {
      removeItem(productId, variantId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId && item.variant?.id == variantId) {
        return CartItem(
          product: item.product,
          variant: item.variant,
          quantity: quantity,
        );
      }
      return item;
    }).toList();

    state = Cart(items: updatedItems);
  }

  void incrementQuantity(int productId, [int? variantId]) {
    final index = state.items.indexWhere(
      (i) => i.product.id == productId && i.variant?.id == variantId,
    );
    if (index >= 0) {
      final item = state.items[index];
      final updatedItems = [...state.items];
      updatedItems[index] = CartItem(
        product: item.product,
        variant: item.variant,
        quantity: item.quantity + 1,
      );
      state = Cart(items: updatedItems);
    }
  }

  void decrementQuantity(int productId, [int? variantId]) {
    final index = state.items.indexWhere(
      (i) => i.product.id == productId && i.variant?.id == variantId,
    );
    if (index >= 0) {
      final item = state.items[index];
      if (item.quantity > 1) {
        final updatedItems = [...state.items];
        updatedItems[index] = CartItem(
          product: item.product,
          variant: item.variant,
          quantity: item.quantity - 1,
        );
        state = Cart(items: updatedItems);
      } else {
        removeItem(productId, variantId);
      }
    }
  }

  void clear() {
    state = const Cart();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  return CartNotifier();
});

final cartTotalQuantityProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalQuantity;
});

final cartTotalPriceProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).totalPrice;
});
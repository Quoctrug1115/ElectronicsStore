import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_models.dart';

class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(const Cart());

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
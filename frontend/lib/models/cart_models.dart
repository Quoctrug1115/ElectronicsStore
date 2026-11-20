import 'product_models.dart';

class CartItem {
  final ProductListItem product;
  final ProductVariant? variant;
  int quantity;

  CartItem({
    required this.product,
    this.variant,
    this.quantity = 1,
  });

  double get price => variant?.price ?? product.price;

  double get totalPrice => price * quantity;

  String get fullImageUrl => product.fullPrimaryImageUrl;

  String get name => product.name;

  String get variantInfo {
    final parts = <String>[];
    if (variant?.color != null) parts.add(variant!.color!);
    if (variant?.storage != null) parts.add(variant!.storage!);
    return parts.join(' / ');
  }
}

class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;
}
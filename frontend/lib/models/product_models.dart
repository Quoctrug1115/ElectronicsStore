import '../../core/api_config.dart';
import '../core/format.dart';

class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int pageIndex;
  final int pageSize;

  const PagedResult({
    required this.items,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
  });

  int get totalPages => pageSize > 0
      ? (totalCount / pageSize).ceil()
      : 0;
  bool get hasNextPage => pageIndex < totalPages;
  bool get hasPreviousPage => pageIndex > 1;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PagedResult<T>(
      items: (json['items'] as List<dynamic>)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num).toInt(),
      pageIndex: (json['pageIndex'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
    );
  }
}

class ProductListItem {
  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final int brandId;
  final String brandName;
  final double price;
  final double? compareAtPrice;
  final String? primaryImageUrl;
  final int stockQuantity;
  final bool isActive;
  final DateTime createdAt;

  const ProductListItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.brandId,
    required this.brandName,
    required this.price,
    this.compareAtPrice,
    this.primaryImageUrl,
    this.stockQuantity = 0,
    required this.isActive,
    required this.createdAt,
  });

  /// Còn bán được: đang kinh doanh và còn tồn kho.
  bool get inStock => isActive && stockQuantity > 0;

  String get fullPrimaryImageUrl {
    if (primaryImageUrl == null || primaryImageUrl!.isEmpty) return '';
    return '${ApiConfig.baseUrl}$primaryImageUrl';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'brandId': brandId,
    'brandName': brandName,
    'price': price,
    'compareAtPrice': compareAtPrice,
    'primaryImageUrl': primaryImageUrl,
    'stockQuantity': stockQuantity,
    'isActive': isActive,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory ProductListItem.fromJson(Map<String, dynamic> json) => ProductListItem(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    categoryId: (json['categoryId'] as num).toInt(),
    categoryName: json['categoryName'] as String? ?? '',
    brandId: (json['brandId'] as num).toInt(),
    brandName: json['brandName'] as String? ?? '',
    price: (json['price'] as num).toDouble(),
    compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
    primaryImageUrl: json['primaryImageUrl'] as String?,
    stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? false,
    createdAt: parseServerDate(json['createdAt']) ??
        DateTime.now(),
  );
}

class ProductImage {
  final int id;
  final String imageUrl;
  final bool isPrimary;
  final int sortOrder;

  const ProductImage({
    required this.id,
    required this.imageUrl,
    required this.isPrimary,
    required this.sortOrder,
  });

  String get fullImageUrl {
    if (imageUrl.isEmpty) return '';
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    id: (json['id'] as num).toInt(),
    imageUrl: json['imageUrl'] as String? ?? '',
    isPrimary: json['isPrimary'] as bool? ?? false,
    sortOrder: (json['sortOrder'] as num).toInt(),
  );
}

class ProductVariant {
  final int id;
  final String sku;
  final String? color;
  final String? storage;
  final double price;
  final double? compareAtPrice;
  final int stockQuantity;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.sku,
    this.color,
    this.storage,
    required this.price,
    this.compareAtPrice,
    this.stockQuantity = 0,
    required this.isActive,
  });

  /// Còn bán được: biến thể đang hoạt động và còn tồn kho.
  bool get inStock => isActive && stockQuantity > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'color': color,
    'storage': storage,
    'price': price,
    'compareAtPrice': compareAtPrice,
    'stockQuantity': stockQuantity,
    'isActive': isActive,
  };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: (json['id'] as num).toInt(),
    sku: json['sku'] as String? ?? '',
    color: json['color'] as String?,
    storage: json['storage'] as String?,
    price: (json['price'] as num).toDouble(),
    compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
    stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? false,
  );
}

class ProductDetail {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String categoryName;
  final int brandId;
  final String brandName;
  final bool isActive;
  final DateTime createdAt;
  final List<ProductImage> images;
  final List<ProductVariant> variants;

  const ProductDetail({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.categoryName,
    required this.brandId,
    required this.brandName,
    required this.isActive,
    required this.createdAt,
    this.images = const [],
    this.variants = const [],
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    categoryId: (json['categoryId'] as num).toInt(),
    categoryName: json['categoryName'] as String? ?? '',
    brandId: (json['brandId'] as num).toInt(),
    brandName: json['brandName'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? false,
    createdAt: parseServerDate(json['createdAt']) ??
        DateTime.now(),
    images: (json['images'] as List<dynamic>? ?? [])
        .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
        .toList(),
    variants: (json['variants'] as List<dynamic>? ?? [])
        .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ProductRequest {
  final int categoryId;
  final int brandId;
  final String name;
  final String? description;
  final bool isActive;
  final String sku;
  final String? color;
  final String? storage;
  final double price;
  final double? compareAtPrice;
  final int stockQuantity;

  const ProductRequest({
    required this.categoryId,
    required this.brandId,
    required this.name,
    this.description,
    this.isActive = true,
    required this.sku,
    this.color,
    this.storage,
    required this.price,
    this.compareAtPrice,
    this.stockQuantity = 0,
  });

  Map<String, String> toFormFields() {
    return {
      'CategoryId': categoryId.toString(),
      'BrandId': brandId.toString(),
      'Name': name,
      'Description': description ?? '',
      'IsActive': isActive.toString(),
      'SKU': sku,
      'Color': color ?? '',
      'Storage': storage ?? '',
      'Price': price.toString(),
      'StockQuantity': stockQuantity.toString(),
      if (compareAtPrice != null) 'CompareAtPrice': compareAtPrice!.toString(),
    };
  }
}

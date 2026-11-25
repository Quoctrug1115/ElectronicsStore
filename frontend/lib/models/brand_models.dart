import '../../core/api_config.dart';
import '../core/format.dart';

class BrandResponse {
  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final bool isActive;
  final DateTime createdAt;
  final int productCount;

  const BrandResponse({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    required this.isActive,
    required this.createdAt,
    this.productCount = 0,
  });

  String get fullLogoUrl {
    if (logoUrl == null || logoUrl!.isEmpty) return '';
    return '${ApiConfig.baseUrl}$logoUrl';
  }

  factory BrandResponse.fromJson(Map<String, dynamic> json) => BrandResponse(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    logoUrl: json['logoUrl'] as String?,
    isActive: json['isActive'] as bool? ?? false,
    createdAt: parseServerDate(json['createdAt']) ??
        DateTime.now(),
    productCount: (json['productCount'] as num?)?.toInt() ?? 0,
  );
}

class BrandRequest {
  final String name;
  final String? description;
  final bool isActive;

  const BrandRequest({
    required this.name,
    this.description,
    this.isActive = true,
  });

  Map<String, String> toFormFields() {
    return {
      'Name': name,
      'Description': description ?? '',
      'IsActive': isActive.toString(),
    };
  }
}

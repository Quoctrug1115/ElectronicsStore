import '../../core/api_config.dart';
import '../core/format.dart';

class CategoryResponse {
  final int id;
  final String name;
  final int? parentId;
  final String? parentName;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final int productCount;

  const CategoryResponse({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    this.productCount = 0,
  });

  String get fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return '';
    return '${ApiConfig.baseUrl}$imageUrl';
  }

  factory CategoryResponse.fromJson(Map<String, dynamic> json) => CategoryResponse(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    parentId: (json['parentId'] as num?)?.toInt(),
    parentName: json['parentName'] as String?,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    isActive: json['isActive'] as bool? ?? false,
    createdAt: parseServerDate(json['createdAt']) ??
        DateTime.now(),
    productCount: (json['productCount'] as num?)?.toInt() ?? 0,
  );
}

class CategoryRequest {
  final String name;
  final int? parentId;
  final String? description;
  final bool isActive;

  const CategoryRequest({
    required this.name,
    this.parentId,
    this.description,
    this.isActive = true,
  });

  Map<String, String> toFormFields() {
    final fields = <String, String>{
      'Name': name,
      'Description': description ?? '',
      'IsActive': isActive.toString(),
    };
    if (parentId != null) {
      fields['ParentId'] = parentId!.toString();
    }
    return fields;
  }
}

import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/local_database.dart';
import '../models/product_models.dart';
import 'local_cache.dart';

class ProductService {
  ProductService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PagedResult<ProductListItem>> getProducts({
    int pageIndex = 1,
    int pageSize = 10,
    String? search,
    int? categoryId,
    int? brandId,
    String sortBy = 'newest',

    /// true (màn của khách): lưu kết quả vào SQLite và khi mất mạng thì đọc lại từ SQLite.
    bool useOffline = false,
  }) async {
    final query = <String, String>{
      'pageIndex': pageIndex.toString(),
      'pageSize': pageSize.toString(),
      'sortBy': sortBy,
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (categoryId != null) query['categoryId'] = categoryId.toString();
    if (brandId != null) query['brandId'] = brandId.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}')
        .replace(queryParameters: query);

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: await ApiClient.authHeaders())
          .timeout(ApiConfig.timeout);
    } catch (e) {
      if (useOffline && LocalCache.isNetworkError(e)) {
        final cached = await LocalCache.queryProducts(
          pageIndex: pageIndex,
          pageSize: pageSize,
          search: search,
          categoryId: categoryId,
          brandId: brandId,
          sortBy: sortBy,
        );
        if (cached != null) {
          LocalDatabase.offline.value = true;
          return PagedResult<ProductListItem>(
            items: cached.items.map(ProductListItem.fromJson).toList(),
            totalCount: cached.total,
            pageIndex: pageIndex,
            pageSize: pageSize,
          );
        }
      }
      rethrow;
    }

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final map = data as Map<String, dynamic>;
      if (useOffline) {
        LocalDatabase.offline.value = false;
        await LocalCache.saveProducts(
          (map['items'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
      }
      return PagedResult<ProductListItem>.fromJson(
        map,
        ProductListItem.fromJson,
      );
    }
    throw ApiClient.toException(status, data);
  }

  Future<ProductDetail> getProductById(int id, {bool useOffline = false}) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}/$id'),
            headers: await ApiClient.authHeaders(),
          )
          .timeout(ApiConfig.timeout);
    } catch (e) {
      if (useOffline && LocalCache.isNetworkError(e)) {
        final cached = await LocalCache.loadProductDetail(id);
        if (cached != null) {
          LocalDatabase.offline.value = true;
          return ProductDetail.fromJson(cached);
        }
      }
      rethrow;
    }

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final map = data as Map<String, dynamic>;
      if (useOffline) {
        LocalDatabase.offline.value = false;
        await LocalCache.saveProductDetail(id, map);
      }
      return ProductDetail.fromJson(map);
    }
    throw ApiClient.toException(status, data);
  }

  Future<ProductDetail> createProduct(
    ProductRequest request, {
    required List<File> imageFiles,
  }) async {
    final response = await _postMultipart(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}'),
      request.toFormFields(),
      imageFiles.map((f) => _toMultipartFile(f, 'ImageFiles')).toList(),
    );
    final data = response.data;
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final productId = (data as Map)['productId'] as num?;
      if (productId != null) return getProductById(productId.toInt());
      return ProductDetail.fromJson(data as Map<String, dynamic>);
    }
    throw ApiClient.toException(status, data);
  }

  Future<ProductDetail> updateProduct(
    int id,
    ProductRequest request, {
    required List<File> imageFiles,
  }) async {
    final response = await _postMultipart(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}/$id'),
      request.toFormFields(),
      imageFiles.map((f) => _toMultipartFile(f, 'ImageFiles')).toList(),
    );
    final data = response.data;
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return getProductById(id);
    }
    throw ApiClient.toException(status, data);
  }

  Future<void> deleteProduct(int id) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.products}/$id'),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    throw ApiClient.toException(status, data);
  }

  Future<({dynamic data, int statusCode})> _postMultipart(
    String method,
    Uri uri,
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) async {
    final request = http.MultipartRequest(method, uri)
      ..headers.addAll(await ApiClient.authHeaders())
      ..fields.addAll(fields)
      ..files.addAll(files);

    final streamedResponse = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return (
      data: ApiClient.decodeBody(response),
      statusCode: response.statusCode,
    );
  }

  http.MultipartFile _toMultipartFile(File file, String fieldName) =>
      http.MultipartFile(
        fieldName,
        file.readAsBytes().asStream(),
        file.lengthSync(),
        filename: file.path.split(Platform.pathSeparator).last,
      );
}

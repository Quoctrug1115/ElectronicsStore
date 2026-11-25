import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/local_database.dart';
import '../models/category_models.dart';
import 'local_cache.dart';

class CategoryService {
  CategoryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<CategoryResponse>> getCategories({
    bool? isActive,

    /// true (màn của khách): lưu vào SQLite và khi mất mạng thì đọc lại từ SQLite.
    bool useOffline = false,
  }) async {
    final query = <String, String>{};
    if (isActive != null) query['isActive'] = isActive.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}')
        .replace(queryParameters: query);

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: await ApiClient.authHeaders())
          .timeout(ApiConfig.timeout);
    } catch (e) {
      if (useOffline && LocalCache.isNetworkError(e)) {
        final cached = await LocalCache.loadCategories(isActive: isActive);
        if (cached.isNotEmpty) {
          LocalDatabase.offline.value = true;
          return cached.map(CategoryResponse.fromJson).toList();
        }
      }
      rethrow;
    }

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final list = (data as List<dynamic>).cast>();
      if (useOffline) {
        LocalDatabase.offline.value = false;
        await LocalCache.saveCategories(list, replaceAll: isActive == null);
      }
      return list.map(CategoryResponse.fromJson).toList();
    }
    throw ApiClient.toException(status, data);
  }

  Future<CategoryResponse> getCategoryById(int id) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}/$id'),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return CategoryResponse.fromJson(data as Map<String, dynamic>);
    }
    throw ApiClient.toException(status, data);
  }

  Future<CategoryResponse> createCategory(
    CategoryRequest request, {
    File? imageFile,
  }) async {
    final requestMulti =
        http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}'),
          )
          ..headers.addAll(await ApiClient.authHeaders())
          ..fields.addAll(request.toFormFields());

    if (imageFile != null) {
      requestMulti.files.add(
        http.MultipartFile(
          'ImageFile',
          imageFile.readAsBytes().asStream(),
          imageFile.lengthSync(),
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return _sendMultipart<CategoryResponse>(
      requestMulti,
      (json) => CategoryResponse.fromJson(json as Map<String, dynamic>),
      wrapperKey: 'data',
    );
  }

  Future<CategoryResponse> updateCategory(
    int id,
    CategoryRequest request, {
    File? imageFile,
    bool removeImage = false,
  }) async {
    final requestMulti =
        http.MultipartRequest(
            'PUT',
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}/$id'),
          )
          ..headers.addAll(await ApiClient.authHeaders())
          ..fields.addAll(request.toFormFields())
          ..fields['RemoveImage'] = removeImage.toString();

    if (imageFile != null) {
      requestMulti.files.add(
        http.MultipartFile(
          'ImageFile',
          imageFile.readAsBytes().asStream(),
          imageFile.lengthSync(),
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return _sendMultipart<CategoryResponse>(
      requestMulti,
      (json) => CategoryResponse.fromJson(json as Map<String, dynamic>),
      wrapperKey: 'data',
    );
  }

  Future<void> deleteCategory(int id) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.categories}/$id'),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    throw ApiClient.toException(status, data);
  }

  Future<T> _sendMultipart<T>(
    http.MultipartRequest request,
    T Function(dynamic) itemFromJson, {
    String? wrapperKey,
  }) async {
    final streamedResponse = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final json = wrapperKey == null || data is! Map ? data : data[wrapperKey];
      return itemFromJson(json);
    }
    throw ApiClient.toException(status, data);
  }
}
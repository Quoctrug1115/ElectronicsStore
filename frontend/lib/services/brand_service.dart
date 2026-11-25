import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/brand_models.dart';

class BrandService {
  BrandService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<BrandResponse>> getBrands({bool? isActive}) async {
    final query = <String, String>{};
    if (isActive != null) query['isActive'] = isActive.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.brands}')
        .replace(queryParameters: query);

    final response = await _client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiConfig.timeout);

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return (data as List<dynamic>)
          .map((e) => BrandResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiClient.toException(status, data);
  }

  Future<BrandResponse> getBrandById(int id) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.brands}/$id'),
          headers: await ApiClient.authHeaders(),
        )
        .timeout(ApiConfig.timeout);

    final data = ApiClient.decodeBody(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return BrandResponse.fromJson(data as Map<String, dynamic>);
    }
    throw ApiClient.toException(status, data);
  }

  Future<BrandResponse> createBrand(
    BrandRequest request, {
    File? logoFile,
  }) async {
    final requestMulti =
        http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.brands}'),
          )
          ..headers.addAll(await ApiClient.authHeaders())
          ..fields.addAll(request.toFormFields());

    if (logoFile != null) {
      requestMulti.files.add(
        http.MultipartFile(
          'LogoFile',
          logoFile.readAsBytes().asStream(),
          logoFile.lengthSync(),
          filename: logoFile.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return _sendMultipart<BrandResponse>(
      requestMulti,
      (json) => BrandResponse.fromJson(json as Map<String, dynamic>),
      wrapperKey: 'data',
    );
  }

  Future<BrandResponse> updateBrand(
    int id,
    BrandRequest request, {
    File? logoFile,
  }) async {
    final requestMulti =
        http.MultipartRequest(
            'PUT',
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.brands}/$id'),
          )
          ..headers.addAll(await ApiClient.authHeaders())
          ..fields.addAll(request.toFormFields());

    if (logoFile != null) {
      requestMulti.files.add(
        http.MultipartFile(
          'LogoFile',
          logoFile.readAsBytes().asStream(),
          logoFile.lengthSync(),
          filename: logoFile.path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return _sendMultipart<BrandResponse>(
      requestMulti,
      (json) => BrandResponse.fromJson(json as Map<String, dynamic>),
      wrapperKey: 'data',
    );
  }

  Future<void> deleteBrand(int id) async {
    final response = await _client
        .delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.brands}/$id'),
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

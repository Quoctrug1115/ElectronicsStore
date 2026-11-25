import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/revenue_models.dart';

class AdminStatsService {
  AdminStatsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Gửi múi giờ của máy để backend chia "hôm nay / tháng này / từng ngày" đúng giờ địa phương.
  Future<RevenueStats> getRevenue({int days = 7}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminRevenue}')
        .replace(
          queryParameters: {
            'days': '$days',
            'tzOffsetMinutes': '${DateTime.now().timeZoneOffset.inMinutes}',
          },
        );
    final response = await _client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiConfig.timeout);
    return RevenueStats.fromJson(
      ApiClient.unwrap(response) as Map<String, dynamic>,
    );
  }
}

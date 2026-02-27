import 'api_constants.dart';
import 'api_client.dart';

class AlertService {
  Future<Map<String,dynamic>> list(String token, {String? rbwId, bool unreadOnly = false, int perPage = 20}) async {
    final params = <String,String>{
      'per_page': perPage.toString(),
    };
    if (rbwId != null) params['rbw_id'] = rbwId;
    if (unreadOnly) params['unread_only'] = 'true';
    final url = ApiConstants.alerts;
    final res = await ApiClient.get(url, headers: ApiConstants.authHeaders(token), queryParams: params);
    return res is Map<String,dynamic> ? res : {'success': false, 'data': []};
  }

  Future<Map<String,dynamic>> markRead(String token, String alertId) async {
    final url = '${ApiConstants.alerts}/$alertId';
    final body = {'is_read': true};
    final res = await ApiClient.patch(url, headers: ApiConstants.authHeaders(token), body: body);
    return res is Map<String,dynamic> ? res : {'success': false};
  }

  Future<Map<String,dynamic>> createLocalSynthetic(String token, {required String title, required String message, String? rbwId, String severity = 'info'}) async {

    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'message': message,
      'severity': severity,
      'rbw_id': rbwId,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'synthetic': true,
    };
  }
}

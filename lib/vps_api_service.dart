import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vps_config.dart';

class VpsApiService {
  static String get baseUrl => VpsConfig.apiBaseUrl;
  static String? authToken;

  static List<String> get candidateBaseUrls => [
        'http://89.116.52.173/api.php',
        VpsConfig.apiBaseUrl,
        'http://200.141.4.137/api.php',
        'http://localhost/api.php',
        'http://127.0.0.1/api.php',
        'http://localhost/vps_backend/api.php',
      ];

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// Test connection to VPS server
  static Future<bool> testConnection() async {
    for (var base in candidateBaseUrls) {
      try {
        final String fullUrl = base.contains('?') ? '$base&action=sellers' : '$base?action=sellers';
        final response = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Generic GET request with multi-URL candidate fallback
  static Future<dynamic> get(String action) async {
    String formattedAction = action.trim();
    if (!formattedAction.startsWith('action=') && !formattedAction.contains('action=')) {
      if (formattedAction.contains('&')) {
        final parts = formattedAction.split('&');
        formattedAction = 'action=${parts[0]}&${parts.sublist(1).join('&')}';
      } else {
        formattedAction = 'action=$formattedAction';
      }
    }

    for (var base in candidateBaseUrls) {
      try {
        final String fullUrl = base.contains('?') ? '$base&$formattedAction' : '$base?$formattedAction';
        final Uri uri = Uri.parse(Uri.encodeFull(fullUrl));
        final response = await http.get(
          uri,
          headers: _headers,
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final resData = _handleResponse(response);
          if (resData != null) return resData;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Generic POST request with multi-URL candidate fallback
  static Future<dynamic> post(String action, Map<String, dynamic> data) async {
    String formattedAction = action.trim();
    if (!formattedAction.startsWith('action=') && !formattedAction.contains('action=')) {
      formattedAction = 'action=$formattedAction';
    }
    if (!data.containsKey('action')) {
      data['action'] = action;
    }

    for (var base in candidateBaseUrls) {
      try {
        final String fullUrl = base.contains('?') ? '$base&$formattedAction' : '$base?$formattedAction';
        final Uri uri = Uri.parse(Uri.encodeFull(fullUrl));
        final response = await http.post(
          uri,
          headers: _headers,
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final resData = _handleResponse(response);
          if (resData != null) return resData;
        }
      } catch (_) {}
    }
    return null;
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vps_config.dart';

class VpsApiService {
  static String get baseUrl => VpsConfig.apiBaseUrl;
  static String? authToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// Test connection to VPS server
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse(baseUrl)).timeout(
            const Duration(seconds: 5),
          );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Generic GET request with automatic URI Encoding for parameters
  static Future<dynamic> get(String action) async {
    try {
      final String fullUrl = '$baseUrl?action=$action';
      final Uri uri = Uri.parse(Uri.encodeFull(fullUrl));
      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      return _handleResponse(response);
    } catch (e) {
      return null;
    }
  }

  /// Generic POST request
  static Future<dynamic> post(String action, Map<String, dynamic> data) async {
    try {
      final String fullUrl = '$baseUrl?action=$action';
      final Uri uri = Uri.parse(Uri.encodeFull(fullUrl));
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 5));
      return _handleResponse(response);
    } catch (e) {
      return null;
    }
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }
}

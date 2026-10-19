import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get baseUrl => ApiConfig.baseUrl;

  /// Retrieves a valid Firebase ID token with optional force refresh
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('⚠️ [ApiService] Error getting Firebase ID token: $e');
      return null;
    }
  }

  /// Builds standard headers including Authorization: Bearer `token`
  Future<Map<String, String>> _getHeaders({bool isRetry = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await getIdToken(forceRefresh: isRetry);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// GET request
  Future<dynamic> get(String endpoint) async {
    return _sendRequest(
      () async => http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      ),
      endpoint: endpoint,
    );
  }

  /// POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    return _sendRequest(
      () async => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ),
      endpoint: endpoint,
    );
  }

  /// PATCH request
  Future<dynamic> patch(String endpoint, [Map<String, dynamic>? body]) async {
    return _sendRequest(
      () async => http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
      endpoint: endpoint,
    );
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint) async {
    return _sendRequest(
      () async => http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      ),
      endpoint: endpoint,
    );
  }

  /// Internal request sender with automatic 401 token refresh retry
  Future<dynamic> _sendRequest(
    Future<http.Response> Function() requestFn, {
    required String endpoint,
    bool isRetry = false,
  }) async {
    try {
      final response = await requestFn();

      // If token expired (401) and we haven't retried yet, force refresh ID token and retry once
      if (response.statusCode == 401 && !isRetry && _auth.currentUser != null) {
        debugPrint('🔄 [ApiService] 401 received. Refreshing Firebase ID token and retrying...');
        await getIdToken(forceRefresh: true);
        return await _sendRequest(requestFn, endpoint: endpoint, isRetry: true);
      }

      final responseBody = response.body;
      dynamic decodedData;
      try {
        decodedData = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
      } catch (_) {
        decodedData = responseBody;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedData;
      }

      final errorMessage = decodedData is Map && decodedData['message'] != null
          ? decodedData['message'].toString()
          : 'Request failed with status ${response.statusCode}';

      throw ApiException(
        statusCode: response.statusCode,
        message: errorMessage,
        data: decodedData,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ [ApiService] Network error on $endpoint: $e');
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to backend server ($baseUrl). Check your connection.',
        data: e.toString(),
      );
    }
  }
}

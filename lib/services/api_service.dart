import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://eastbus-backend-production.up.railway.app/api',
  );

  static const Duration timeout = Duration(seconds: 20);

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('staff_token')?.trim() ?? '';

      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<dynamic> get(String path, {bool auth = true}) async {
    try {
      final response = await http.get(
        _uri(path),
        headers: await _headers(auth: auth),
      ).timeout(timeout);

      return await _decode(response, auth: auth);
    } on TimeoutException {
      throw Exception(
        'Server connection timed out. Please check your internet connection.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to connect to the EastBus server.',
      );
    }
  }

  static Future<dynamic> post(
      String path,
      Map<String, dynamic> body, {
        bool auth = true,
      }) async {
    try {
      final response = await http.post(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ).timeout(timeout);

      return await _decode(response, auth: auth);
    } on TimeoutException {
      throw Exception(
        'Server connection timed out. Please check your internet connection.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to connect to the EastBus server.',
      );
    }
  }

  static Uri _uri(String path) {
    final cleanBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final cleanPath = path.trim().replaceFirst(RegExp(r'^/+'), '');

    return Uri.parse('$cleanBase/$cleanPath');
  }

  static Future<dynamic> _decode(
      http.Response response, {
        required bool auth,
      }) async {
    dynamic data;

    if (response.body.trim().isEmpty) {
      data = <String, dynamic>{};
    } else {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw Exception(
          'Invalid server response (${response.statusCode}).',
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (auth && response.statusCode == 401) {
      await _clearSession();

      throw Exception(
        'Your login session has expired. Please login again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        _message(data) ?? 'You are not allowed to perform this action.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        _message(data) ?? 'The requested information was not found.',
      );
    }

    if (response.statusCode == 422) {
      final validationMessage = _validationMessage(data);

      throw Exception(
        validationMessage ??
            _message(data) ??
            'Please check the entered information.',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception(
        _message(data) ??
            'EastBus server error. Please try again.',
      );
    }

    throw Exception(
      _message(data) ??
          'Request failed (${response.statusCode}).',
    );
  }

  static String? _message(dynamic data) {
    if (data is! Map) return null;

    final message = data['message']?.toString().trim();

    if (message == null || message.isEmpty) {
      return null;
    }

    return message;
  }

  static String? _validationMessage(dynamic data) {
    if (data is! Map || data['errors'] is! Map) {
      return null;
    }

    final errors = Map<dynamic, dynamic>.from(data['errors'] as Map);
    final messages = <String>[];

    for (final value in errors.values) {
      if (value is List) {
        for (final item in value) {
          final message = item.toString().trim();

          if (message.isNotEmpty) {
            messages.add(message);
          }
        }
      } else if (value != null) {
        final message = value.toString().trim();

        if (message.isNotEmpty) {
          messages.add(message);
        }
      }
    }

    if (messages.isEmpty) return null;

    return messages.join('\n');
  }

  static Map<String, dynamic> _map(dynamic data) {
    if (data is! Map) return {};

    final map = Map<String, dynamic>.from(data);

    if (map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }

    if (map['staff'] is Map) {
      return Map<String, dynamic>.from(map['staff'] as Map);
    }

    return map;
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    dynamic listData = data;

    if (data is Map) {
      listData =
          data['data'] ??
              data['trips'] ??
              data['passengers'] ??
              data['notifications'] ??
              [];
    }

    if (listData is! List) {
      return [];
    }

    return listData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> login({
    required String login,
    required String password,
  }) async {
    final cleanLogin = login.trim();

    if (cleanLogin.isEmpty) {
      throw Exception('Enter your login ID, phone number or email.');
    }

    if (password.isEmpty) {
      throw Exception('Enter your password.');
    }

    final data = await post(
      '/staff/login',
      {
        'login': cleanLogin,
        'password': password,
      },
      auth: false,
    );

    if (data is! Map) {
      throw Exception('Invalid login response.');
    }

    final response = Map<String, dynamic>.from(data);

    final token =
    '${response['token'] ?? response['access_token'] ?? ''}'.trim();

    if (token.isEmpty) {
      throw Exception('Login token was not returned by the server.');
    }

    final staff = response['staff'] is Map
        ? Map<String, dynamic>.from(response['staff'] as Map)
        : <String, dynamic>{};

    final staffId = '${staff['id'] ?? ''}'.trim();
    final loginId = '${staff['login_id'] ?? cleanLogin}'.trim();
    final fullName = '${staff['full_name'] ?? ''}'.trim();
    final role = '${staff['role'] ?? ''}'.trim();
    final operatorId = '${staff['operator_id'] ?? ''}'.trim();

    if (loginId.isEmpty) {
      throw Exception('Staff login ID was not returned by the server.');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('staff_token', token);
    await prefs.setString('staff_login_id', loginId);

    if (staffId.isNotEmpty) {
      await prefs.setString('staff_id', staffId);
    }

    if (fullName.isNotEmpty) {
      await prefs.setString('staff_full_name', fullName);
    }

    if (role.isNotEmpty) {
      await prefs.setString('staff_role', role);
    }

    if (operatorId.isNotEmpty) {
      await prefs.setString('staff_operator_id', operatorId);
    }
  }

  static Future<void> logout() async {
    try {
      await post('/staff/logout', {});
    } catch (_) {
      // Local session must still be cleared if server logout fails.
    }

    await _clearSession();
  }

  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('staff_token');
    await prefs.remove('staff_login_id');
    await prefs.remove('staff_id');
    await prefs.remove('staff_full_name');
    await prefs.remove('staff_role');
    await prefs.remove('staff_operator_id');
  }

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('staff_token')?.trim() ?? '';

    return token.isNotEmpty;
  }

  static Future<Map<String, dynamic>> me() async {
    return _map(
      await get('/staff/me'),
    );
  }

  static Future<Map<String, dynamic>> dashboard() async {
    final data = await get('/staff/dashboard');

    return data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
  }

  static Future<List<Trip>> trips() async {
    final data = await get('/staff/trips');
    final trips = <Trip>[];

    for (final item in _list(data)) {
      try {
        trips.add(Trip.fromJson(item));
      } catch (_) {
        // Ignore malformed trip records instead of crashing the trip list.
      }
    }

    return trips;
  }

  static Future<List<Map<String, dynamic>>> passengers(int tripId) async {
    return _list(
      await get('/staff/trips/$tripId/passengers'),
    );
  }

  static Future<List<Map<String, dynamic>>> notifications() async {
    return _list(
      await get('/staff/notifications'),
    );
  }

  static Future<void> sendLocation(
      int tripId,
      double latitude,
      double longitude,
      double speed, {
        double? heading,
        double? accuracy,
      }) async {
    if (latitude < -90 || latitude > 90) {
      throw Exception('Invalid GPS latitude.');
    }

    if (longitude < -180 || longitude > 180) {
      throw Exception('Invalid GPS longitude.');
    }

    await post(
      '/staff/trips/$tripId/location',
      {
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed < 0 ? 0 : speed,
        if (heading != null)
          'heading': ((heading % 360) + 360) % 360,
        if (accuracy != null && accuracy >= 0)
          'accuracy': accuracy,
      },
    );
  }
}
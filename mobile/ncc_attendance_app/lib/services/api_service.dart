import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/mock_data.dart';
import '../models/cadet.dart';

/// Talks to the Express backend in `app/backend` (routes under /api).
/// Falls back to mock data so the app works without a running server.
class ApiService {
  // The Android emulator reaches the host machine via 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:5001/api';

  String? _token;
  String _staffId = 'demo-staff'; // Staff.id (UUID) from login, sent as `markedBy`

  Future<bool> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        // Response: { message, token, staff: { id, email, institute } }
        final body = jsonDecode(res.body);
        _token = body['token'];
        _staffId = body['staff']['id'].toString();
        return true;
      }
      return false;
    } catch (_) {
      // Offline / demo mode: accept any non-empty credentials.
      return email.isNotEmpty && password.isNotEmpty;
    }
  }

  Future<List<Cadet>> fetchCadets() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/students'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Cadet.fromJson(e)).toList();
      }
    } catch (_) {}
    return mockCadets();
  }

  /// POST /api/attendance/mark  body: { paradeId, attendanceRecords: [...] }
  Future<bool> submitAttendance(List<Cadet> cadets, {String? paradeId}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/attendance/mark'),
            headers: _headers,
            body: jsonEncode({
              'paradeId': paradeId,
              'attendanceRecords':
                  cadets.map((c) => c.toAttendanceRecord(_staffId)).toList(),
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return true; // demo mode
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
}

final api = ApiService();

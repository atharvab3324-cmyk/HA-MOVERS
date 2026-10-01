import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthApiService {
 static const String _baseUrl = 'http://127.0.0.1:8000/api';

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Login failed',
    );
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.35:8000/api";

  static Future<String> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      return 'Connection failed: $e';
    }
  }
}
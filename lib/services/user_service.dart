import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:foodex/models/user.dart';

class UserService {
  final String baseUrl;

  UserService({required this.baseUrl});

  Future<User?> loadUser(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/foodexim/functions.php'),
        body: {
          'action': 'load-user',
          'id': userId.toString(),
        },
      );

      print('Loading user with ID: $userId');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final userData = jsonResponse['data'];
          final rights = jsonResponse['rights'] as List<dynamic>;

          final user = User.fromJson(userData, rights);

          // Print fetched data to console
          print('\nUser Details:');
          print('ID: ${user.id}');
          print('Name: ${user.name}');
          print('Type: ${user.type}');
          print('Status: ${user.status}');
          print('Rights: ${user.rights}');

          return user;
        } else {
          print('Error message: ${jsonResponse['message']}');
          return null;
        }
      } else {
        throw Exception(
            'Failed to load user. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading user: $e');
      rethrow;
    }
  }
}

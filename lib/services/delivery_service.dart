import 'dart:convert';
import 'package:http/http.dart' as http;
class DeliveryService {

  Future<void> pickUpOrder(int orderId) async {
    final url = 'https://vinczefi.com/foodexim/functions.php';
    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'action': 'pickup-order',
          'order': orderId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          // Order picked up successfully
          print("order picked up succesfully");
        } else {
          // Error occurred
          print('Error: ${result['message']}');
        }
      } else {
        throw Exception('Failed to pick up order');
      }
    } catch (e) {
      print('Error picking up order: $e');
      throw e;
    }
  }

  Future<void> deliverOrder(int orderId) async {
    final url = 'https://vinczefi.com/foodexim/functions.php';
    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'action': 'deliver-order',
          'order': orderId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          // Order picked up successfully
          print("order delivered succesfully");

          
        } else {
          // Error occurred
          print('Error: ${result['message']}');
        }
      } else {
        throw Exception('Failed to deliver up order');
      }
    } catch (e) {
      print('Error delivering order: $e');
      throw e;
    }
  }
}
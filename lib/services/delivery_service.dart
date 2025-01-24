import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DeliveryService {
  final String baseUrl = 'https://vinczefi.com/foodexim/functions.php';

  Future<void> pickupOrder(int orderId, bool isAdmin) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update-order.php'),
      body: {
        'action': 'pickup-order',
        'order': orderId.toString(),
        'admin': isAdmin.toString(),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to pickup order');
    }
  }

  Future<void> deliverOrder(int orderId, bool isAdmin) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update-order.php'),
      body: {
        'action': 'deliver-order',
        'order': orderId.toString(),
        'admin': isAdmin.toString(),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to deliver order');
    }
  }

  Future<void> updateOrderUit(int orderId, String uit) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'action': 'update-order',
          'type': 'uit',
          'order-id': orderId.toString(),
          'uit': uit,
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (!result['success']) {
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Failed to update UIT/EKR');
      }
    } catch (e) {
      print('Error updating UIT/EKR: $e');
      throw e;
    }
  }

  Future<void> updateOrderEkr(int orderId, String ekr) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'action': 'update-order',
          'type': 'ekr',
          'order-id': orderId.toString(),
          'ekr': ekr,
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (!result['success']) {
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Failed to update UIT/EKR');
      }
    } catch (e) {
      print('Error updating UIT/EKR: $e');
      throw e;
    }
  }

  Future<void> updateOrderInvoice(int orderId, List<File> invoiceFiles) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields.addAll({
        'action': 'update-order',
        'type': 'invoice',
        'order-id': orderId.toString(),
      });

      for (var file in invoiceFiles) {
        request.files.add(await http.MultipartFile.fromPath(
          'invoice[]', // Changed to array notation
          file.path,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result is List && result.isNotEmpty && !result[0]['success']) {
          throw Exception(result[0]['message']);
        }
      } else {
        throw Exception('Failed to update invoice');
      }
    } catch (e) {
      print('Error updating invoice: $e');
      throw e;
    }
  }

  Future<void> updateOrderCmr(int orderId, List<File> cmrFiles) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields.addAll({
        'action': 'update-order',
        'type': 'cmr',
        'order-id': orderId.toString(),
      });

      for (var file in cmrFiles) {
        request.files.add(await http.MultipartFile.fromPath(
          'cmr[]', // Changed to array notation
          file.path,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result is List && result.isNotEmpty && !result[0]['success']) {
          throw Exception(result[0]['message']);
        }
      } else {
        throw Exception('Failed to update CMR');
      }
    } catch (e) {
      print('Error updating CMR: $e');
      throw e;
    }
  }

  Future<void> updateCrates(int orderId, int quantity, String type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update-order.php'),
      body: {
        'action': 'update-order',
        'type': 'container',
        'order-id': orderId.toString(),
        'crate': quantity.toString(),
        'crate-type': type,
        'pallet': '0',
        'pallet-type': ''
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update crates');
    }
  }

  Future<void> updatePalets(int orderId, int quantity, String type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update-order.php'),
      body: {
        'action': 'update-order',
        'type': 'container',
        'order-id': orderId.toString(),
        'pallet': quantity.toString(),
        'pallet-type': type,
        'crate': '0',
        'crate-type': ''
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update palets');
    }
  }
// Helper method to handle all updates from dialog
  // Future<void> handleOrderUpdates(
  //     int orderId, Map<String, dynamic> updates) async {
  //   try {
  //     // Process document updates first
  //     if (updates['uit']?.isNotEmpty ?? false) {
  //       await updateOrderUit(orderId, updates['uit']);
  //     }

  //     if (updates['ekr']?.isNotEmpty ?? false) {
  //       await updateOrderEkr(orderId, updates['ekr']);
  //     }

  //     if (updates['invoice'] != null) {
  //       await updateOrderInvoice(orderId, File(updates['invoice']));
  //     }

  //     if (updates['cmr'] != null) {
  //       await updateOrderCmr(orderId, File(updates['cmr']));
  //     }

  //     // Handle container updates if present
  //     if (updates['containers'] != null) {
  //       await updateOrderContainer(
  //         orderId,
  //         containerData: updates['containers'],
  //       );
  //     }
  //   } catch (e) {
  //     print('Error handling order updates: $e')  ;
  //     throw e;
  //   }
  // }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DeliveryService {
  final String baseUrl = 'https://vinczefi.com/foodexim/functions.php';

  Future<void> pickUpOrder(int orderId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'action': 'pickup-order',
          'order': orderId.toString(),
        },
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          print("order picked up successfully");
        } else {
          print('Error: ${result['message']}');
          throw Exception(result['message']);
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
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'action': 'deliver-order',
          'order': orderId.toString(),
        },
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          print("order delivered successfully");
        } else {
          print('Error: ${result['message']}');
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Failed to deliver order');
      }
    } catch (e) {
      print('Error delivering order: $e');
      throw e;
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

  Future<void> updateOrderInvoice(int orderId, File invoiceFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields.addAll({
        'action': 'update-order',
        'type': 'invoice',
        'order-id': orderId.toString(),
      });

      request.files.add(await http.MultipartFile.fromPath(
        'invoice',
        invoiceFile.path,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (!result['success']) {
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Failed to update invoice');
      }
    } catch (e) {
      print('Error updating invoice: $e');
      throw e;
    }
  }

  Future<void> updateOrderCmr(int orderId, File cmrFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
      request.fields.addAll({
        'action': 'update-order',
        'type': 'cmr',
        'order-id': orderId.toString(),
      });

      request.files.add(await http.MultipartFile.fromPath(
        'cmr',
        cmrFile.path,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (!result['success']) {
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Failed to update CMR');
      }
    } catch (e) {
      print('Error updating CMR: $e');
      throw e;
    }
  }

  Future<void> updateOrderContainer(
    int orderId, {
    Map<String, dynamic>? containerData,
  }) async {
    try {
      if (containerData == null) {
        throw Exception('No container data provided');
      }

      // Extract container data
      final pallet = containerData['Pallet'];
      final crate = containerData['Case'];

      // Backend expects both pallet and crate data
      Map<String, String> body = {
        'action': 'update-order',
        'type': 'container',
        'order-id': orderId.toString(),
        'pallet': (pallet?['amount'] ?? '0').toString(),
        'pallet-type': pallet?['type'] ?? '',
        'crate': (crate?['amount'] ?? '0').toString(),
        'crate-type': crate?['type'] ?? '',
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        body: body,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (!result['success']) {
          String errorMessage = result['message'] ?? 'Unknown error occurred';
          // Make error message more user-friendly
          if (errorMessage.contains('No pallets found')) {
            errorMessage = 'Selected pallet type is not available in inventory';
          } else if (errorMessage.contains('No crates found')) {
            errorMessage = 'Selected crate type is not available in inventory';
          }
          throw Exception(errorMessage);
        }
      } else {
        throw Exception('Failed to update container information');
      }
    } catch (e) {
      print('Error updating container information: $e');
      throw e;
    }
  }

// Helper method to handle all updates from dialog
  Future<void> handleOrderUpdates(
      int orderId, Map<String, dynamic> updates) async {
    try {
      // Process document updates first
      if (updates['uit']?.isNotEmpty ?? false) {
        await updateOrderUit(orderId, updates['uit']);
      }

      if (updates['ekr']?.isNotEmpty ?? false) {
        await updateOrderEkr(orderId, updates['ekr']);
      }

      if (updates['invoice'] != null) {
        await updateOrderInvoice(orderId, File(updates['invoice']));
      }

      if (updates['cmr'] != null) {
        await updateOrderCmr(orderId, File(updates['cmr']));
      }

      // Handle container updates if present
      if (updates['containers'] != null) {
        await updateOrderContainer(
          orderId,
          containerData: updates['containers'],
        );
      }
    } catch (e) {
      print('Error handling order updates: $e');
      throw e;
    }
  }
}

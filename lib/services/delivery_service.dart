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

  Future<void> updateOrderUitEkr(int orderId, String uitEkr) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'action': 'update-order',
          'type': 'uit-ekr',
          'order-id': orderId.toString(),
          'uit-ekr': uitEkr,
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
    String? crateType,
    String? palletType,
    int? crateAmount,
    int? palletAmount,
  }) async {
    try {
      // Only include container types that are actually selected
      Map<String, String> body = {
        'action': 'update-order',
        'type': 'container',
        'order-id': orderId.toString(),
      };

      // Only add crate info if it's provided
      if (crateType != null && crateAmount != null && crateAmount > 0) {
        body['crate'] = crateAmount.toString();
        body['crate-type'] = crateType;
      }

      // Only add pallet info if it's provided
      if (palletType != null && palletAmount != null && palletAmount > 0) {
        body['pallet'] = palletAmount.toString();
        body['pallet-type'] = palletType;
      }

      // If neither crate nor pallet info is provided, return early
      if (!body.containsKey('crate') && !body.containsKey('pallet')) {
        return;
      }

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
      // Sequential processing to maintain order and handle errors better
      List<Future<void>> updateOperations = [];

      // Collect all necessary update operations
      if (updates['UitEkr']?.isNotEmpty ?? false) {
        updateOperations.add(updateOrderUitEkr(orderId, updates['UitEkr']));
      }

      if (updates['Invoice'] != null) {
        updateOperations
            .add(updateOrderInvoice(orderId, File(updates['Invoice'])));
      }

      if (updates['CMR'] != null) {
        updateOperations.add(updateOrderCmr(orderId, File(updates['CMR'])));
      }

      if (updates['Pallet'] != null || updates['Case'] != null) {
        updateOperations.add(updateOrderContainer(
          orderId,
          crateType: updates['Case']?['type'],
          palletType: updates['Pallet']?['type'],
          crateAmount: updates['Case']?['amount'],
          palletAmount: updates['Pallet']?['amount'],
        ));
      }

      // Execute all updates sequentially
      for (var operation in updateOperations) {
        await operation;
      }

      return;
    } catch (e) {
      print('Error handling order updates: $e');
      throw e;
    }
  }
}

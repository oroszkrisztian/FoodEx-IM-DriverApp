import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';

class OrderService {
  // Separate lists for different order types
  List<Order> _activeOrders = [];
  List<Order> _inactiveOrders = [];
  
  // Getters to access orders
  List<Order> get activeOrders => _activeOrders;
  List<Order> get inactiveOrders => _inactiveOrders;
  List<Order> get allOrders => [..._activeOrders, ..._inactiveOrders];

  // Helper method to process a single order status response
  Future<List<Order>> _processOrderStatus(String status, {String? fromDate, String? toDate}) async {
    try {
      final body = {
        'action': 'show-orders-flutter',
        'order-status': status,
        'driver': Globals.userId.toString()
      };

      if (fromDate != null) body['from_date'] = fromDate;
      if (toDate != null) body['to_date'] = toDate;

      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Response body for $status orders: ${response.body}');
        
        if (data['success']) {
          // Handle empty data cases
          if (data['data'] == null || data['data'].isEmpty) {
            debugPrint('No $status orders found - empty data array');
            return [];
          }

          // Handle single null order case
          if (data['data'].length == 1) {
            final firstOrder = data['data'][0];
            if (firstOrder['order_number'] == null && 
                (firstOrder['order_details'] == null || 
                 json.decode(firstOrder['order_details'])['order_id'] == null)) {
              debugPrint('No $status orders found - null order received');
              return [];
            }
          }

          // Process valid orders
          List<Order> orders = (data['data'] as List).map((orderJson) {
            Map<String, dynamic> orderDetails = {};
            if (orderJson['order_details'] != null) {
              try {
                orderDetails = json.decode(orderJson['order_details']);
              } catch (e) {
                debugPrint('Error decoding order_details: $e');
                return null;
              }
            }

            // Skip invalid orders
            if (orderDetails['order_id'] == null) return null;

            // Decode additional fields
            List companies = [];
            List warehouses = [];
            List products = [];
            List contactPeople = [];

            try {
              companies = json.decode(orderJson['companies'] ?? '[]');
              warehouses = json.decode(orderJson['warehouses'] ?? '[]');
              products = json.decode(orderJson['products'] ?? '[]');
              if (orderJson['contact_people'] != null && 
                  orderJson['contact_people'] != 'null') {
                contactPeople = json.decode(orderJson['contact_people']);
              }
            } catch (e) {
              debugPrint('Error decoding order data: $e');
            }

            try {
              return Order.fromJson({
                ...orderDetails,
                'companies': companies,
                'warehouses': warehouses,
                'products': products,
                'contact_people': contactPeople,
              });
            } catch (e) {
              debugPrint('Error creating Order object: $e');
              return null;
            }
          })
          .where((order) => order != null)
          .cast<Order>()
          .toList();

          // Sort orders by pickup time
          orders.sort((a, b) => a.pickupTime.compareTo(b.pickupTime));
          debugPrint('Total $status orders fetched: ${orders.length}');
          
          return orders;
        } else {
          throw Exception('Failed to load $status orders: ${data['message']}');
        }
      } else {
        throw Exception('Failed to load $status orders: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching $status orders: $e');
      throw e;
    }
  }

  // Fetch active orders only
  Future<void> fetchActiveOrders({String? fromDate, String? toDate}) async {
    _activeOrders = await _processOrderStatus('active', fromDate: fromDate, toDate: toDate);
    Globals.ordersNumber = _activeOrders.length;
    _debugPrintOrderInfo(_activeOrders, 'active');
  }

  // Fetch inactive orders only
  Future<void> fetchInactiveOrders({String? fromDate, String? toDate}) async {
    _inactiveOrders = await _processOrderStatus('inactive', fromDate: fromDate, toDate: toDate);
    _debugPrintOrderInfo(_inactiveOrders, 'inactive');
  }

  // Fetch both active and inactive orders
  Future<void> fetchAllOrders({String? fromDate, String? toDate}) async {
    try {
      // Reset the counter before fetching
      Globals.ordersNumber = 0;

      // Fetch both types concurrently
      final results = await Future.wait([
        _processOrderStatus('active', fromDate: fromDate, toDate: toDate),
        _processOrderStatus('inactive', fromDate: fromDate, toDate: toDate)
      ]);

      // Update the stored orders
      _activeOrders = results[0];
      _inactiveOrders = results[1];

      // Update global counter with total
      Globals.ordersNumber = _activeOrders.length + _inactiveOrders.length;

      // Debug logging
      debugPrint('StartDate: $fromDate');
      debugPrint('EndDate: $toDate');
      _debugPrintOrderInfo(_activeOrders, 'active');
      _debugPrintOrderInfo(_inactiveOrders, 'inactive');
    } catch (e) {
      debugPrint('Error fetching all orders: $e');
      throw e;
    }
  }

  // Helper method for debug logging
  void _debugPrintOrderInfo(List<Order> orders, String type) {
    debugPrint('Total $type orders: ${orders.length}');
    for (var order in orders) {
      debugPrint('$type Order ID: ${order.orderId}, '
          'Total Product Quantity: ${order.getTotalQuantity()}');
      for (var contact in order.contactPeople) {
        debugPrint('Contact for $type order ${order.orderId}: '
            'Name: ${contact.name}, Tel: ${contact.telephone}, Type: ${contact.type}');
      }
    }
  }

  Future<int?> checkVehicleLogin() async {
    try {
      final body = {
        'action': 'get-vehicle-id',
        'driver': Globals.userId.toString()
      };

      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('Raw vehicle response: ${response.body}');
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final vehicleData = data['data'];
          final vehicleId = vehicleData['vehicle_id'];

          if (vehicleId != null) {
            int? parsedVehicleId;
            if (vehicleId is String) {
              parsedVehicleId = int.tryParse(vehicleId);
            } else if (vehicleId is int) {
              parsedVehicleId = vehicleId;
            }

            if (parsedVehicleId != null) {
              Globals.vehicleID = parsedVehicleId;
              debugPrint('Successfully stored vehicle ID: $parsedVehicleId');

              if (vehicleData['photos'] != null) {
                final List<dynamic> photos = json.decode(vehicleData['photos']);
                debugPrint('Found ${photos.length} photos');
              }

              return parsedVehicleId;
            }
          }

          debugPrint('No valid vehicle ID found in response');
          return null;
        }
        
        debugPrint('Response indicates failure or missing data: ${data['message']}');
        return null;
      }
      
      debugPrint('HTTP Error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error in checkVehicleLogin: $e');
      return null;
    }
  }

  bool isOrderDelivered(Order order) {
    return order.delivered != '0000-00-00 00:00:00';
  }
}
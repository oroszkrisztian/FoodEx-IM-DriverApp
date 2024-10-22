// lib/services/order_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart'; // Adjust import paths as needed

// Import models

class OrderService {
  List<Order> _orders = [];

  List<Order> get orders => _orders;

  Future<void> fetchOrders({DateTime? fromDate, DateTime? toDate}) async {
    Globals.ordersNumber = 0;
    try {
      final body = {
        'action': 'show-orders-flutter',
        if (fromDate != null) 'data-from': fromDate.toString().split(' ')[0],
        if (toDate != null) 'data-to': toDate.toString().split(' ')[0],
        'order-status': 'active',
        'driver' : Globals.userId.toString()
      };

      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Response body: ${response.body}');
        if (data['success']) {
          _orders = (data['data'] as List).map((orderJson) {
            final orderDetails = json.decode(orderJson['order_details']);

            return Order.fromJson({
              ...orderDetails,
              'companies': json.decode(orderJson['companies'] ?? '[]'),
              'warehouses': json.decode(orderJson['warehouses'] ?? '[]'),
              'products': json.decode(orderJson['products'] ?? '[]'),
              'contact_people': orderJson['contact_people'] is String &&
                      orderJson['contact_people'] != 'null'
                  ? json.decode(orderJson['contact_people'])
                  : [],
            });
          }).toList();

          print('Total orders fetched: ${orders.length}');
          Globals.ordersNumber = _orders.length;

          // Print total quantity for each order
          for (var order in _orders) {
            print(
                'Order ID: ${order.orderId}, Total Product Quantity: ${order.getTotalQuantity()}');
          }

          // Print total quantity and notes for each order
          for (var order in _orders) {
            print('Order ID: ${order.orderId}');
            print('Contact People:');
            for (var contact in order.contactPeople) {
              print(
                  'Name: ${contact.name}, Telephone: ${contact.telephone}, Type: ${contact.type}');
            }
          }
        } else {
          throw Exception('Failed to load orders: ${data['message']}');
        }
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      throw e;
    }
  }

  bool isOrderDelivered(Order order) {
    // Check if the 'delivered' field is not equal to '0000-00-00 00:00:00'
    return order.delivered != '0000-00-00 00:00:00';
  }
}

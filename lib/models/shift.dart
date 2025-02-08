import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';

class Shift {
  final int id;
  final int driverId;
  final String driverName;
  final int vehicleId;
  final String vehicle;
  final DateTime startTime;
  final DateTime endTime;
  final String? remarks;
  final List<dynamic> orders;

  Shift({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.vehicleId,
    required this.vehicle,
    required this.startTime,
    required this.endTime,
    this.remarks,
    required this.orders,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    var ordersData = [];
    if (json['orders'] != null) {
      // The orders field is already a string from PHP's JSON_ARRAYAGG
      ordersData = jsonDecode(json['orders'] as String);
    }

    return Shift(
      id: json['id'],
      driverId: json['driver_id'],
      driverName: json['name'],
      vehicleId: json['vehicle_id'],
      vehicle: json['vehicle'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      remarks:
          json['remarks']?.toString(), // Ensure remarks is converted to String
      orders: ordersData,
    );
  }

  // Get total number of orders in the shift
  // Helper methods
  int get totalOrder {
    if ( orders[0]['order_id'] == null && orders.length == 1) {
      print(orders.toString());
      return 0;
    } else {
      return orders.length;
    }
  }

  // Calculate total weight of all products in all orders
  double get totalWeight {
    double total = 0.0;

    for (var order in orders) {
      if (order != null && order['products'] != null) {
        List<dynamic> products = order['products'];
        for (var product in products) {
          total += (product['product_weight'] as num).toDouble();
        }
      }
    }

    return total;
  }
}

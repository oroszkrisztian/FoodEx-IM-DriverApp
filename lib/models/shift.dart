import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/colections.dart';

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
          json['remarks']?.toString(), 
      orders: ordersData,
    );
  }

  // Get total number of orders in the shift
  // Helper methods
  int get totalOrder {
    if (orders[0]['order_id'] == null && orders.length == 1) {
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

  // Get all collection units across all orders
  List<CollectionUnit> get collectionUnits {
    Map<String, CollectionUnit> combinedUnits = {};

    for (var order in orders) {
      if (order != null && order['products'] != null) {
        List<dynamic> products = order['products'];
        for (var product in products) {
          // Only process if both collection_unit and collection_quantity exist and are not null
          if (product['collection_unit'] != null &&
              product['collection_quantity'] != null &&
              product['collection_unit'].toString().isNotEmpty) {
            String unitName = product['collection_unit'].toString();
            int quantity =
                int.tryParse(product['collection_quantity'].toString()) ?? 0;

            if (quantity > 0) {
              // Create a unique key for the collection unit
              String key = unitName;

              if (combinedUnits.containsKey(key)) {
                // Add to existing quantity
                var existingUnit = combinedUnits[key]!;
                combinedUnits[key] = CollectionUnit(
                    id: existingUnit.id,
                    type: existingUnit.type,
                    name: unitName,
                    quantity: existingUnit.quantity + quantity);
              } else {
                // Create new collection unit
                combinedUnits[key] = CollectionUnit(
                    id: 1, 
                    type:
                        'default', 
                    name: unitName,
                    quantity: quantity);
              }
            }
          }
        }
      }
    }

    // Convert to list and sort by name
    var unitsList = combinedUnits.values.toList();
    unitsList.sort((a, b) => a.name.compareTo(b.name));
    return unitsList;
  }

  int get totalCollectionUnits {
    return collectionUnits.fold(0, (sum, unit) => sum + unit.quantity);
  }
}

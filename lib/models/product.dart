import 'package:flutter/material.dart';

class Product {
  final int productId;
  final String productName;
  final String productUnit;
  final String productType;
  final double productWeight;
  final int quantity;
  final double price;
  final int collection;
  final int ordered;

  Product({
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.productType,
    required this.productWeight,
    required this.quantity,
    required this.price,
    required this.collection,
    required this.ordered,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      return Product(
        productId: json['product_id'] ?? 0, // Provide default value
        productName: json['product_name'] ?? '', // Provide default value
        productUnit: json['product_unit'] ?? '', // Provide default value
        productType: json['product_type'] ?? '', // Provide default value
        productWeight: (json['product_weight'] as num?)?.toDouble() ??
            0.0, // Handle null and type casting
        quantity: json['quantity'] ?? 0, // Provide default value
        price: (json['price'] as num?)?.toDouble() ??
            0.0, // Handle null and type casting
        collection: json['collection_quantity'] ?? 0, // Provide default value
        ordered: json['ordered'] ?? 0, // Provide default value
      );
    } catch (e) {
      debugPrint('Error parsing Product: $e, JSON: $json');
      rethrow; // Very important for debugging
    }
  }

  // Optional: Override toString() for easier debugging
}

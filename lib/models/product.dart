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
        productId: json['product_id'] ?? 0,
        productName: json['product_name'] ?? '',
        productUnit: json['product_unit'] ?? '',
        productType: json['product_type'] ?? '',
        productWeight: (json['product_weight'] as num?)?.toDouble() ?? 0.0,
        quantity: json['quantity'] ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        collection: json['collection_quantity'] ?? 0,
        ordered: json['ordered'] ?? 0,
      );
    } catch (e) {
      debugPrint('Error parsing Product: $e, JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'product_unit': productUnit,
      'product_type': productType,
      'product_weight': productWeight,
      'quantity': quantity,
      'price': price,
      'collection_quantity': collection,
      'ordered': ordered,
    };
  }
}
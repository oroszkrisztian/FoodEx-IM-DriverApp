// lib/models/product.dart
class Product {
  final String productName;
  final int quantity;
  final double price;

  Product({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productName: json['product_name'],
      quantity: json['quantity'],
      price: json['price'].toDouble(),
    );
  }
}

class Product {
  final String productName;
  final String productUnit; // New field for measurement unit
  final String productType; // New field for product type
  final double productWeight; // New field for product weight
  final int quantity;
  final double price;

  Product({
    required this.productName,
    required this.productUnit, // Initialize product unit
    required this.productType, // Initialize product type
    required this.productWeight, // Initialize product weight
    required this.quantity,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productName: json['product_name'],
      productUnit: json['product_unit'] ?? '', // Handle missing product unit
      productType: json['product_type'] ?? '', // Handle missing product type
      productWeight: json['product_weight']?.toDouble() ??
          0.0, // Handle missing product weight
      quantity: json['quantity'],
      price: json['price'].toDouble(),
    );
  }
}

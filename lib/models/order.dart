import 'product.dart';
import 'company.dart';
import 'warehouse.dart';
import 'contact_person.dart';

class Order {
  final int orderId;
  final String driver;
  final String vehicle;
  final String pickupTime;
  final String deliveryTime;
  String pickedUp; // Add picked_up field
  String delivered; // Add delivered field
  final String upNotes;
  final String downNotes;
  final String uitEkr; // New field
  final String invoice; // New field
  final String cmr; // New field
  final List<Company> companies;
  final List<Warehouse> warehouses;
  final List<Product> products;
  final List<ContactPerson> contactPeople;

  Order({
    required this.orderId,
    required this.driver,
    required this.vehicle,
    required this.pickupTime,
    required this.deliveryTime,
    required this.pickedUp, // Initialize picked_up
    required this.delivered, // Initialize delivered
    required this.upNotes,
    required this.downNotes,
    required this.uitEkr, // Initialize uit_ekr
    required this.invoice, // Initialize invoice
    required this.cmr, // Initialize cmr
    required this.companies,
    required this.warehouses,
    required this.products,
    required this.contactPeople,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id'],
      driver: json['driver'],
      vehicle: json['vehicle'],
      pickupTime: json['pickup_time'],
      deliveryTime: json['delivery_time'],
      pickedUp: json['picked_up'] ??
          '0000-00-00 00:00:00', // Handle missing picked_up value
      delivered: json['delivered'] ??
          '0000-00-00 00:00:00', // Handle missing delivered value
      upNotes: json['up_notes'] ?? '',
      downNotes: json['down_notes'] ?? '',
      uitEkr: json['uit_ekr'] ?? '', // Handle missing uit_ekr value
      invoice: json['invoice'] ?? '', // Handle missing invoice value
      cmr: json['cmr'] ?? '', // Handle missing cmr value
      companies: (json['companies'] as List)
          .map((companyJson) => Company.fromJson(companyJson))
          .toList(),
      warehouses: (json['warehouses'] as List)
          .map((warehouseJson) => Warehouse.fromJson(warehouseJson))
          .toList(),
      products: (json['products'] as List)
          .map((productJson) => Product.fromJson(productJson))
          .toList(),
      contactPeople: (json['contact_people'] as List?)
              ?.map((contactJson) => ContactPerson.fromJson(contactJson))
              .toList() ??
          [],
    );
  }

  // Method to calculate the total quantity of products
  int getTotalQuantity() {
    return products.fold<int>(0, (total, product) => total + product.quantity);
  }

  // Calculate total weight
  double getTotalWeight() {
    return products.fold<double>(0.0,
        (total, product) => total + (product.quantity * product.productWeight));
  }
}

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
  String pickedUp;
  String delivered;
  final String upNotes;
  final String downNotes;
  final String uit;
  final String ekr;
  final String invoice;
  final String cmr;
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
    required this.pickedUp,
    required this.delivered,
    required this.upNotes,
    required this.downNotes,
    required this.uit,
    required this.ekr,
    required this.invoice,
    required this.cmr,
    required this.companies,
    required this.warehouses,
    required this.products,
    required this.contactPeople,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle potentially null or invalid order_id
    int safeOrderId;
    try {
      if (json['order_id'] == null) {
        safeOrderId = 0;
      } else if (json['order_id'] is String) {
        safeOrderId = int.tryParse(json['order_id']) ?? 0;
      } else {
        safeOrderId = json['order_id'] as int;
      }
    } catch (e) {
      print('Error parsing order_id: $e');
      safeOrderId = 0;
    }

    // Handle lists with null safety
    List<dynamic> safeCompanies = [];
    List<dynamic> safeWarehouses = [];
    List<dynamic> safeProducts = [];
    List<dynamic> safeContactPeople = [];

    try {
      safeCompanies = (json['companies'] is List) ? json['companies'] : [];
    } catch (e) {
      print('Error parsing companies: $e');
    }

    try {
      safeWarehouses = (json['warehouses'] is List) ? json['warehouses'] : [];
    } catch (e) {
      print('Error parsing warehouses: $e');
    }

    try {
      safeProducts = (json['products'] is List) ? json['products'] : [];
    } catch (e) {
      print('Error parsing products: $e');
    }

    try {
      safeContactPeople =
          (json['contact_people'] is List) ? json['contact_people'] : [];
    } catch (e) {
      print('Error parsing contact_people: $e');
    }

    return Order(
      orderId: safeOrderId,
      driver: json['driver']?.toString() ?? '',
      vehicle: json['vehicle']?.toString() ?? '',
      pickupTime: json['pickup_time']?.toString() ?? '0000-00-00 00:00:00',
      deliveryTime: json['delivery_time']?.toString() ?? '0000-00-00 00:00:00',
      pickedUp: json['picked_up']?.toString() ?? '0000-00-00 00:00:00',
      delivered: json['delivered']?.toString() ?? '0000-00-00 00:00:00',
      upNotes: json['up_notes']?.toString() ?? '',
      downNotes: json['down_notes']?.toString() ?? '',
      uit: json['uit']?.toString() ?? '',
      ekr: json['ekr']?.toString() ?? '',
      invoice: json['invoice']?.toString() ?? '',
      cmr: json['cmr']?.toString() ?? '',
      companies: safeCompanies
          .map((companyJson) => Company.fromJson(companyJson))
          .toList(),
      warehouses: safeWarehouses
          .map((warehouseJson) => Warehouse.fromJson(warehouseJson))
          .toList(),
      products: safeProducts
          .map((productJson) => Product.fromJson(productJson))
          .toList(),
      contactPeople: safeContactPeople
          .map((contactJson) => ContactPerson.fromJson(contactJson))
          .toList(),
    );
  }

  // Method to calculate the total quantity of products
  int getTotalQuantity() {
    return products.fold<int>(0, (total, product) => total + product.quantity);
  }

  //get order by id

  // Calculate total weight
  double getTotalWeight() {
    return products.fold<double>(0.0,
        (total, product) => total + (product.quantity * product.productWeight));
  }

  static Order empty() {
    return Order(
      orderId: 0,
      driver: '',
      vehicle: '',
      pickupTime: '0000-00-00 00:00:00',
      deliveryTime: '0000-00-00 00:00:00',
      pickedUp: '0000-00-00 00:00:00',
      delivered: '0000-00-00 00:00:00',
      upNotes: '',
      downNotes: '',
      uit: '',
      ekr: '',
      invoice: '',
      cmr: '',
      companies: [], // empty list
      warehouses: [], // empty list
      products: [], // empty list
      contactPeople: [], // empty list
    );
  }
}

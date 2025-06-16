import 'package:foodex/models/colections.dart';

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
  final bool existsPhotos; 
  final String orderNote; 
  final List<Company> companies;
  final List<Warehouse> warehouses;
  final List<Product> products;
  final List<ContactPerson> contactPeople;
  final List<CollectionUnit> collectionUnits;

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
    required this.existsPhotos,
    required this.orderNote, 
    required this.companies,
    required this.warehouses,
    required this.products,
    required this.contactPeople,
    required this.collectionUnits,
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
    List<dynamic> safeCollectionUnits = [];

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

    try {
      safeCollectionUnits =
          (json['collection_units'] is List) ? json['collection_units'] : [];
    } catch (e) {
      print('Error parsing collection_units: $e');
    }

    // Parse existsPhoto as boolean
    bool existsPhotos = false;
    try {
      if (json['existsPhoto'] is bool) {
        existsPhotos = json['existsPhoto'];
      } else if (json['existsPhoto'] is String) {
        existsPhotos = json['existsPhoto'].toLowerCase() == 'true' || 
                      json['existsPhoto'] == '1';
      } else if (json['existsPhoto'] is num) {
        existsPhotos = json['existsPhoto'] != 0;
      }
    } catch (e) {
      print('Error parsing existsPhoto: $e');
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
      existsPhotos: existsPhotos,
      orderNote: json['user_notes']?.toString() ?? '',  
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
      collectionUnits: safeCollectionUnits
          .map((unitJson) => CollectionUnit.fromJson(unitJson))
          .toList(),
    );
  }

  // Convert Order object to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'driver': driver,
      'vehicle': vehicle,
      'pickup_time': pickupTime,
      'delivery_time': deliveryTime,
      'picked_up': pickedUp,
      'delivered': delivered,
      'up_notes': upNotes,
      'down_notes': downNotes,
      'uit': uit,
      'ekr': ekr,
      'invoice': invoice,
      'cmr': cmr,
      'existsPhoto': existsPhotos,
      'user_notes': orderNote,
      'companies': companies.map((company) => company.toJson()).toList(),
      'warehouses': warehouses.map((warehouse) => warehouse.toJson()).toList(),
      'products': products.map((product) => product.toJson()).toList(),
      'contact_people': contactPeople.map((contact) => contact.toJson()).toList(),
      'collection_units': collectionUnits.map((unit) => unit.toJson()).toList(),
    };
  }

  // Method to calculate the total quantity of products
  double getTotalOrderedQuantity() {
    return products.fold<double>(0.0,
        (total, product) => total + (product.ordered * product.productWeight));
  }

  //get order by id
  int getTotalCollection() {
    return products.fold<int>(
        0, (total, product) => total + product.collectionQuantity);
  }

  // Calculate total weight
  double getTotalRecievedWeight() {
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
      existsPhotos: false,
      orderNote: '',  
      companies: [],
      warehouses: [],
      products: [],
      contactPeople: [],
      collectionUnits: [],
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/services/delivery_service.dart' show DeliveryService;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';

class OrderService {
  final _ordersController = StreamController<List<Order>>.broadcast();
  final DeliveryService _deliveryService =
      DeliveryService(); // Add DeliveryService instance

  // SharedPreferences keys
  static const String _activeOrdersKey = 'cached_active_orders';
  static const String _inactiveOrdersKey = 'cached_inactive_orders';

  // Getter for the stream
  Stream<List<Order>> get ordersStream => _ordersController.stream;

  List<Order> _activeOrders = [];
  List<Order> _inactiveOrders = [];

  // Update your existing getters to also notify the stream
  List<Order> get activeOrders => _activeOrders;
  List<Order> get inactiveOrders => _inactiveOrders;
  List<Order> get allOrders {
    final orders = [..._activeOrders, ..._inactiveOrders];
    _ordersController.add(orders); // Notify listeners
    return orders;
  }

  /// Load orders from SharedPreferences (for offline use)
  Future<void> loadOrdersFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load active orders
      final activeOrdersJson = prefs.getString(_activeOrdersKey);
      if (activeOrdersJson != null) {
        debugPrint(
            'Loading active orders from cache, JSON length: ${activeOrdersJson.length}');
        final List<dynamic> activeOrdersList = json.decode(activeOrdersJson);
        _activeOrders = activeOrdersList
            .map((orderJson) => Order.fromJson(orderJson))
            .toList();

        // Debug: Check what we loaded
        for (var order in _activeOrders) {
          debugPrint('Loaded order ${order.orderId}:');
          for (var company in order.companies) {
            debugPrint(
                '  Company ${company.companyName}: photos=${company.photos.length}, contacts=${company.contactPeople.length}');
            if (company.photos.isNotEmpty) {
              debugPrint('    Photo URLs: ${company.photos}');
            }
          }
          for (var warehouse in order.warehouses) {
            debugPrint(
                '  Warehouse ${warehouse.warehouseName}: photos=${warehouse.photos.length}, contacts=${warehouse.contactPeople.length}');
            if (warehouse.photos.isNotEmpty) {
              debugPrint('    Photo URLs: ${warehouse.photos}');
            }
          }
        }
      }

      // Load inactive orders
      final inactiveOrdersJson = prefs.getString(_inactiveOrdersKey);
      if (inactiveOrdersJson != null) {
        final List<dynamic> inactiveOrdersList =
            json.decode(inactiveOrdersJson);
        _inactiveOrders = inactiveOrdersList
            .map((orderJson) => Order.fromJson(orderJson))
            .toList();
      }

      // Update globals and notify listeners
      Globals.ordersNumber = _activeOrders.length;
      _ordersController.add([..._activeOrders, ..._inactiveOrders]);

      debugPrint(
          'Loaded ${_activeOrders.length} active and ${_inactiveOrders.length} inactive orders from cache');
    } catch (e) {
      debugPrint('Error loading orders from cache: $e');
    }
  }

  /// Save orders to SharedPreferences
  Future<void> _saveOrdersToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear existing cache
      await prefs.remove(_activeOrdersKey);
      await prefs.remove(_inactiveOrdersKey);

      // Save active orders
      if (_activeOrders.isNotEmpty) {
        // Debug: Check what we're about to save
        for (var order in _activeOrders) {
          debugPrint('Saving order ${order.orderId}:');
          for (var company in order.companies) {
            debugPrint(
                '  Company ${company.companyName}: photos=${company.photos.length}, contacts=${company.contactPeople.length}');
          }
          for (var warehouse in order.warehouses) {
            debugPrint(
                '  Warehouse ${warehouse.warehouseName}: photos=${warehouse.photos.length}, contacts=${warehouse.contactPeople.length}');
          }
        }

        final activeOrdersJson =
            json.encode(_activeOrders.map((order) => order.toJson()).toList());
        await prefs.setString(_activeOrdersKey, activeOrdersJson);
        debugPrint('Active orders JSON length: ${activeOrdersJson.length}');
      }

      // Save inactive orders
      if (_inactiveOrders.isNotEmpty) {
        final inactiveOrdersJson = json
            .encode(_inactiveOrders.map((order) => order.toJson()).toList());
        await prefs.setString(_inactiveOrdersKey, inactiveOrdersJson);
      }

      debugPrint(
          'Saved ${_activeOrders.length} active and ${_inactiveOrders.length} inactive orders to cache');
    } catch (e) {
      debugPrint('Error saving orders to cache: $e');
    }
  }

  /// Clear all cached orders
  Future<void> clearOrdersCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeOrdersKey);
      await prefs.remove(_inactiveOrdersKey);
      debugPrint('Cleared orders cache');
    } catch (e) {
      debugPrint('Error clearing orders cache: $e');
    }
  }

  Future<List<Order>> _processOrderStatus(String status,
      {String? fromDate, String? toDate}) async {
    try {
      // Use 'from' and 'to' as expected by the backend
      final body = {
        'action': 'show-orders-flutter',
        'order-status': status,
        'driver': Globals.userId.toString()
      };

      if (fromDate != null) body['from'] = fromDate;
      if (toDate != null) body['to'] = toDate;

      debugPrint('Sending request with params: $body');

      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      final data = json.decode(response.body);
      debugPrint('Response for $status orders: ${response.body}');

      if (!data['success']) {
        throw Exception(data['message'] ?? 'API request failed');
      }

      if (data['data'] == null || data['data'].isEmpty) {
        debugPrint('No $status orders found - empty data');
        return [];
      }

      // Handle single null order case
      if (data['data'].length == 1) {
        final firstOrder = data['data'][0];
        if (firstOrder['order_number'] == null &&
            (firstOrder['order_details'] == null ||
                json.decode(firstOrder['order_details'])['order_id'] == null)) {
          debugPrint('No $status orders found - null order');
          return [];
        }
      }

      List<Order> orders = [];
      for (var orderJson in data['data']) {
        try {
          // Parse order details
          final orderDetails = orderJson['order_details'] != null
              ? json.decode(orderJson['order_details'])
              : {};

          if (orderDetails['order_id'] == null) continue;

          // Parse related data with proper error handling
          final companies = _safeJsonDecode(orderJson['companies'], '[]');
          final warehouses = _safeJsonDecode(orderJson['warehouses'], '[]');
          final products = _safeJsonDecode(orderJson['products'], '[]');
          final contactPeople = orderJson['contact_people'] != null &&
                  orderJson['contact_people'] != 'null'
              ? _safeJsonDecode(orderJson['contact_people'], '[]')
              : [];
          final collectionUnits = orderJson['collection_units'] != null &&
                  orderJson['collection_units'] != 'null'
              ? _safeJsonDecode(orderJson['collection_units'], '[]')
              : [];

          List<Map<String, dynamic>> enhancedCompanies = [];
          for (var company in companies) {
            try {
              final companyId = company['company_id'] ?? company['id'];
              if (companyId != null) {
                final enhancedCompanyData =
                    await _deliveryService.getPartnerDetails(companyId);

                // Convert contact_people to List<Map<String, String>>
                List<Map<String, String>> contactPeopleConverted = [];
                if (enhancedCompanyData['contact_people'] is List) {
                  contactPeopleConverted =
                      (enhancedCompanyData['contact_people'] as List)
                          .map((contact) => {
                                'name': contact['name']?.toString() ?? '',
                                'telephone':
                                    contact['telephone']?.toString() ?? '',
                              })
                          .toList();
                }

                // Convert photos to base64 strings for offline storage
                List<String> base64Photos = [];
                if (enhancedCompanyData['photos'] is List) {
                  List<String> photoUrls =
                      (enhancedCompanyData['photos'] as List)
                          .map((photo) {
                            String photoPath = photo.toString();
                            // Build full URL
                            if (photoPath.isNotEmpty &&
                                !photoPath.startsWith('http')) {
                              String cleanPath = photoPath.startsWith('/')
                                  ? photoPath.substring(1)
                                  : photoPath;
                              return 'https://vinczefi.com/foodexim/$cleanPath';
                            }
                            return photoPath;
                          })
                          .where((url) => url.isNotEmpty)
                          .toList();

                  // Download and convert to base64
                  for (String photoUrl in photoUrls) {
                    final base64Image = await _downloadImageAsBase64(photoUrl);
                    if (base64Image != null) {
                      base64Photos.add(base64Image);
                    }
                  }
                  debugPrint(
                      'Converted ${base64Photos.length}/${photoUrls.length} company photos to base64');
                }

                // Merge original company data with detailed data
                enhancedCompanies.add({
                  ...company,
                  'details': enhancedCompanyData['details']?.toString() ?? '',
                  'address': enhancedCompanyData['address']?.toString() ?? '',
                  'telephone':
                      enhancedCompanyData['telephone']?.toString() ?? '',
                  'coordinates':
                      enhancedCompanyData['coordinates']?.toString() ?? '',
                  'photos': base64Photos, // Now contains base64 strings
                  'contact_people': contactPeopleConverted,
                });
                debugPrint(
                    'Enhanced company ${company['company_name']} with ${base64Photos.length} base64 photos');
              } else {
                enhancedCompanies.add(company);
              }
            } catch (e) {
              debugPrint('Error loading company details: $e');
              enhancedCompanies.add(company); // Use original data as fallback
            }
          }

          List<Map<String, dynamic>> enhancedWarehouses = [];
          for (var warehouse in warehouses) {
            try {
              final warehouseId = warehouse['warehouse_id'] ?? warehouse['id'];
              if (warehouseId != null) {
                final enhancedWarehouseData =
                    await _deliveryService.getWarehouseDetails(warehouseId);

                // Convert contact_people to List<Map<String, String>>
                List<Map<String, String>> contactPeopleConverted = [];
                if (enhancedWarehouseData['contact_people'] is List) {
                  contactPeopleConverted =
                      (enhancedWarehouseData['contact_people'] as List)
                          .map((contact) => {
                                'name': contact['name']?.toString() ?? '',
                                'telephone':
                                    contact['telephone']?.toString() ?? '',
                              })
                          .toList();
                }

                // Convert photos to base64 strings for offline storage
                List<String> base64Photos = [];
                if (enhancedWarehouseData['photos'] is List) {
                  List<String> photoUrls =
                      (enhancedWarehouseData['photos'] as List)
                          .map((photo) {
                            String photoPath = photo.toString();
                            // Build full URL
                            if (photoPath.isNotEmpty &&
                                !photoPath.startsWith('http')) {
                              String cleanPath = photoPath.startsWith('/')
                                  ? photoPath.substring(1)
                                  : photoPath;
                              return 'https://vinczefi.com/foodexim/$cleanPath';
                            }
                            return photoPath;
                          })
                          .where((url) => url.isNotEmpty)
                          .toList();

                  // Download and convert to base64
                  for (String photoUrl in photoUrls) {
                    final base64Image = await _downloadImageAsBase64(photoUrl);
                    if (base64Image != null) {
                      base64Photos.add(base64Image);
                    }
                  }
                  debugPrint(
                      'Converted ${base64Photos.length}/${photoUrls.length} warehouse photos to base64');
                }

                // Merge original warehouse data with detailed data
                enhancedWarehouses.add({
                  ...warehouse,
                  'telephone':
                      enhancedWarehouseData['telephone']?.toString() ?? '',
                  'coordinates':
                      enhancedWarehouseData['coordinates']?.toString() ?? '',
                  'photos': base64Photos, // Now contains base64 strings
                  'contact_people': contactPeopleConverted,
                });
                debugPrint(
                    'Enhanced warehouse ${warehouse['warehouse_name']} with ${base64Photos.length} base64 photos');
              } else {
                enhancedWarehouses.add(warehouse);
              }
            } catch (e) {
              debugPrint('Error loading warehouse details: $e');
              enhancedWarehouses
                  .add(warehouse); // Use original data as fallback
            }
          }

          final order = Order.fromJson({
            ...orderDetails,
            'companies': enhancedCompanies,
            'warehouses': enhancedWarehouses,
            'products': products,
            'contact_people': contactPeople,
            'collection_units': collectionUnits,
          });

          orders.add(order);
          debugPrint('Successfully processed order ${order.orderId}');
        } catch (e) {
          debugPrint('Error processing order: $e');
          continue;
        }
      }

      debugPrint(
          'Processed ${orders.length} $status orders with enhanced data');
      return orders;
    } catch (e) {
      debugPrint('Error in _processOrderStatus: $e');
      throw e;
    }
  }

  Future<String?> _downloadImageAsBase64(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) return null;

      debugPrint('Downloading image as base64: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        final base64String = base64Encode(response.bodyBytes);
        debugPrint(
            'Image converted to base64, size: ${base64String.length} chars');
        return base64String;
      } else {
        debugPrint('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }

  dynamic _safeJsonDecode(String? jsonString, String defaultValue) {
    if (jsonString == null || jsonString.isEmpty)
      return json.decode(defaultValue);
    try {
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('JSON decode error: $e');
      return json.decode(defaultValue);
    }
  }

  // In OrderService class, modify these methods:

  Future<void> fetchActiveOrders({String? fromDate, String? toDate}) async {
    try {
      _activeOrders = await _processOrderStatus('active',
          fromDate: fromDate, toDate: toDate);
      Globals.ordersNumber = _activeOrders.length;
      _debugPrintOrderInfo(_activeOrders, 'active');

      // Save to cache after successful fetch
      await _saveOrdersToCache();
    } catch (e) {
      debugPrint('Error fetching active orders, loading from cache: $e');
      // If network fails, try to load from cache
      await loadOrdersFromCache();
      // Remove the rethrow; - let it continue with cached data
    }
  }

  Future<void> fetchInactiveOrders({String? fromDate, String? toDate}) async {
    try {
      _inactiveOrders = await _processOrderStatus('inactive',
          fromDate: fromDate, toDate: toDate);
      _debugPrintOrderInfo(_inactiveOrders, 'inactive');

      // Save to cache after successful fetch
      await _saveOrdersToCache();
    } catch (e) {
      debugPrint('Error fetching inactive orders, loading from cache: $e');
      // If network fails, try to load from cache
      await loadOrdersFromCache();
      // Remove the rethrow; - let it continue with cached data
    }
  }

  Future<void> fetchAllOrders({String? fromDate, String? toDate}) async {
    try {
      // DON'T clear cache here - only clear after successful API call

      final results = await Future.wait([
        _processOrderStatus('active', fromDate: fromDate, toDate: toDate),
        _processOrderStatus('inactive', fromDate: fromDate, toDate: toDate)
      ]);

      // API call succeeded, now we can clear old cache and save new data
      await clearOrdersCache();

      _activeOrders = results[0];
      _inactiveOrders = results[1];

      // Save to cache after successful fetch
      await _saveOrdersToCache();

      // Notify stream listeners of the update
      _ordersController.add([..._activeOrders, ..._inactiveOrders]);
    } catch (e) {
      debugPrint('Error fetching all orders, loading from cache: $e');
      // Cache was NOT cleared, so we can still load from it
      await loadOrdersFromCache();

      // Still notify stream listeners even with cached data
      _ordersController.add([..._activeOrders, ..._inactiveOrders]);
    }
  }

  void _debugPrintOrderInfo(List<Order> orders, String type) {
    debugPrint('Total $type orders: ${orders.length}');
    for (var order in orders) {
      debugPrint('$type Order ID: ${order.orderId}, '
          'Total Product Quantity: ${order.getTotalOrderedQuantity()}');
      for (var contact in order.contactPeople) {
        debugPrint('Contact for $type order ${order.orderId}: '
            'Name: ${contact.name}, Tel: ${contact.telephone}, Type: ${contact.type}');
      }
    }
  }

  /// Fetches a specific order by its ID from the backend.
  /// Returns the order if found, or null if not.
  Future<Order?> getOrderById(int orderId) async {
    try {
      final body = {
        'action': 'show-orders-flutter-id',
        'order_id': orderId.toString(),
        'driver': Globals.userId.toString(),
      };

      debugPrint('Fetching order with ID: $orderId, request: $body');

      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      final data = json.decode(response.body);
      debugPrint('Response for order ID $orderId: ${response.body}');

      if (!data['success'] || data['data'] == null || data['data'].isEmpty) {
        debugPrint('Failed to fetch order: ${data['message']}');
        return null;
      }

      final orderJson = data['data'][0];
      final orderDetails = orderJson['order_details'] != null
          ? json.decode(orderJson['order_details'])
          : {};

      if (orderDetails['order_id'] == null) {
        debugPrint('Order details are invalid for ID $orderId');
        return null;
      }

      final companies = _safeJsonDecode(orderJson['companies'], '[]');
      final warehouses = _safeJsonDecode(orderJson['warehouses'], '[]');
      final products = _safeJsonDecode(orderJson['products'], '[]');
      final contactPeople = orderJson['contact_people'] != null &&
              orderJson['contact_people'] != 'null'
          ? _safeJsonDecode(orderJson['contact_people'], '[]')
          : [];
      final collectionUnits = orderJson['collection_units'] != null &&
              orderJson['collection_units'] != 'null'
          ? _safeJsonDecode(orderJson['collection_units'], '[]')
          : [];

      // Handle existsPhoto field only in getOrderById
      final existsPhoto = orderJson['existsPhoto'] ?? false;

      final order = Order.fromJson({
        ...orderDetails,
        'existsPhoto': existsPhoto,
        'companies': companies,
        'warehouses': warehouses,
        'products': products,
        'contact_people': contactPeople,
        'collection_units': collectionUnits,
      });

      debugPrint(
          'Fetched order: ${order.orderId}, has photo: ${order.existsPhotos}');
      return order;
    } catch (e) {
      debugPrint('Error in getOrderById: $e');

      // If network fails, try to find the order in cached data
      final cachedOrder = [..._activeOrders, ..._inactiveOrders]
          .where((order) => order.orderId == orderId)
          .firstOrNull;

      if (cachedOrder != null) {
        debugPrint('Found order $orderId in cache');
        return cachedOrder;
      }

      return null;
    }
  }

  Future<int?> checkVehicleLogin() async {
    try {
      final body = {
        'action': 'get-vehicle-id-simple',
        'driver': Globals.userId.toString()
      };

      debugPrint("Getting vehicle ID for driver: ${Globals.userId}");

      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('Response: ${response.body}');
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final vehicleId = data['data']['vehicle_id'];

          if (vehicleId != null) {
            int? parsedVehicleId;

            if (vehicleId is String) {
              parsedVehicleId = int.tryParse(vehicleId);
            } else if (vehicleId is int) {
              parsedVehicleId = vehicleId;
            }

            if (parsedVehicleId != null) {
              Globals.vehicleID = parsedVehicleId;
              //Globals.vehicleName = data['data']['vehicle_name'];

              debugPrint('Vehicle ID: $parsedVehicleId');
              return parsedVehicleId;
            }
          }

          debugPrint('No vehicle ID in response');
          return null;
        }

        debugPrint('Request failed: ${data['message']}');
        return null;
      }

      debugPrint('HTTP Error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error getting vehicle ID: $e');
      return null;
    }
  }

  bool isOrderDelivered(Order order) {
    return order.delivered != '0000-00-00 00:00:00';
  }

  void dispose() {
    _ordersController.close();
  }
}

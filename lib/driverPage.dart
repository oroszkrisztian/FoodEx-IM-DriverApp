import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodex/ConnectionErrorPage.dart';
import 'package:foodex/ServerUpdate.dart';
import 'package:foodex/deliveryInfo.dart';
import 'package:foodex/expense_log_page.dart';
import 'package:foodex/loginPage.dart';
import 'package:foodex/logoutPage.dart';
import 'package:foodex/main.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/user.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/myLogs.dart';
import 'package:foodex/services/delivery_service.dart';
import 'package:foodex/services/order_services.dart';
import 'package:foodex/services/shorebird_service.dart';
import 'package:foodex/services/user_service.dart';
import 'package:foodex/shiftsPage.dart';
import 'package:foodex/shorebirdUpdateScreen.dart';
import 'package:foodex/vehicleData.dart';
import 'package:foodex/vehicleExpensePage.dart';
import 'package:foodex/widgets/shared_indicators.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'globals.dart';

final defaultPickupWarehouse = Warehouse(
  warehouseName: 'Unknown Pickup Warehouse',
  warehouseAddress: 'N/A',
  warehouseLocation: 'N/A',
  type: 'pickup',
  coordinates: 'N/A',
  id: 0,
);

final defaultCompany = Company(
  companyName: 'Unknown',
  type: 'unknown',
  id: 0,
);

final defaultContactPerson = ContactPerson(
  name: 'Unknown',
  telephone: 'Unknown',
  type: 'unknown',
);

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  StreamSubscription? _ordersSubscription;
  Timer? _connectionTimer;
  bool _isLoggedIn = false;
  bool _vehicleLoggedIn = false;
  bool hasOrders = false;
  bool _isLoading = true;

  User? _user;

  final OrderService _orderService = OrderService();
  final deliveryService = DeliveryService();
  final userService = UserService(baseUrl: 'https://vinczefi.com');
  String? errorMessage;
  bool _hasConnection = true;
  bool _connectionCheckedDuringInit = false;
  bool _hasUserAndVehicleData = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
    _initializeData();
    _setupOrdersListener();
    _startConnectionMonitoring();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _connectionTimer?.cancel();
    super.dispose();
  }

  void _startConnectionMonitoring() {
    _connectionTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        final hasConnection = await _hasInternetConnection();

        final connectionRestored = !_hasConnection && hasConnection;

        if (_hasConnection != hasConnection) {
          setState(() {
            _hasConnection = hasConnection;
          });
        }

        if (connectionRestored) {
          debugPrint('Connection restored - automatically loading orders');

          setState(() {
            _isLoading = true;
          });

          await Future.delayed(const Duration(milliseconds: 500));

          await fetchInitialOrders();
        }
      }
    });
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _setupOrdersListener() {
    _ordersSubscription = _orderService.ordersStream.listen((orders) {
      setState(() {
        hasOrders = orders.isNotEmpty;
      });
    });
  }

  Future<void> _loadSavedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String savedLanguage = prefs.getString('language') ?? 'en';
    setState(() {
      Globals.currentLanguage = savedLanguage;
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      await _checkLoginStatus();
      await _syncVehicleStatus();

      print(Globals.vehicleID);
      print(Globals.userId);
      print(Globals.vehicleName);

      _hasUserAndVehicleData = _isLoggedIn &&
          _vehicleLoggedIn &&
          Globals.userId != null &&
          Globals.vehicleID != null;

      final hasConnection = await _hasInternetConnection();
      setState(() {
        _hasConnection = hasConnection;
        _connectionCheckedDuringInit = true;
      });

      if (!hasConnection) {
        setState(() {
          _isLoading = false;
          errorMessage = 'No internet connection';
        });

        if (!_hasUserAndVehicleData) {
          return;
        }
      }

      if (hasConnection && Globals.userId != null) {
        try {
          final user = await userService.loadUser(Globals.userId!);
          setState(() {
            _user = user;
          });
        } catch (e) {
          if (e.toString().contains('Failed host lookup') ||
              e.toString().contains('No address associated with hostname') ||
              e.toString().contains('SocketException')) {
            setState(() {
              _hasConnection = false;
              errorMessage = 'Connection error while loading user data';
            });
          } else {
            debugPrint('Error loading user: $e');
          }
        }
      }

      if (_isLoggedIn && _vehicleLoggedIn && _hasConnection) {
        await fetchInitialOrders();
      }
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('SocketException')) {
        setState(() {
          _hasConnection = false;
          errorMessage = 'Connection error during initialization';
        });
      } else {
        debugPrint('Error in initialization: $e');
        setState(() {
          errorMessage = 'Error initializing: ${e.toString()}';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchInitialOrders() async {
    final hasConnection = await _hasInternetConnection();
    if (!hasConnection) {
      setState(() {
        _isLoading = false;
        _hasConnection = false;
        errorMessage = 'No internet connection available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = null;
      _hasConnection = true;
    });

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime pastDate = DateTime(today.year, today.month, today.day, 0, 1);
    String formattedPastDate = DateFormat('yyyy-MM-dd').format(pastDate);

    try {
      debugPrint(
          "Fetching orders for today: $formattedPastDate - $formattedPastDate");
      await _orderService.fetchAllOrders(
          fromDate: formattedPastDate, toDate: formattedPastDate);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('SocketException')) {
        setState(() {
          _isLoading = false;
          _hasConnection = false;
          errorMessage = 'Failed to load orders - Connection error';
        });
      } else {
        setState(() {
          _isLoading = false;
          hasOrders = false;
          errorMessage = 'No orders found for today.';
        });
      }
    }
  }

  Future<void> _syncVehicleStatus() async {
    if (Globals.vehicleID != null) {
      setState(() {
        _vehicleLoggedIn = true;
      });
      return;
    }

    try {
      final vehicleId = await userService.checkVehicleLogin();
      setState(() {
        _vehicleLoggedIn = vehicleId != null;
      });
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('SocketException')) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedVehicleId = prefs.getInt('selected_vehicle_id');

          if (savedVehicleId != null) {
            Globals.vehicleID = savedVehicleId;
            debugPrint(
                'Using saved vehicle ID from SharedPreferences: $savedVehicleId');
            setState(() {
              _vehicleLoggedIn = true;
            });
          } else {
            debugPrint('No saved vehicle ID found and no connection');
            setState(() {
              _vehicleLoggedIn = false;
            });
          }
        } catch (prefsError) {
          debugPrint('Error accessing SharedPreferences: $prefsError');
          setState(() {
            _vehicleLoggedIn = false;
          });
        }
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedVehicleId = prefs.getInt('selected_vehicle_id');

          if (savedVehicleId != null) {
            Globals.vehicleID = savedVehicleId;
            debugPrint(
                'Using saved vehicle ID from SharedPreferences: $savedVehicleId');
            setState(() {
              _vehicleLoggedIn = true;
            });
          } else {
            debugPrint('No saved vehicle ID found');
            setState(() {
              _vehicleLoggedIn = false;
            });
          }
        } catch (prefsError) {
          debugPrint('Error accessing SharedPreferences: $prefsError');
          setState(() {
            _vehicleLoggedIn = false;
          });
        }
      }
    }
  }

  Future<void> _refreshOrderData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final hasConnection = await _hasInternetConnection();
      setState(() {
        _hasConnection = hasConnection;
      });

      if (!hasConnection) {
        setState(() {
          _isLoading = false;
          errorMessage = 'No internet connection available';
        });
        return;
      }

      await fetchInitialOrders();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logoutUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      _isLoggedIn = false;
      _vehicleLoggedIn = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MyHomePage(),
      ),
    );
  }

  Future<void> _checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      // Read as string since you save it as string in login
      String? userIdString = prefs.getString('userId');
      if (userIdString != null) {
        Globals.userId = int.tryParse(userIdString);
      }

      setState(() {
        _isLoggedIn = isLoggedIn && Globals.userId != null;
      });
    } catch (e) {
      debugPrint('Error checking login status: $e');
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  Widget _buildBody() {
    final themeColor = const Color.fromARGB(255, 1, 160, 226);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    int? vehicleId = Globals.vehicleID;
    final orders = _orderService.activeOrders;

    Widget buildDateRange() {
      final now = DateTime.now();
      return Column(
        children: [
          Text(
            DateFormat('yyyy-MM-dd').format(now),
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE').format(now),
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: themeColor,
          strokeWidth: 3,
        ),
      );
    }

    if (!_hasConnection) {
      return Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off,
                      color: Colors.red,
                      size: isSmallScreen ? 40 : 48,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      Globals.getText('noInternetConnection'),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              ElevatedButton.icon(
                onPressed: _refreshOrderData,
                icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
                label: Text(
                  Globals.getText('retryConnection'),
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 24,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If no vehicle logged in, show centered vehicle login prompt
    if (vehicleId == null) {
      return Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_filled_outlined,
                      color: themeColor,
                      size: isSmallScreen ? 40 : 48,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      '${Globals.getText('pleaseLoginVehicle')}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()));
                },
                icon: Icon(Icons.login, size: isSmallScreen ? 20 : 24),
                label: Text(
                  '${Globals.getText('loginVehicleButton')}',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 24,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If no orders but has connection and vehicle, show centered no orders message
    if (!hasOrders && _hasConnection) {
      return Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: themeColor,
                      size: isSmallScreen ? 40 : 48,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    buildDateRange(),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      'No orders found for today',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              ElevatedButton.icon(
                onPressed: _refreshOrderData,
                icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
                label: Text(
                  'Check Again',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 24,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If has orders, show the orders list
    return Column(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderService.activeOrders.length,
            itemBuilder: (context, index) {
              final order = _orderService.activeOrders[index];
              final pickupWarehouse = order.warehouses.firstWhere(
                  (wh) => wh.type == 'pickup',
                  orElse: () => defaultPickupWarehouse);
              final deliverWarehouse = order.warehouses.firstWhere(
                  (wh) => wh.type == 'delivery',
                  orElse: () => defaultPickupWarehouse);
              final pickupCompany = order.companies.firstWhere(
                  (comp) => comp.type == 'pickup',
                  orElse: () => defaultCompany);
              final deliveryCompany = order.companies.firstWhere(
                  (comp) => comp.type == 'delivery',
                  orElse: () => defaultCompany);
              final pickupContact = order.contactPeople.firstWhere(
                  (cp) => cp.type == 'pickup',
                  orElse: () => defaultContactPerson);
              final deliveryContact = order.contactPeople.firstWhere(
                  (cp) => cp.type == 'delivery',
                  orElse: () => defaultContactPerson);

              return GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                DeliveryInfo(orderId: order.orderId)),
                      ),
                  child: Stack(
                    children: [
                      Card(
                        color: order.pickedUp == '0000-00-00 00:00:00'
                            ? const Color.fromARGB(255, 255, 189, 189)
                            : Color.fromARGB(255, 166, 250, 118),
                        elevation: 2.0,
                        margin: EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: isSmallScreen ? 2.0 : 8.0,
                        ),
                        shape: RoundedRectangleBorder(
                          side:
                              const BorderSide(color: Colors.black, width: 1.0),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 6.0 : 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${Globals.getText('partner')}: ',
                                      style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold)),
                                  Text(pickupCompany.companyName,
                                      style: const TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              // Pickup Info
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(pickupCompany.companyName,
                                            style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                        Text(
                                            '${Globals.getText(DateFormat('E').format(DateTime.parse(order.pickupTime)))} ${DateFormat('dd.MM').format(DateTime.parse(order.pickupTime))},  ${DateFormat('HH:mm').format(DateTime.parse(order.pickupTime))}',
                                            style: const TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: Text(
                                                '${Globals.getText('address')}: ${pickupWarehouse.warehouseName} (${pickupWarehouse.warehouseAddress})',
                                                style: const TextStyle(
                                                    fontSize: 12.0))),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SharedIndicators.buildIcon(
                                                Icons.note_rounded,
                                                order.upNotes.isNotEmpty
                                                    ? Colors.green
                                                    : Colors.red),
                                            const SizedBox(width: 4.0),
                                            SharedIndicators.buildContactStatus(
                                              name: pickupContact.name,
                                              telephone:
                                                  pickupContact.telephone,
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              // Delivery Info
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(deliveryCompany.companyName,
                                            style: const TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                        Text(
                                            '${Globals.getText(DateFormat('E').format(DateTime.parse(order.deliveryTime)))} ${DateFormat('dd.MM').format(DateTime.parse(order.deliveryTime))},  ${DateFormat('HH:mm').format(DateTime.parse(order.deliveryTime))}',
                                            style: const TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: Text(
                                                '${Globals.getText('address')}:${deliverWarehouse.warehouseName} (${deliverWarehouse.warehouseAddress})',
                                                style: const TextStyle(
                                                    fontSize: 12.0))),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SharedIndicators.buildIcon(
                                                Icons.note_rounded,
                                                order.downNotes.isNotEmpty
                                                    ? Colors.green
                                                    : Colors.red),
                                            const SizedBox(width: 4.0),
                                            SharedIndicators.buildContactStatus(
                                              name: deliveryContact.name,
                                              telephone:
                                                  deliveryContact.telephone,
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              // Bottom indicators
                              Wrap(
                                spacing: 6.0,
                                runSpacing: 4.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          '${order.getTotalOrderedQuantity()} kg',
                                          style: const TextStyle(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.bold)),
                                      Wrap(
                                        spacing: isSmallScreen ? 8 : 10,
                                        children: [
                                          SharedIndicators
                                              .buildDocumentIndicator(
                                                  'UIT', order.uit.isNotEmpty),
                                          SharedIndicators
                                              .buildDocumentIndicator(
                                                  'EKR', order.ekr.isNotEmpty),
                                          SharedIndicators.buildDocumentIndicator(
                                              '${Globals.getText('orderInvoice')}',
                                              order.invoice.isNotEmpty),
                                          SharedIndicators
                                              .buildDocumentIndicator(
                                                  'CMR', order.cmr.isNotEmpty),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Status Arrow
                      Positioned(
                        top: 0,
                        right: isSmallScreen ? 4.0 : 8.0,
                        child: order.pickedUp == '0000-00-00 00:00:00'
                            ? Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.red,
                                size: isSmallScreen ? 48 : 54,
                              )
                            : order.delivered == '0000-00-00 00:00:00'
                                ? Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.green,
                                    size: isSmallScreen ? 48 : 54,
                                  )
                                : Container(),
                      ),
                    ],
                  ));
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Globals.getText('driverPage'),
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _hasConnection ? Icons.wifi : Icons.wifi_off,
                color: _hasConnection ? Colors.green : Colors.red,
                size: 28,
                key: ValueKey(_hasConnection),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Globals.vehicleID != null
                ? (Globals.vehicleName?.contains('Iroda') == true
                    ? const Icon(
                        Icons.business,
                        color: Colors.green,
                        size: 28,
                      )
                    : const Icon(
                        Icons.local_shipping,
                        color: Colors.green,
                        size: 28,
                      ))
                : const Icon(
                    Icons.local_shipping,
                    color: Colors.red,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 20),
          if (_vehicleLoggedIn)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: GestureDetector(
                onTap: _refreshOrderData,
                child: const Icon(
                  Icons.refresh,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          const SizedBox(width: 30),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: _buildDrawer(),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                      padding: const EdgeInsets.all(8.0),
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: _buildBody()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final vehcileId = Globals.vehicleID;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 1, 160, 226),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  if (_user != null)
                    Text(
                      _user!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (Globals.vehicleID != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Globals.vehicleName?.contains('Iroda') == true
                              ? Icons.business
                              : Icons.local_shipping,
                          color: Colors.white,
                          size: 50,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          Globals.vehicleName ?? 'Unknown Vehicle',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        )
                      ],
                    )
                  ]
                ],
              ),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.list, color: Color.fromARGB(255, 1, 160, 226)),
            title: Text(Globals.getText('myLogs')),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyLogPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.directions_car,
                color: Color.fromARGB(255, 1, 160, 226)),
            title: Text(Globals.getText("myCar")),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const VehicleDataPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money,
                color: Color.fromARGB(255, 1, 160, 226)),
            title: Text(Globals.vehicleID == null
                ? "${Globals.getText('expense')} - ${Globals.getText('myLogs')}"
                : Globals.getText('expense')),
            onTap: () {
              Navigator.pop(context);
              if (Globals.vehicleID == null) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ExpenseLogPage()),
                );
              } else {
                _showExpenseDialog();
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.punch_clock_rounded,
                color: Color.fromARGB(255, 1, 160, 226)),
            title: Text(Globals.getText('shifts')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ShiftsPage()),
              );
            },
          ),
          const Divider(),
          FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              int? vehicleId = Globals.vehicleID;
              String label = vehicleId != null
                  ? Globals.getText('logoutVehicle')
                  : Globals.getText('loginVehicle');
              IconData icon = vehicleId != null ? Icons.logout : Icons.login;
              return ListTile(
                leading:
                    Icon(icon, color: const Color.fromARGB(255, 1, 160, 226)),
                title: Text(label),
                onTap: () {
                  Navigator.pop(context);
                  if (vehicleId != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LogoutPage()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  }
                },
              );
            },
          ),

          if (vehcileId == null) ...[
            FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                int? userId = Globals.userId;
                String label =
                    userId != null ? 'Logout Account' : 'Login Account';
                IconData icon =
                    userId != null ? Icons.person_off : Icons.person;

                return ListTile(
                  leading:
                      Icon(icon, color: const Color.fromARGB(255, 1, 160, 226)),
                  title: Text(label),
                  onTap: () {
                    _logoutUser();
                  },
                );
              },
            ),
          ],
          const Divider(),

          ListTile(
            leading: const Icon(Icons.system_update,
                color: Color.fromARGB(255, 1, 160, 226)),
            title: Text(
                Globals.getText('checkServerUpdate') ?? 'Check Server Update'),
            onTap: () {
              Navigator.pop(context);
              Globals.isUpdateDialogShowing = true;
              showDialog(
                context: context,
                builder: (BuildContext context) => const ServerUpdateDialog(),
              );
            },
          ),
          const Spacer(),
          //const Divider(),
          // Language Selection SectionG
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLanguageButton('en'),
                    _buildLanguageButton('hu'),
                    _buildLanguageButton('ro'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            alignment: Alignment.center,
            child: Text(
              'Version 1.3.12',
              style: TextStyle(
                color: Colors.black,
                fontSize: isSmallScreen ? 16.0 : 20.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String languageCode) {
    // Flag emojis are created by combining regional indicator symbols
    // Each country code consists of two letters that get converted to regional indicators
    final Map<String, String> flagEmojis = {
      'en': '🇬🇧', // UK flag for English
      'hu': '🇭🇺', // Hungarian flag
      'ro': '🇷🇴', // Romanian flag
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () async {
          // Save selected language to SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('language', languageCode);

          // Update current language in Globals
          setState(() {
            Globals.currentLanguage = languageCode;
          });

          debugPrint('Language changed to: $languageCode');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Globals.currentLanguage == languageCode
              ? const Color.fromARGB(255, 1, 160, 226)
              : Colors.grey[300],
          padding: const EdgeInsets.all(12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: Globals.currentLanguage == languageCode
                  ? const Color.fromARGB(255, 1, 160, 226)
                  : Colors.transparent,
              width: 2.0,
            ),
          ),
          minimumSize:
              const Size(48, 48), // Makes buttons square and consistent size
        ),
        child: Text(
          flagEmojis[languageCode] ??
              '🏳️', // Default to white flag if language code not found
          style: const TextStyle(
            fontSize: 24.0, // Make flags larger
          ),
        ),
      ),
    );
  }

  void _showExpenseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'submit_expense',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const VehicleExpensePage()),
                  );
                },
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    Text(
                      '${Globals.getText('submit')}',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                heroTag: 'expense_log',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ExpenseLogPage()),
                  );
                },
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list, color: Colors.white),
                    Text(
                      '${Globals.getText('logs')}',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

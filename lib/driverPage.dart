import 'dart:async';
import 'package:flutter/material.dart';
import 'package:foodex/deliveryInfo.dart';
import 'package:foodex/expense_log_page.dart';
import 'package:foodex/loginPage.dart';
import 'package:foodex/logoutPage.dart';
import 'package:foodex/main.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/myLogs.dart';
import 'package:foodex/services/delivery_service.dart';
import 'package:foodex/services/order_services.dart';
import 'package:foodex/shiftsPage.dart';
import 'package:foodex/vehicleData.dart';
import 'package:foodex/vehicleExpensePage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';

final defaultPickupWarehouse = Warehouse(
  warehouseName: 'Unknown Pickup Warehouse',
  warehouseAddress: 'N/A',
  type: 'pickup',
  coordinates: 'N/A',
);

final defaultCompany = Company(
  companyName: 'Unknown',
  type: 'unknown',
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
  bool _isLoggedIn = false;
  bool _vehicleLoggedIn = false;
  bool hasOrders = false;
  bool _isLoading = false;

  final OrderService _orderService = OrderService();
  final deliveryService = DeliveryService();
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      await _checkLoginStatus();
      await _syncVehicleStatus();
      if (_isLoggedIn) {
        await fetchInitialOrders();
      }
    } catch (e) {
      debugPrint('Error in initialization: $e');
      setState(() {
        errorMessage = 'Error initializing: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      final vehicleId = await _orderService.checkVehicleLogin();
      setState(() {
        _vehicleLoggedIn = vehicleId != null;
      });
    } catch (e) {
      setState(() {
        _vehicleLoggedIn = false;
      });
    }
  }

  Future<void> fetchInitialOrders() async {
    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime pastDate = DateTime(today.year, today.month, today.day, 0, 1);
    String formattedPastDate = DateFormat('yyyy-MM-dd').format(pastDate);

    try {
      await _orderService.fetchActiveOrders(
          fromDate: formattedPastDate, toDate: formattedPastDate);

      setState(() {
        hasOrders = _orderService.activeOrders.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        hasOrders = false;
        errorMessage = 'No orders found for today.';
      });
    }
  }

  Future<void> _refreshOrderData() async {
    try {
      // Show loading state if needed
      setState(() {
        _isLoading = true;
      });

      // Refresh orders
      await fetchInitialOrders();

      // Update loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any errors during refresh
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Page', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        actions: [
          if (_vehicleLoggedIn) // Add refresh button when vehicle is logged in
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshOrderData,
              tooltip: 'Refresh Orders',
            ),
        ],
        iconTheme:
            const IconThemeData(color: Colors.white), // For hamburger icon
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                child: Column(
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (!_isLoggedIn)
                      const Center(child: Text('Please log in.'))
                    else if (!_vehicleLoggedIn)
                      const Center(child: Text('Please log in a vehicle.'))
                    else if (errorMessage != null)
                      Center(child: Text(errorMessage!))
                    else if (hasOrders)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _orderService.activeOrders.length,
                        itemBuilder: (context, index) {
                          final order = _orderService.activeOrders[index];
                          final pickupWarehouse = order.warehouses.firstWhere(
                              (wh) => wh.type == 'pickup',
                              orElse: () => defaultPickupWarehouse);
                          final deliveryWarehouse = order.warehouses.firstWhere(
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
                          final deliveryContact = order.contactPeople
                              .firstWhere((cp) => cp.type == 'delivery',
                                  orElse: () => defaultContactPerson);

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DeliveryInfo(orderId: order.orderId),
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                Card(
                                  elevation: 4.0,
                                  margin: EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: isSmallScreen ? 4.0 : 16.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                        color: Colors.black, width: 1.5),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                        isSmallScreen ? 8.0 : 16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Partner name at the top
                                        Row(
                                          children: [
                                            const Text(
                                              'Partner: ',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              pickupCompany.companyName,
                                              style: const TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12.0),
                                        // Pickup Info
                                        Container(
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border:
                                                Border.all(color: Colors.blue),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    pickupCompany.companyName,
                                                    style: const TextStyle(
                                                      fontSize: 18.0,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                            'MM-dd (E) HH:mm')
                                                        .format(DateTime.parse(
                                                            order.pickupTime)),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8.0),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                        'Address: ${pickupWarehouse.warehouseAddress}'),
                                                  ),
                                                  const SizedBox(width: 8.0),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (order.upNotes
                                                          .isNotEmpty) ...[
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.amber
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                            border: Border.all(
                                                              color:
                                                                  Colors.amber,
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            Icons.note_rounded,
                                                            size: isSmallScreen
                                                                ? 16
                                                                : 18,
                                                            color: Colors
                                                                .amber.shade700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8.0),
                                                      ],
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: (pickupContact
                                                                      .name
                                                                      .isNotEmpty &&
                                                                  pickupContact
                                                                          .name !=
                                                                      "N/A" &&
                                                                  pickupContact
                                                                      .telephone
                                                                      .isNotEmpty &&
                                                                  pickupContact
                                                                          .telephone !=
                                                                      "N/A")
                                                              ? Colors.green
                                                                  .withOpacity(
                                                                      0.1)
                                                              : Colors.red
                                                                  .withOpacity(
                                                                      0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12.0),
                                                          border: Border.all(
                                                            color: (pickupContact
                                                                        .name
                                                                        .isNotEmpty &&
                                                                    pickupContact
                                                                            .name !=
                                                                        "N/A" &&
                                                                    pickupContact
                                                                        .telephone
                                                                        .isNotEmpty &&
                                                                    pickupContact
                                                                            .telephone !=
                                                                        "N/A")
                                                                ? Colors.green
                                                                : Colors.red,
                                                            width: 1.0,
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.person_rounded,
                                                          size: isSmallScreen
                                                              ? 16
                                                              : 18,
                                                          color: (pickupContact
                                                                      .name
                                                                      .isNotEmpty &&
                                                                  pickupContact
                                                                          .name !=
                                                                      "N/A" &&
                                                                  pickupContact
                                                                      .telephone
                                                                      .isNotEmpty &&
                                                                  pickupContact
                                                                          .telephone !=
                                                                      "N/A")
                                                              ? Colors.green
                                                                  .shade700
                                                              : Colors
                                                                  .red.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        // Delivery Info
                                        Container(
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            border:
                                                Border.all(color: Colors.green),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    deliveryCompany.companyName,
                                                    style: const TextStyle(
                                                      fontSize: 18.0,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                            'MM-dd (E) HH:mm')
                                                        .format(DateTime.parse(
                                                            order
                                                                .deliveryTime)),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8.0),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                        'Address: ${deliveryWarehouse.warehouseAddress}'),
                                                  ),
                                                  const SizedBox(width: 8.0),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (order.downNotes
                                                          .isNotEmpty) ...[
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.amber
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.0),
                                                            border: Border.all(
                                                              color:
                                                                  Colors.amber,
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            Icons.note_rounded,
                                                            size: isSmallScreen
                                                                ? 16
                                                                : 18,
                                                            color: Colors
                                                                .amber.shade700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8.0),
                                                      ],
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: (deliveryContact
                                                                      .name
                                                                      .isNotEmpty &&
                                                                  deliveryContact
                                                                          .name !=
                                                                      "N/A" &&
                                                                  deliveryContact
                                                                      .telephone
                                                                      .isNotEmpty &&
                                                                  deliveryContact
                                                                          .telephone !=
                                                                      "N/A")
                                                              ? Colors.green
                                                                  .withOpacity(
                                                                      0.1)
                                                              : Colors.red
                                                                  .withOpacity(
                                                                      0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12.0),
                                                          border: Border.all(
                                                            color: (deliveryContact
                                                                        .name
                                                                        .isNotEmpty &&
                                                                    deliveryContact
                                                                            .name !=
                                                                        "N/A" &&
                                                                    deliveryContact
                                                                        .telephone
                                                                        .isNotEmpty &&
                                                                    deliveryContact
                                                                            .telephone !=
                                                                        "N/A")
                                                                ? Colors.green
                                                                : Colors.red,
                                                            width: 1.0,
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.person_rounded,
                                                          size: isSmallScreen
                                                              ? 16
                                                              : 18,
                                                          color: (deliveryContact
                                                                      .name
                                                                      .isNotEmpty &&
                                                                  deliveryContact
                                                                          .name !=
                                                                      "N/A" &&
                                                                  deliveryContact
                                                                      .telephone
                                                                      .isNotEmpty &&
                                                                  deliveryContact
                                                                          .telephone !=
                                                                      "N/A")
                                                              ? Colors.green
                                                                  .shade700
                                                              : Colors
                                                                  .red.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        // Quantity and Document Indicators
                                        Wrap(
                                          spacing: 10.0,
                                          runSpacing: 8.0,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            
                                            Text(
                                              'Quantity: ${order.getTotalWeight()} kg',
                                              style: const TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: order.uit.isNotEmpty
                                                    ? Colors.green
                                                    : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'UIT',
                                                style: TextStyle(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: order.ekr.isNotEmpty
                                                    ? Colors.green
                                                    : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'EKR',
                                                style: TextStyle(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: order.invoice.isNotEmpty
                                                    ? Colors.green
                                                    : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Invoice',
                                                style: TextStyle(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: order.cmr.isNotEmpty
                                                    ? Colors.green
                                                    : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'CMR',
                                                style: TextStyle(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Status Arrow
                                Positioned(
                                  top: 2.0,
                                  right: isSmallScreen ? 8.0 : 16.0,
                                  child: order.pickedUp == '0000-00-00 00:00:00'
                                      ? Icon(
                                          Icons.keyboard_arrow_up,
                                          color: Colors.green,
                                          size: isSmallScreen ? 56 : 62,
                                        )
                                      : order.delivered == '0000-00-00 00:00:00'
                                          ? Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.red,
                                              size: isSmallScreen ? 56 : 62,
                                            )
                                          : Container(),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      const Center(
                          child: Text('No orders available for today.')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
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
                children: const [
                  Icon(
                    Icons.local_shipping,
                    color: Colors.white,
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Driver Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.list, color: Color.fromARGB(255, 1, 160, 226)),
            title: const Text('My Logs'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyLogPage()),
              );
            },
          ),
          if (_vehicleLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.directions_car,
                  color: Color.fromARGB(255, 1, 160, 226)),
              title: const Text('My Car'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VehicleDataPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money,
                  color: Color.fromARGB(255, 1, 160, 226)),
              title: const Text('Expense'),
              onTap: () {
                Navigator.pop(context);
                _showExpenseDialog();
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.punch_clock_rounded,
                color: Color.fromARGB(255, 1, 160, 226)),
            title: const Text('Shifts'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
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
              String label =
                  vehicleId != null ? 'Logout Vehicle' : 'Login Vehicle';
              IconData icon = vehicleId != null ? Icons.logout : Icons.login;

              return ListTile(
                leading:
                    Icon(icon, color: const Color.fromARGB(255, 1, 160, 226)),
                title: Text(label),
                onTap: () {
                  Navigator.pop(context);
                  if (vehicleId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LogoutPage()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  }
                },
              );
            },
          ),
          const Divider(),
          if (!_vehicleLoggedIn) ...[
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
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyHomePage(),
                      ),
                    );
                  },
                );
              },
            ),
          ],
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
      String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon, color: const Color.fromARGB(255, 1, 160, 226)),
            onPressed: onPressed,
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: Color.fromARGB(255, 1, 160, 226)),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleActionButton() {
    return SizedBox(
      width: 90,
      child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          int? vehicleId = Globals.vehicleID;
          String label = vehicleId != null ? 'Logout Vehicle' : 'Login Vehicle';
          IconData icon = vehicleId != null ? Icons.logout : Icons.login;
          VoidCallback onPressed = () async {
            if (vehicleId != null) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const LogoutPage()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const LoginPage()));
            }
          };
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(icon, color: const Color.fromARGB(255, 1, 160, 226)),
                onPressed: onPressed,
              ),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10, color: Color.fromARGB(255, 1, 160, 226)),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const VehicleExpensePage()),
                  );
                },
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    Text(
                      'Submit',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                heroTag: 'expense_log',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ExpenseLogPage()),
                  );
                },
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list, color: Colors.white),
                    Text(
                      'Logs',
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

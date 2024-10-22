import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/order.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/services/delivery_service.dart';
import 'package:foodex/services/order_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'globals.dart';
import 'loginPage.dart';
import 'main.dart';
import 'logoutPage.dart';
import 'package:http/http.dart' as http;
import 'myLogs.dart';
import 'vehicleData.dart';
import 'my_routes_page.dart';
import 'vehicleExpensePage.dart';
import 'expense_log_page.dart';

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

class _DriverPageState extends State<DriverPage> with TickerProviderStateMixin {
  bool _isLoggedIn = false;
  bool _vehicleLoggedIn = false;
  bool hasOrders = false;

  //orders
  final OrderService _orderService = OrderService();
  final deliveryService = DeliveryService();

  bool isLoading = true;
  //DateTime? _fromDate;
  //DateTime? _toDate;
  bool isFiltered = false;
  String? errorMessage;
  List<String> buttonLabels = []; // List to track button labels for each order
  List<bool> isButtonVisible =
      []; // List to track button visibility for each order

  //animation
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isExpanded = false;

  // Track expanded state and animation controllers for each card
  List<bool> expandedStates = [];
  List<AnimationController> animationControllers = [];
  List<Animation<double>> animations = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    fetchInitialOrders();
  }

  void prepareAnimation() {
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void initializeAnimations() {
    // Clear existing controllers and animations
    for (var controller in animationControllers) {
      controller.dispose();
    }
    animationControllers.clear();
    animations.clear();
    expandedStates.clear();

    // Create new controllers and animations for each card
    for (var _ in _orderService.orders) {
      final controller = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      );

      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.fastOutSlowIn,
      );

      animationControllers.add(controller);
      animations.add(animation);
      expandedStates.add(false);
    }
  }

  void toggleCard(int index) {
    setState(() {
      expandedStates[index] = !expandedStates[index];
      if (expandedStates[index]) {
        animationControllers[index].forward();
      } else {
        animationControllers[index].reverse();
      }
    });
  }

  Future<void> fetchInitialOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime pastDate = today.subtract(const Duration(days: 360));
    DateTime futureDate = DateTime(now.year, now.month, now.day + 1, 23, 59);

    try {
      await _orderService.fetchOrders(fromDate: pastDate, toDate: futureDate);

      setState(() {
        hasOrders = _orderService.orders.isNotEmpty;
        if (hasOrders) {
          buttonLabels =
              List.generate(_orderService.orders.length, (_) => 'Pick Up');
          isButtonVisible =
              List.generate(_orderService.orders.length, (_) => true);
          initializeAnimations();
        } else {
          errorMessage = 'No orders found for today.';
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching initial orders: $e');
      setState(() {
        isLoading = false;
        hasOrders = false;
        errorMessage = 'No orders found for today.';
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    int? vehicleId = Globals.vehicleID;

    setState(() {
      _isLoggedIn = isLoggedIn;
      _vehicleLoggedIn = vehicleId != null;
    });
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

  String getButtonLabel(Order order) {
    if (order.pickedUp == '0000-00-00 00:00:00') {
      return 'Pick Up'; // Not picked up yet
    } else if (order.delivered == '0000-00-00 00:00:00') {
      return 'Deliver'; // Picked up but not delivered
    } else {
      return 'Completed'; // Delivered
    }
  }

  Future<void> handleButtonPress(int orderId, int index) async {
    // Get the order from the order service
    Order order =
        _orderService.orders.firstWhere((order) => order.orderId == orderId);

    // Show confirmation dialog
    bool confirmed = await _showConfirmationDialog(
        order.pickedUp == '0000-00-00 00:00:00'
            ? 'Are you sure you want to pick up this order?'
            : 'Are you sure you want to deliver this order?');

    if (confirmed) {
      if (order.pickedUp == '0000-00-00 00:00:00') {
        print('Order ID for pickup: $orderId');
        await deliveryService.pickUpOrder(
            orderId); // Call your delivery service
        setState(() {
          order.pickedUp =
              DateTime.now().toString(); // Update the order's pickedUp status
        });
        _showSnackBar(context,
            'Order picked up successfully'); // Show SnackBar after confirmation
      } else if (order.delivered == '0000-00-00 00:00:00') {
        print('Order ID for delivery: $orderId');
        await deliveryService.deliverOrder(
            orderId); // Call your delivery service
        setState(() {
          order.delivered =
              DateTime.now().toString(); // Update the order's delivered status
        });
        await fetchInitialOrders(); // Fetch orders again after delivery
        _showSnackBar(context,
            'Order delivered successfully'); // Show SnackBar after confirmation
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
  final snackBar = SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 3), // Duration for which the SnackBar is shown
    behavior: SnackBarBehavior.floating, // Optional: makes it float above other content
    backgroundColor: Colors.green, // Customize the background color
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}


// Show confirmation dialog
  Future<bool> _showConfirmationDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Action'),
          content: Text(message),
          actions: <Widget>[
            // Cancel button with red background and rounded edges
            Container(
              decoration: BoxDecoration(
                color: Colors.red, // Red background
                borderRadius: BorderRadius.circular(15.0), // Rounded edges
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // User canceled
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white), // White text
                ),
              ),
            ),
            // Confirm button with green background and rounded edges
            Container(
              decoration: BoxDecoration(
                color: Colors.green, // Green background
                borderRadius: BorderRadius.circular(15.0), // Rounded edges
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // User confirmed
                },
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white), // White text
                ),
              ),
            ),
          ],
        );
      },
    ).then((value) => value ?? false); // Ensure a default return value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Page', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        actions: _vehicleLoggedIn
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logoutUser,
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom:
                        80), // Add padding to prevent content from being hidden behind buttons
                child: Column(
                  children: [
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (!_isLoggedIn)
                      const Center(child: Text('Please log in.'))
                    else if (!_vehicleLoggedIn)
                      const Center(child: Text('Please log in a vehicle.'))
                    else if (errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else if (hasOrders)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _orderService.orders.length,
                        itemBuilder: (context, index) {
                          final order = _orderService.orders[index];
                          final comanda = order.orderId;

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
                              toggleCard(index);
                              print(index);
                            },
                            child: Card(
                              elevation: 4.0,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 10.0),
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(
                                    color: Colors.black, width: 1.5),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Partner Name Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Partner:',
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
                                    const SizedBox(
                                        height:
                                            12.0), // Space between Partner and Pickup details

                                    // Pickup Details Container
                                    Container(
                                      padding: const EdgeInsets.all(10.0),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(color: Colors.blue),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Pickup Details',
                                                style: TextStyle(
                                                  fontSize: 18.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time,
                                                      size: 16,
                                                      color: Colors.grey),
                                                  const SizedBox(width: 5.0),
                                                  Text(
                                                    order.pickupTime,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8.0),
                                          Wrap(
                                            children: [
                                              // Non-clickable label
                                              const Text(
                                                'Warehouse address: ',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                              // Clickable address
                                              GestureDetector(
                                                onTap: () async {
                                                  print(Globals.vehicleID);
                                                  // Use coordinates if available, otherwise fall back to the warehouse address
                                                  final String address =
                                                      pickupWarehouse
                                                                  .coordinates
                                                                  ?.isNotEmpty ==
                                                              true
                                                          ? pickupWarehouse
                                                              .coordinates!
                                                          : pickupWarehouse
                                                              .warehouseAddress;

                                                  final Uri launchUri = Uri(
                                                    scheme: 'geo',
                                                    path: '0,0',
                                                    queryParameters: {
                                                      'q': address
                                                    },
                                                  );

                                                  try {
                                                    await launchUrl(launchUri);
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Could not open Google Maps.')),
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  pickupWarehouse
                                                      .warehouseAddress,
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          Text(
                                            'Company: ${pickupCompany.companyName}',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),

                                          // Hardcoded Notes Field for Pickup
                                          const SizedBox(height: 10.0),
                                          Text(
                                            'Notes: ${order.upNotes}.',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),

                                          // Hardcoded Contact Person Field for Pickup
                                          const SizedBox(height: 10.0),
                                          Text(
                                            'Contact Person: ${pickupContact.name}',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          GestureDetector(
                                            onTap: (pickupContact
                                                        .telephone.isNotEmpty &&
                                                    pickupContact
                                                            .telephone.length >
                                                        10)
                                                ? () async {
                                                    final String phoneNumber =
                                                        pickupContact.telephone;
                                                    print(phoneNumber);

                                                    final Uri launchUri = Uri(
                                                      scheme: 'tel',
                                                      path: phoneNumber,
                                                    );

                                                    try {
                                                      await launchUrl(
                                                          launchUri);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                'Could not launch dialer.')),
                                                      );
                                                    }
                                                  }
                                                : null, // If no phone number, onTap is null and GestureDetector is disabled
                                            child: Text(
                                              'Phone: ${pickupContact.telephone.isNotEmpty ? pickupContact.telephone : 'Not Available'}',
                                              style: TextStyle(
                                                color: (pickupContact.telephone
                                                            .isNotEmpty &&
                                                        pickupContact.telephone
                                                                .length >
                                                            10)
                                                    ? Colors.blue
                                                    : Colors
                                                        .grey, // Grey to indicate non-clickable
                                                decoration: (pickupContact
                                                            .telephone
                                                            .isNotEmpty &&
                                                        pickupContact.telephone
                                                                .length >
                                                            10)
                                                    ? TextDecoration.underline
                                                    : TextDecoration
                                                        .none, // Remove underline when not clickable
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(
                                        height:
                                            12.0), // Space between containers

                                    SizeTransition(
                                      sizeFactor: animations[index],
                                      axis: Axis.vertical,
                                      child: Column(
                                        children: [
                                          if (isButtonVisible[index])
                                            Center(
                                                child: ElevatedButton(
                                              onPressed: () =>
                                                  handleButtonPress(
                                                      order.orderId, index),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10),
                                              ),
                                              child: Text(
                                                getButtonLabel(
                                                    order), // Use the dynamic label based on order status
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.white),
                                              ),
                                            )),

                                          const SizedBox(height: 12.0),

                                          // Products Table
                                          const Text(
                                            'Products:',
                                            style: TextStyle(
                                                fontSize: 18.0,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8.0),
                                          Table(
                                            border: TableBorder.all(),
                                            columnWidths: const {
                                              0: FlexColumnWidth(
                                                  3), // Product Name
                                              1: FlexColumnWidth(1), // Price
                                              2: FlexColumnWidth(1), // Quantity
                                            },
                                            children: [
                                              const TableRow(
                                                decoration: BoxDecoration(
                                                    color: Colors.grey),
                                                children: [
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('Product Name',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('Quantity',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('Price (RON)',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                ],
                                              ),
                                              // Add a row for each product
                                              ...order.products.map((product) {
                                                double price =
                                                    product.quantity *
                                                        product.price;
                                                return TableRow(
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Text(
                                                          product.productName),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Text(
                                                          '${product.quantity} kg'),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Text(
                                                          '\ ${price.toStringAsFixed(2)}'),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12.0),

                                    // Delivery Details Container

                                    Container(
                                      padding: const EdgeInsets.all(10.0),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Delivery Details',
                                                style: TextStyle(
                                                  fontSize: 18.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time,
                                                      size: 16,
                                                      color: Colors.grey),
                                                  const SizedBox(width: 5.0),
                                                  Text(
                                                    order.deliveryTime,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8.0),
                                          Wrap(
                                            children: [
                                              // Non-clickable label
                                              const Text(
                                                'Warehouse address: ',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                              // Clickable address
                                              GestureDetector(
                                                onTap: () async {
                                                  // Use coordinates if available, otherwise fall back to the warehouse address
                                                  final String address =
                                                      deliveryWarehouse
                                                                  .coordinates
                                                                  ?.isNotEmpty ==
                                                              true
                                                          ? deliveryWarehouse
                                                              .coordinates!
                                                          : deliveryWarehouse
                                                              .warehouseAddress;

                                                  final Uri launchUri = Uri(
                                                    scheme: 'geo',
                                                    path: '0,0',
                                                    queryParameters: {
                                                      'q': address
                                                    },
                                                  );

                                                  try {
                                                    await launchUrl(launchUri);
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Could not open Google Maps.')),
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  deliveryWarehouse
                                                      .warehouseAddress,
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          Text(
                                            'Company: ${deliveryCompany.companyName}',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),

                                          // Hardcoded Notes Field for Delivery
                                          const SizedBox(height: 10.0),
                                          Text(
                                            'Notes: ${order.downNotes}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),

                                          // Hardcoded Contact Person Field for Delivery
                                          const SizedBox(height: 10.0),
                                          Text(
                                            'Contact Person: ${deliveryContact.name}',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: (deliveryContact
                                                        .telephone.isNotEmpty &&
                                                    deliveryContact
                                                            .telephone.length >
                                                        10)
                                                ? () async {
                                                    final String phoneNumber =
                                                        deliveryContact
                                                            .telephone;
                                                    print(phoneNumber);

                                                    final Uri launchUri = Uri(
                                                      scheme: 'tel',
                                                      path: phoneNumber,
                                                    );

                                                    try {
                                                      await launchUrl(
                                                          launchUri);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                'Could not launch dialer.')),
                                                      );
                                                    }
                                                  }
                                                : null, // If no phone number, onTap is null and GestureDetector is disabled
                                            child: Text(
                                              'Phone: ${deliveryContact.telephone.isNotEmpty ? deliveryContact.telephone : 'Not Available'}',
                                              style: TextStyle(
                                                color: (deliveryContact
                                                            .telephone
                                                            .isNotEmpty &&
                                                        deliveryContact
                                                                .telephone
                                                                .length >
                                                            10)
                                                    ? Colors.blue
                                                    : Colors
                                                        .grey, // Grey to indicate non-clickable
                                                decoration: (deliveryContact
                                                            .telephone
                                                            .isNotEmpty &&
                                                        deliveryContact
                                                                .telephone
                                                                .length >
                                                            10)
                                                    ? TextDecoration.underline
                                                    : TextDecoration
                                                        .none, // Remove underline when not clickable
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 12.0), // Space before Quantity

                                    // Quantity Field
                                    Text(
                                      'Quantity: ${order.getTotalQuantity()} kg',
                                      style: const TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBottomButton('MyLogs', Icons.list, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const MyLogPage()));
            }),
            if (_vehicleLoggedIn)
              _buildBottomButton('MyCar', Icons.directions_car, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const VehicleDataPage()));
              }),
            if (_vehicleLoggedIn)
              _buildBottomButton(
                  'Expense', Icons.attach_money, _showExpenseDialog),
            _buildBottomButton('MyRoutes', Icons.map, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyRoutesPage()));
            }),
            _buildVehicleActionButton(),
          ],
        ),
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
}

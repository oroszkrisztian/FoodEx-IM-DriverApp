import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/order.dart';
import 'package:foodex/models/product.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/services/delivery_service.dart';
import 'package:foodex/services/order_services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
import 'shiftsPage.dart';

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
  bool _isLoading = false;

  final TextEditingController _amountController = TextEditingController();

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
  bool isExpanded = false;

  // Track expanded state and animation controllers for each card
  List<bool> expandedStates = [];
  List<AnimationController> animationControllers = [];
  List<Animation<double>> animations = [];

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
      await _syncVehicleStatus(); // New method to sync vehicle status
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

  void ShowEkr(BuildContext context, String uitEkr) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12), // Rounded corners for the dialog
          ),
          title: const Text(
            'EKR Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize
                .min, // Ensures dialog doesn't take up too much space
            children: [
              Text(
                'EKR Number:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700], // Subtle text color
                ),
              ),
              const SizedBox(height: 10),
              Text(
                uitEkr,
                style: const TextStyle(
                  fontSize: 32, // Larger font for better visibility
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue, // Blue OK button
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void ShowInvoiceCmr(BuildContext context, String relativePdfUrl) async {
    try {
      // Define the base URL for your server
      String baseUrl = 'https://vinczefi.com/foodexim/';

      // Combine the base URL with the relative path to build the full URL
      String fullUrl = baseUrl + relativePdfUrl;

      // Encode the full URL to handle special characters like spaces and accents
      final encodedUrl = Uri.encodeFull(fullUrl);
      print('Full PDF URL: $fullUrl');
      print('Encoded PDF URL: $encodedUrl');

      // Download the PDF file from the server
      final response = await http.get(Uri.parse(encodedUrl));

      if (response.statusCode == 200) {
        // Save the PDF file to the local file system (temporary directory)
        final file =
            File('${(await getTemporaryDirectory()).path}/invoice.pdf');
        await file.writeAsBytes(response.bodyBytes);

        // Show the PDF view in a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Invoice Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: PDFView(
                  filePath: file.path, // Path to the local file
                  enableSwipe: true, // Allow swipe to navigate pages
                  swipeHorizontal: true, // Horizontal swipe for page navigation
                  autoSpacing: true, // Automatically adjust spacing
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        print('Failed to load PDF: ${response.statusCode}');
        // Handle the error (e.g., show a message to the user)
      }
    } catch (e) {
      print('Error loading PDF from URL: $e');
      // Handle the error (e.g., display an error message to the user)
    }
  }

  void prepareAnimation() {}

  // New method to sync vehicle status
  Future<void> _syncVehicleStatus() async {
    // First check if we already have a vehicle ID in globals
    if (Globals.vehicleID != null) {
      setState(() {
        _vehicleLoggedIn = true;
        debugPrint('Vehicle already logged in with ID: ${Globals.vehicleID}');
      });
      return;
    }

    // If no vehicle ID in globals, check with server
    try {
      final vehicleId = await _orderService.checkVehicleLogin();
      setState(() {
        _vehicleLoggedIn = vehicleId != null;
        if (_vehicleLoggedIn) {
          debugPrint(
              'Successfully synced vehicle status. Vehicle ID: $vehicleId');
        } else {
          debugPrint('No vehicle currently logged in');
        }
      });
    } catch (e) {
      debugPrint('Error syncing vehicle status: $e');
      setState(() {
        _vehicleLoggedIn = false;
      });
    }
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget buildContainersTables(List<Product> products) {
    final palletteTable = buildProductsTable(products, 'palette');
    final crateTable = buildProductsTable(products, 'crate');

    final hasPalettes = palletteTable.children.length > 1;
    final hasCrates = crateTable.children.length > 1;

    if (!hasPalettes && !hasCrates) {
      return const SizedBox.shrink();
    }

    // Get container products
    final containerProducts = products
        .where((p) => p.productType == 'palette' || p.productType == 'crate')
        .toList();

    // Create aggregation maps using int for quantity
    final Map<String, int> quantityMap = {};
    final Map<String, double> priceMap = {};
    final Map<String, Product> firstOccurrence = {};

    // Aggregate quantities and keep track of first product instance for other details
    for (var product in containerProducts) {
      if (quantityMap.containsKey(product.productName)) {
        quantityMap[product.productName] =
            (quantityMap[product.productName] ?? 0) + product.quantity;
      } else {
        quantityMap[product.productName] = product.quantity;
        firstOccurrence[product.productName] = product;
        priceMap[product.productName] = product.price;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Containers:',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Table(
            border: TableBorder.all(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                ),
                children: [
                  _buildHeaderCell('Container Name'),
                  _buildHeaderCell('Quantity'),
                  _buildHeaderCell('Price (RON)'),
                ],
              ),
              ...firstOccurrence.entries.map((entry) {
                final productName = entry.key;
                final product = entry.value;
                final quantity = quantityMap[productName] ?? 0;
                final totalPrice = quantity * (priceMap[productName] ?? 0);

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(productName),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('$quantity pieces'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${totalPrice.toStringAsFixed(2)} RON'),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

// Keep the original buildProductsTable for compatibility with existing checks
  Table buildProductsTable(List<Product> products, String type) {
    final filteredProducts =
        products.where((product) => product.productType == type).toList();

    if (filteredProducts.isEmpty) {
      return Table(
        children: const [
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No containers info available',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey[300],
          ),
          children: [
            _buildHeaderCell('Container Name'),
            _buildHeaderCell('Quantity'),
            _buildHeaderCell('Price (RON)'),
          ],
        ),
        ...filteredProducts.map((product) {
          final totalPrice = product.quantity * product.price;
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(product.productName),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('${product.quantity} kg'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('${totalPrice.toStringAsFixed(2)} RON'),
              ),
            ],
          );
        }).toList(),
      ],
    );
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

    // Past date as today at 00:01
    DateTime pastDate = DateTime(today.year, today.month, today.day, 0, 1);

    // Future date as 30 days from now
    DateTime futureDate = now.add(const Duration(days: 30));

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
    //int? vehicleId = Globals.vehicleID;

    setState(() {
      _isLoggedIn = isLoggedIn;
      // _vehicleLoggedIn = vehicleId != null;
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
    Order order =
        _orderService.orders.firstWhere((order) => order.orderId == orderId);

    bool confirmed = await _showConfirmationDialog(
        order.pickedUp == '0000-00-00 00:00:00'
            ? 'Are you sure you want to pick up this order?'
            : 'Are you sure you want to deliver this order?');

    if (confirmed) {
      try {
        Map<String, dynamic>? options = await _showOptionDialog(
          order.products,
          order.uitEkr,
          order.invoice,
          order.cmr,
          orderId,
        );

        if (options == null) {
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Only process updates if there are actually changes
        if (options.isNotEmpty) {
          try {
            await deliveryService.handleOrderUpdates(orderId, options);
            await _refreshOrderData();
            order =
                _orderService.orders.firstWhere((o) => o.orderId == orderId);
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(); // Remove loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Error updating order details: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        // Handle pickup or delivery
        if (order.pickedUp == '0000-00-00 00:00:00') {
          await deliveryService.pickUpOrder(orderId);
          await _refreshOrderData();
          if (mounted) {
            Navigator.of(context).pop(); // Remove loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order picked up successfully')),
            );
          }
        } else if (order.delivered == '0000-00-00 00:00:00') {
          await deliveryService.deliverOrder(orderId);
          await _refreshOrderData();
          if (mounted) {
            Navigator.of(context).pop(); // Remove loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order delivered successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Remove loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

// Function to show the dialog with checkboxes and dropdowns for 'Pallet' and 'Case'

  Future<Map<String, dynamic>?> _showOptionDialog(List<Product> products,
      String? uitEkr, String? invoice, String? cmr, int orderId) async {
    final imagePicker = ImagePicker();

    // Initialize state variables
    bool isPalletChecked = false;
    bool isCaseChecked = false;
    String? palletSubOption;
    String? caseSubOption;
    int palletAmount = 0;
    int caseAmount = 0;

    final uitEkrController = TextEditingController(text: uitEkr);
    File? invoiceImage;
    File? cmrImage;

    // Check for existing values
    bool hasUitEkr = uitEkr?.isNotEmpty ?? false;
    bool hasInvoice = invoice?.isNotEmpty ?? false;
    bool hasCmr = cmr?.isNotEmpty ?? false;
    bool hasPaletteProducts =
        products.any((product) => product.productType == 'palette');
    bool hasCrateProducts =
        products.any((product) => product.productType == 'crate');

    Future<File?> pickImage() async {
      try {
        final pickedFile = await imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        return pickedFile != null ? File(pickedFile.path) : null;
      } catch (e) {
        print('Error picking image: $e');
        return null;
      }
    }

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 600, maxHeight: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Order Details',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Documentation Section
                            _buildSectionHeader(
                              context,
                              'Required Documents',
                              Icons.description,
                              hasSubtitle: true,
                              subtitle:
                                  'Please provide the necessary documentation',
                            ),
                            const SizedBox(height: 16),

                            // UitEkr Input Card
                            _buildDocumentCard(
                              context,
                              'UitEkr Reference',
                              'Enter the reference number',
                              Icons.numbers,
                              hasValue: hasUitEkr,
                              child: !hasUitEkr
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: TextField(
                                        controller: uitEkrController,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.grey[100],
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          hintText:
                                              'Enter UitEkr reference number',
                                          prefixIcon: const Icon(Icons.tag),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Document Upload Section
                            Row(
                              children: [
                                Expanded(
                                  child: _buildUploadCard(
                                    context,
                                    'Invoice',
                                    Icons.receipt,
                                    invoiceImage,
                                    () async {
                                      final image = await pickImage();
                                      if (image != null) {
                                        setState(() => invoiceImage = image);
                                      }
                                    },
                                    hasExisting: hasInvoice,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildUploadCard(
                                    context,
                                    'CMR',
                                    Icons.article,
                                    cmrImage,
                                    () async {
                                      final image = await pickImage();
                                      if (image != null) {
                                        setState(() => cmrImage = image);
                                      }
                                    },
                                    hasExisting: hasCmr,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Containers Section
                            _buildSectionHeader(
                              context,
                              'Container Information',
                              Icons.inventory_2,
                              hasSubtitle: true,
                              subtitle:
                                  'Specify the containers used for transport',
                            ),
                            const SizedBox(height: 16),

                            // Container Options
                            _buildContainerCard(
                              context,
                              'Pallet Management',
                              isPalletChecked,
                              palletSubOption,
                              palletAmount,
                              ['Plastic', 'Lemn'],
                              (checked) {
                                setState(() {
                                  isPalletChecked = checked ?? false;
                                  if (!checked!) {
                                    palletSubOption = null;
                                    palletAmount = 0;
                                  }
                                });
                              },
                              (value) =>
                                  setState(() => palletSubOption = value),
                              (value) => setState(() => palletAmount = value),
                              hasExisting: hasPaletteProducts,
                              icon: Icons.palette,
                            ),

                            const SizedBox(height: 16),

                            _buildContainerCard(
                              context,
                              'Crate Management',
                              isCaseChecked,
                              caseSubOption,
                              caseAmount,
                              ['E2', 'M10'],
                              (checked) {
                                setState(() {
                                  isCaseChecked = checked ?? false;
                                  if (!checked!) {
                                    caseSubOption = null;
                                    caseAmount = 0;
                                  }
                                });
                              },
                              (value) => setState(() => caseSubOption = value),
                              (value) => setState(() => caseAmount = value),
                              hasExisting: hasCrateProducts,
                              icon: Icons.category,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final result = <String, dynamic>{};

                              if (uitEkrController.text.trim().isNotEmpty &&
                                  uitEkrController.text.trim() != uitEkr) {
                                result['UitEkr'] = uitEkrController.text.trim();
                              }

                              if (invoiceImage != null) {
                                result['Invoice'] = invoiceImage!.path;
                              }

                              if (cmrImage != null) {
                                result['CMR'] = cmrImage!.path;
                              }

                              Map<String, dynamic> containers = {};

                              if (isPalletChecked &&
                                  palletSubOption != null &&
                                  palletAmount > 0) {
                                containers['Pallet'] = {
                                  'type': palletSubOption,
                                  'amount': palletAmount,
                                };
                              }

                              if (isCaseChecked &&
                                  caseSubOption != null &&
                                  caseAmount > 0) {
                                containers['Case'] = {
                                  'type': caseSubOption,
                                  'amount': caseAmount,
                                };
                              }

                              if (containers.isNotEmpty) {
                                result['Containers'] = containers;
                              }

                              Navigator.of(context).pop(result);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    bool hasSubtitle = false,
    String subtitle = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (hasSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    String title,
    String description,
    IconData icon, {
    bool hasValue = false,
    Widget? child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (hasValue) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                ],
              ],
            ),
            if (!hasValue && description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(
    BuildContext context,
    String title,
    IconData icon,
    File? selectedFile,
    VoidCallback onUpload, {
    bool hasExisting = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (hasExisting && selectedFile == null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                ],
              ],
            ),
            if (!hasExisting) ...[
              const SizedBox(height: 12),
              if (selectedFile != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.file_present, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedFile.path.split('/').last,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: Icon(
                  selectedFile != null ? Icons.refresh : Icons.upload,
                  size: 20,
                ),
                label: Text(
                  selectedFile != null
                      ? 'Change File'
                      : hasExisting
                          ? 'Update File'
                          : 'Upload File',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// Helper widget for container cards
// Helper widget for container cards
  Widget _buildContainerCard(
    BuildContext context,
    String title,
    bool isChecked,
    String? selectedOption,
    int amount,
    List<String> options,
    Function(bool?) onCheckChanged,
    Function(String?) onOptionChanged,
    Function(int) onAmountChanged, {
    bool hasExisting = false,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with switch
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasExisting && !isChecked) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(Added)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Switch(
                  value: isChecked,
                  onChanged: onCheckChanged,
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            if (isChecked) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type dropdown
                    Text(
                      'Container Type',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedOption,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      items: options.map((String option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: onOptionChanged,
                      hint: const Text('Select type'),
                    ),
                    const SizedBox(height: 16),
                    // Amount input
                    Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              initialValue: amount > 0 ? amount.toString() : '',
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                hintText: 'Enter amount',
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  onAmountChanged(int.parse(value));
                                } else {
                                  onAmountChanged(0);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Text(
                              'units',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// Show confirmation dialog
  Future<bool> _showConfirmationDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon at the top
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    size: 32,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Confirm Action',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel Button
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Confirm Button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Page', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        actions: [
          if (_vehicleLoggedIn) // Add refresh button when vehicle is logged in
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshOrderData,
              tooltip: 'Refresh Orders',
            ),
          if (!_vehicleLoggedIn) // Show logout button when vehicle is not logged in
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
                              color: order.pickedUp != '0000-00-00 00:00:00' &&
                                      order.delivered == '0000-00-00 00:00:00'
                                  ? Colors.green[200]
                                  : Colors.white,
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
                                            style: const TextStyle(
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
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(4.0),
                                            ),
                                            child: Table(
                                              border: TableBorder.all(),
                                              columnWidths: const {
                                                0: FlexColumnWidth(
                                                    3), // Product Name
                                                1: FlexColumnWidth(
                                                    1), // Quantity
                                                2: FlexColumnWidth(
                                                    1), // Price (RON)
                                              },
                                              children: [
                                                const TableRow(
                                                  decoration: BoxDecoration(
                                                      color: Colors.grey),
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(8.0),
                                                      child: Text(
                                                          'Product Name',
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
                                                ...order.products
                                                    .where((product) =>
                                                        product.productType ==
                                                        'product')
                                                    .map((product) {
                                                  double totalPrice =
                                                      product.quantity *
                                                          product.price;
                                                  return TableRow(
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors
                                                          .white, // Ensure each row has white background
                                                    ),
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Text(product
                                                            .productName),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Text(
                                                            '${product.quantity * product.productWeight} kg'),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Text(
                                                            '${totalPrice.toStringAsFixed(2)} RON'),
                                                      ),
                                                    ],
                                                  );
                                                }).toList()
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12.0),
                                          if (buildProductsTable(
                                                      order.products, 'palette')
                                                  .children
                                                  .isNotEmpty ||
                                              buildProductsTable(
                                                      order.products, 'crate')
                                                  .children
                                                  .isNotEmpty)
                                            buildContainersTables(
                                                order.products),

                                          const SizedBox(height: 12.0),
                                        ],
                                      ),
                                    ),
                                    // Quantity Field
                                    Row(
                                      children: [
                                        Text(
                                          'Quantity: ${order.getTotalWeight()} kg',
                                          style: const TextStyle(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                                10), // Adds spacing for clarity
                                        GestureDetector(
                                          onTap: order.uitEkr.isNotEmpty
                                              ? () {
                                                  // Handle tap for EKR
                                                  ShowEkr(
                                                      context, order.uitEkr);
                                                }
                                              : null, // Disable tap if not green
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: order.uitEkr.isNotEmpty
                                                  ? Colors.green
                                                  : Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8), // Rounded rectangle
                                            ),
                                            child: const Text(
                                              'EKR',
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Colors.white, // Text color
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                                10), // Space between containers
                                        GestureDetector(
                                          onTap: order.invoice.isNotEmpty
                                              ? () {
                                                  // Handle tap for Invoice
                                                  ShowInvoiceCmr(
                                                      context, order.invoice);
                                                }
                                              : null, // Disable tap if not green
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: order.invoice.isNotEmpty
                                                  ? Colors.green
                                                  : Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8), // Rounded rectangle
                                            ),
                                            child: const Text(
                                              'Invoice',
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Colors.white, // Text color
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                                10), // Space between containers
                                        GestureDetector(
                                          onTap: order.cmr.isNotEmpty
                                              ? () {
                                                  ShowInvoiceCmr(
                                                      context, order.cmr);
                                                }
                                              : null, // Disable tap if not green
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: order.cmr.isNotEmpty
                                                  ? Colors.green
                                                  : Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8), // Rounded rectangle
                                            ),
                                            child: const Text(
                                              'CMR',
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Colors.white, // Text color
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
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
            _buildBottomButton('Shifts', Icons.punch_clock_rounded, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ShiftsPage()));
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

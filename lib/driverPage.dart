import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/order.dart';
import 'package:foodex/models/product.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/services/delivery_service.dart';
import 'package:foodex/services/order_services.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isLoading = false;

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

  Table buildProductsTable(List<Product> products, String type) {
    // Filter products to include only those with the specified type
    var filteredProducts =
        products.where((product) => product.productType == type).toList();

    // Check if the filtered list is empty
    if (filteredProducts.isEmpty) {
      return Table(
        children: const [
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No containers info available',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ],
      );
    }

    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FlexColumnWidth(3), // Product Name
        1: FlexColumnWidth(1), // Quantity
        2: FlexColumnWidth(1), // Price (RON)
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Colors.grey),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                type == 'product' ? 'Product Name' : 'Container Name',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: const Text(
                'Quantity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Price (RON)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // Build table rows for each filtered product
        ...filteredProducts.map((product) {
          double totalPrice = product.quantity * product.price;
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
      try {
        // Retrieve the list of products from the order
        List<Product> products = order.products;
        String? uitEkr = order.uitEkr;
        String? invoice = order.invoice;
        String? cmr = order.cmr;

        // Check if any updates are needed
        bool needsUitEkr = uitEkr?.isEmpty ?? true;
        bool needsInvoice = invoice?.isEmpty ?? true;
        bool needsCmr = cmr?.isEmpty ?? true;
        bool hasContainerProducts =
            products.any((product) => product.productType == 'container');
        bool needsContainer = !hasContainerProducts &&
            !products.any((product) =>
                product.productType == 'pallet' ||
                product.productType == 'crate');

        bool needsUpdates =
            needsUitEkr || needsInvoice || needsCmr || needsContainer;

        // Only show the options dialog if updates are needed
        Map<String, dynamic>? options;
        if (needsUpdates) {
          options = await _showOptionDialog(
            products,
            uitEkr,
            invoice,
            cmr,
            orderId,
          );

          // If dialog was cancelled (null returned), return early
          if (options == null) {
            return;
          }
        }

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // If there are updates to be made, handle them first
        if (options != null && options.isNotEmpty) {
          await deliveryService.handleOrderUpdates(orderId, options);
        }

        // Handle pickup or delivery
        if (order.pickedUp == '0000-00-00 00:00:00') {
          await deliveryService.pickUpOrder(orderId);
          // Refresh data after pickup
          await _refreshOrderData();
          if (mounted) {
            Navigator.of(context).pop(); // Remove loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order picked up successfully')),
            );
          }
        } else if (order.delivered == '0000-00-00 00:00:00') {
          await deliveryService.deliverOrder(orderId);
          // Refresh data after delivery
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
    // Initialize state variables only if needed
    final imagePicker = ImagePicker();

    // Only initialize if container info is needed
    bool isPalletChecked = false;
    bool isCaseChecked = false;
    String? palletSubOption;
    String? caseSubOption;
    int palletAmount = 0;
    int caseAmount = 0;

    // Only initialize controllers for missing data
    final uitEkrController = TextEditingController(text: uitEkr);
    File? invoiceImage;
    File? cmrImage;

    // Determine what needs to be shown based on empty values
    bool needsUitEkr = uitEkr?.isEmpty ?? true;
    bool needsInvoice = invoice?.isEmpty ?? true;
    bool needsCmr = cmr?.isEmpty ?? true;
    bool hasContainerProducts =
        products.any((product) => product.productType == 'container');
    bool needsContainer = !hasContainerProducts &&
        !products.any((product) =>
            product.productType == 'pallet' || product.productType == 'crate');

    // If nothing needs to be updated, return null immediately

    bool needsUpdates =
        needsUitEkr || needsInvoice || needsCmr || needsContainer;

    // Removed the early return for no updates needed
    // The dialog will now always show, allowing the user to proceed

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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                              needsUpdates
                                  ? Icons.inventory_2
                                  : Icons.check_circle,
                              color: Theme.of(context).colorScheme.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            needsUpdates
                                ? 'Required Information'
                                : 'Order Ready',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Only show documents section if any document is needed
                            if (needsUitEkr || needsInvoice || needsCmr) ...[
                              _buildSectionHeader(
                                context,
                                'Required Documents',
                                Icons.description,
                              ),
                              const SizedBox(height: 16),

                              // UitEkr Input (only if needed)
                              if (needsUitEkr)
                                Card(
                                  elevation: 0,
                                  color: Theme.of(context).colorScheme.surface,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'UitEkr Reference',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: uitEkrController,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withOpacity(0.1),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide.none,
                                            ),
                                            hintText:
                                                'Enter UitEkr reference number',
                                            prefixIcon:
                                                const Icon(Icons.numbers),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Document Upload Cards (only if needed)
                              Row(
                                children: [
                                  if (needsInvoice)
                                    Expanded(
                                      child: _buildDocumentUploadCard(
                                        context,
                                        'Invoice',
                                        invoiceImage,
                                        () async {
                                          final image = await pickImage();
                                          if (image != null) {
                                            setState(
                                                () => invoiceImage = image);
                                          }
                                        },
                                      ),
                                    ),
                                  if (needsInvoice && needsCmr)
                                    const SizedBox(width: 16),
                                  if (needsCmr)
                                    Expanded(
                                      child: _buildDocumentUploadCard(
                                        context,
                                        'CMR',
                                        cmrImage,
                                        () async {
                                          final image = await pickImage();
                                          if (image != null) {
                                            setState(() => cmrImage = image);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],

                            // Packaging Options (only if needed and no container products)
                            if (needsContainer) ...[
                              const SizedBox(height: 24),
                              _buildSectionHeader(
                                context,
                                'Packaging Options',
                                Icons.inventory,
                              ),
                              const SizedBox(height: 16),
                              Card(
                                elevation: 0,
                                color: Theme.of(context).colorScheme.surface,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      _buildPackagingOption(
                                        context,
                                        'Pallet',
                                        isPalletChecked,
                                        palletSubOption,
                                        palletAmount,
                                        ['Plastic', 'Wood'],
                                        (checked) {
                                          setState(() {
                                            isPalletChecked = checked ?? false;
                                            if (!checked!) {
                                              palletSubOption = null;
                                              palletAmount = 0;
                                            }
                                          });
                                        },
                                        (value) => setState(
                                            () => palletSubOption = value),
                                        (value) => setState(
                                            () => palletAmount = value),
                                      ),
                                      const Divider(height: 32),
                                      _buildPackagingOption(
                                        context,
                                        'Crate',
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
                                        (value) => setState(
                                            () => caseSubOption = value),
                                        (value) =>
                                            setState(() => caseAmount = value),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: () {
                              final result = <String, dynamic>{};

                              // Only include values that need updating
                              if (needsUitEkr &&
                                  uitEkrController.text.trim().isNotEmpty) {
                                result['UitEkr'] = uitEkrController.text.trim();
                              }

                              if (needsInvoice && invoiceImage != null) {
                                result['Invoice'] = invoiceImage!.path;
                              }

                              if (needsCmr && cmrImage != null) {
                                result['CMR'] = cmrImage!.path;
                              }

                              if (needsContainer) {
                                if (isPalletChecked &&
                                    palletSubOption != null &&
                                    palletAmount > 0) {
                                  result['Pallet'] = {
                                    'type': palletSubOption,
                                    'amount': palletAmount,
                                  };
                                }

                                if (isCaseChecked &&
                                    caseSubOption != null &&
                                    caseAmount > 0) {
                                  result['Case'] = {
                                    'type': caseSubOption,
                                    'amount': caseAmount,
                                  };
                                }
                              }

                              // Always return a result (even if empty) to indicate the dialog was confirmed
                              Navigator.of(context).pop(result);
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Confirm'),
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
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadCard(
    BuildContext context,
    String title,
    File? image,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 180,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (image != null) ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Change $title',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.upload_file,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload $title',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click to select',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackagingOption(
    BuildContext context,
    String title,
    bool isChecked,
    String? selectedOption,
    int amount,
    List<String> options,
    Function(bool?) onCheckChanged,
    Function(String?) onOptionChanged,
    Function(int) onAmountChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Checkbox(
                    value: isChecked,
                    onChanged: onCheckChanged,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isChecked) ...[
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedOption,
                      hint: const Text('Select Type'),
                      isExpanded: true,
                      items: options.map((String option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: onOptionChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surface.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Amount',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    final amount = int.tryParse(value) ?? 0;
                    onAmountChanged(amount);
                  },
                  controller: TextEditingController(
                      text: amount > 0 ? amount.toString() : ''),
                ),
              ),
            ],
          ],
        ),
        if (isChecked)
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: Text(
              'Total: $amount ${title.toLowerCase()}${amount != 1 ? 's' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(
          seconds: 3), // Duration for which the SnackBar is shown
      behavior: SnackBarBehavior
          .floating, // Optional: makes it float above other content
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
                                                            '${product.quantity} kg'),
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
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12.0),
                                          if (buildProductsTable(
                                                  order.products, 'container')
                                              .children
                                              .isNotEmpty)
                                            buildProductsTable(
                                                order.products, 'container'),

                                          const SizedBox(height: 12.0),
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

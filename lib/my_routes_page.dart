import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/product.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/services/order_services.dart';
import 'package:intl/intl.dart'; // To format dates
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

class MyRoutesPage extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const MyRoutesPage({
    Key? key,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  _MyRoutesPageState createState() => _MyRoutesPageState();
}

class _MyRoutesPageState extends State<MyRoutesPage>
    with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DriverPage _listFunctions = DriverPage();
  bool isLoading = true;
  bool isFiltered = false;
  String? errorMessage;


  List<bool> expandedStates = [];
  List<AnimationController> animationControllers = [];
  List<Animation<double>> animations = [];
  List<bool> isButtonVisible = [];

  @override
  void initState() {
    super.initState();
    fetchInitialOrders().then((_) {
      initializeAnimations();
    });
  }

  Future<void> fetchInitialOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _orderService.fetchOrders(
        fromDate: widget.startDate,
        toDate: widget.endDate,
      );
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching initial orders: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load orders';
      });
    }
  }

  //listfunctions

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
                  _buildHeaderCell('Pieces'),
                  _buildHeaderCell('KG'),
                ],
              ),
              ...firstOccurrence.entries.map((entry) {
                final productName = entry.key;
                final product = entry.value;
                final quantity = quantityMap[productName] ?? 0;
                final totalPrice = quantity * (priceMap[productName] ?? 0);
                final totalWeight = quantity * product.productWeight;

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(productName),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('$quantity'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${totalWeight.toStringAsFixed(2)}'),
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
            _buildHeaderCell('Pieces'),
            _buildHeaderCell('KG'),
          ],
        ),
        ...filteredProducts.map((product) {
          final totalPrice = product.quantity * product.price;
          final weight = product.productWeight * product.quantity;
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
                child: Text('${weight.toStringAsFixed(2)}'),
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

    // Create new controllers and animations for each order
    for (var _ in _orderService.orders) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Routes', style: TextStyle(color: Colors.white)),
            Text(
              '${DateFormat('MMM dd').format(widget.startDate)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchInitialOrders,
          ),
        ],// Change back button color to white
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null || _orderService.orders.isEmpty
              ? Center(
                  child: Text(
                    errorMessage != null
                        ? 'No orders available for this interval.'
                        : 'No orders available.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: errorMessage != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
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
                    final deliveryContact = order.contactPeople.firstWhere(
                        (cp) => cp.type == 'delivery',
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
                          side:
                              const BorderSide(color: Colors.black, width: 1.5),
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
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 5.0),
                                            Text(
                                              order.pickupTime,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
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
                                          style: TextStyle(color: Colors.black),
                                        ),
                                        // Clickable address
                                        GestureDetector(
                                          onTap: () async {
                                            // Use coordinates if available, otherwise fall back to the warehouse address
                                            final String address =
                                                pickupWarehouse.coordinates
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? pickupWarehouse
                                                        .coordinates!
                                                    : pickupWarehouse
                                                        .warehouseAddress;

                                            final Uri launchUri = Uri(
                                              scheme: 'geo',
                                              path: '0,0',
                                              queryParameters: {'q': address},
                                            );

                                            try {
                                              await launchUrl(launchUri);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Could not open Google Maps.')),
                                              );
                                            }
                                          },
                                          child: Text(
                                            pickupWarehouse.warehouseAddress,
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    Text(
                                      'Company: ${pickupCompany.companyName}',
                                      style:
                                          const TextStyle(color: Colors.grey),
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
                                              pickupContact.telephone.length >
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
                                                await launchUrl(launchUri);
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
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
                                          color: (pickupContact
                                                      .telephone.isNotEmpty &&
                                                  pickupContact
                                                          .telephone.length >
                                                      10)
                                              ? Colors.blue
                                              : Colors
                                                  .grey, // Grey to indicate non-clickable
                                          decoration: (pickupContact
                                                      .telephone.isNotEmpty &&
                                                  pickupContact
                                                          .telephone.length >
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
                                  height: 12.0), // Space between containers

                              // Delivery Details Container

                              Container(
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 5.0),
                                            Text(
                                              order.deliveryTime,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
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
                                          style: TextStyle(color: Colors.black),
                                        ),
                                        // Clickable address
                                        GestureDetector(
                                          onTap: () async {
                                            // Use coordinates if available, otherwise fall back to the warehouse address
                                            final String address =
                                                deliveryWarehouse.coordinates
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? deliveryWarehouse
                                                        .coordinates!
                                                    : deliveryWarehouse
                                                        .warehouseAddress;

                                            final Uri launchUri = Uri(
                                              scheme: 'geo',
                                              path: '0,0',
                                              queryParameters: {'q': address},
                                            );

                                            try {
                                              await launchUrl(launchUri);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Could not open Google Maps.')),
                                              );
                                            }
                                          },
                                          child: Text(
                                            deliveryWarehouse.warehouseAddress,
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    Text(
                                      'Company: ${deliveryCompany.companyName}',
                                      style:
                                          const TextStyle(color: Colors.grey),
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
                                              deliveryContact.telephone.length >
                                                  10)
                                          ? () async {
                                              final String phoneNumber =
                                                  deliveryContact.telephone;
                                              print(phoneNumber);

                                              final Uri launchUri = Uri(
                                                scheme: 'tel',
                                                path: phoneNumber,
                                              );

                                              try {
                                                await launchUrl(launchUri);
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
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
                                                      .telephone.isNotEmpty &&
                                                  deliveryContact
                                                          .telephone.length >
                                                      10)
                                              ? Colors.blue
                                              : Colors
                                                  .grey, // Grey to indicate non-clickable
                                          decoration: (deliveryContact
                                                      .telephone.isNotEmpty &&
                                                  deliveryContact
                                                          .telephone.length >
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
                                          0: FlexColumnWidth(3), // Product Name
                                          1: FlexColumnWidth(1), // Quantity
                                          2: FlexColumnWidth(1), // Price (RON)
                                        },
                                        children: [
                                          const TableRow(
                                            decoration: BoxDecoration(
                                                color: Colors.grey),
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Text('Product Name',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Text('Pieces',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Text('KG',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
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
                                              decoration: const BoxDecoration(
                                                color: Colors
                                                    .white, // Ensure each row has white background
                                              ),
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child:
                                                      Text(product.productName),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Text(
                                                      '${product.quantity * product.productWeight} kg'),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Text(
                                                      'Weight(KG)'),
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
                                      buildContainersTables(order.products),

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
                                      width: 10), // Adds spacing for clarity
                                  GestureDetector(
                                    onTap: order.uitEkr.isNotEmpty
                                        ? () {
                                            // Handle tap for EKR
                                            ShowEkr(context, order.uitEkr);
                                          }
                                        : null, // Disable tap if not green
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: order.uitEkr.isNotEmpty
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(
                                            8), // Rounded rectangle
                                      ),
                                      child: const Text(
                                        'EKR',
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Text color
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                      width: 10), // Space between containers
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
                                        borderRadius: BorderRadius.circular(
                                            8), // Rounded rectangle
                                      ),
                                      child: const Text(
                                        'Invoice',
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Text color
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                      width: 10), // Space between containers
                                  GestureDetector(
                                    onTap: order.cmr.isNotEmpty
                                        ? () {
                                            ShowInvoiceCmr(context, order.cmr);
                                          }
                                        : null, // Disable tap if not green
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: order.cmr.isNotEmpty
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(
                                            8), // Rounded rectangle
                                      ),
                                      child: const Text(
                                        'CMR',
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Text color
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
                ),
    );
  }
}

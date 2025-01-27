import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:foodex/deliveryInfo.dart';
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
  bool isLoading = true;
  bool isFiltered = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchInitialOrders();
  }

  Future<void> fetchInitialOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    DateTime fromDate = widget.startDate;
    DateTime toDate = widget.endDate;

    // Format dates exactly as expected by the backend
    String formattedFromDate = DateFormat('yyyy-MM-dd').format(fromDate);
    String formattedToDate = DateFormat('yyyy-MM-dd').format(toDate);

    try {
      await _orderService.fetchAllOrders(
        fromDate: formattedFromDate,
        toDate: formattedToDate,
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
    super.dispose();
  }

// Keep the original buildProductsTable for compatibility with existing checks

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
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
          ], // Change back button color to white
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null || _orderService.allOrders.isEmpty
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
                      final deliveryContact = order.contactPeople.firstWhere(
                          (cp) => cp.type == 'delivery',
                          orElse: () => defaultContactPerson);

                      return GestureDetector(
                        onTap: () {
                          Globals.startDate = widget.startDate;
                          Globals.endDate = widget.endDate;
                          Navigator.pushReplacement(
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
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              Text(
                                                pickupCompany.companyName,
                                                style: const TextStyle(
                                                  fontSize: 18.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MM-dd (E) HH:mm')
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
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (order
                                                      .upNotes.isNotEmpty) ...[
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12.0),
                                                        border: Border.all(
                                                          color: Colors.amber,
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
                                                    const SizedBox(width: 8.0),
                                                  ],
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: (pickupContact.name.isNotEmpty &&
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
                                                              .withOpacity(0.1)
                                                          : Colors.red
                                                              .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                                      color: (pickupContact.name.isNotEmpty &&
                                                              pickupContact
                                                                      .name !=
                                                                  "N/A" &&
                                                              pickupContact
                                                                  .telephone
                                                                  .isNotEmpty &&
                                                              pickupContact
                                                                      .telephone !=
                                                                  "N/A")
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors.red.shade700,
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
                                              Text(
                                                deliveryCompany.companyName,
                                                style: const TextStyle(
                                                  fontSize: 18.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MM-dd (E) HH:mm')
                                                    .format(DateTime.parse(
                                                        order.deliveryTime)),
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
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (order.downNotes
                                                      .isNotEmpty) ...[
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12.0),
                                                        border: Border.all(
                                                          color: Colors.amber,
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
                                                    const SizedBox(width: 8.0),
                                                  ],
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
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
                                                              .withOpacity(0.1)
                                                          : Colors.red
                                                              .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
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
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors.red.shade700,
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
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
                  ));
  }
}

// ignore: file_names
import 'dart:io';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/services.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/product.dart';
import 'package:foodex/my_routes_page.dart';
import 'package:foodex/services/delivery_service.dart';
import 'package:foodex/services/order_services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:foodex/models/order.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryInfo extends StatefulWidget {
  final int orderId;
  final bool? myRoutesPage;

  const DeliveryInfo(
      {super.key, required this.orderId, this.myRoutesPage = false});

  @override
  State<DeliveryInfo> createState() => _DeliveryInfoState();
}

class _DeliveryInfoState extends State<DeliveryInfo> {
  // Initialize delivery service

  final deliveryService = DeliveryService();
  final orderService = OrderService();

  late Order order = Order.empty();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    widget.myRoutesPage;
  }

  Future<void> _loadOrder() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final orderData = await orderService.getOrderById(widget.orderId);

      if (mounted) {
        setState(() {
          order = orderData ?? Order.empty();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildProductsTable(BuildContext context, bool isSmallScreen) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Colors.black,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dataTableTheme: DataTableThemeData(
                dataRowMinHeight: 48,
                dataRowMaxHeight: textScaleFactor * 64,
                headingRowHeight: 56,
              ),
            ),
            child: DataTable(
              columnSpacing: isSmallScreen ? 16 : 24,
              horizontalMargin: isSmallScreen ? 16 : 24,
              columns: [
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Product Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Weight (kg)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Price (RON)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: order.products
                  .where((product) => product.productType == 'product')
                  .map((product) {
                final totalWeight = product.quantity * product.productWeight;
                final totalPrice = product.quantity * product.price;
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width *
                              (isSmallScreen ? 0.4 : 0.5),
                        ),
                        child: Text(
                          product.productName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        totalWeight.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        totalPrice.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContainersTable(BuildContext context, bool isSmallScreen) {
    if (!order.products
        .any((p) => p.productType == 'palette' || p.productType == 'crate')) {
      return const SizedBox.shrink();
    }

    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    // Group products by name and sum quantities
    Map<String, int> summedQuantities = {};
    for (var product in order.products
        .where((p) => p.productType == 'palette' || p.productType == 'crate')) {
      summedQuantities[product.productName] =
          (summedQuantities[product.productName] ?? 0) + product.quantity;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Colors.black,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dataTableTheme: DataTableThemeData(
                dataRowMinHeight: 48,
                dataRowMaxHeight: textScaleFactor * 64,
                headingRowHeight: 56,
              ),
            ),
            child: DataTable(
              columnSpacing: isSmallScreen ? 16 : 24,
              horizontalMargin: isSmallScreen ? 16 : 24,
              columns: [
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Container Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Weight (kg)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Price (RON)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: summedQuantities.entries.map((entry) {
                final productName = entry.key;
                final totalQuantity = entry.value;
                final product = order.products
                    .firstWhere((p) => p.productName == productName);
                final totalPrice = totalQuantity * product.price;
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width *
                              (isSmallScreen ? 0.5 : 0.6),
                        ),
                        child: Text(
                          productName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${(totalQuantity * product.productWeight).toStringAsFixed(2)} kg',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        totalPrice.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context, bool isSmallScreen) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Colors.black,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16.0 : 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Weight:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${order.getTotalWeight()} kg',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  //UIT,EKR, INVOICE, CMR

  Widget _buildUitEkrInvCmr(
    BuildContext context,
    String Uit,
    String Ekr,
    String Invoice,
    String Cmr,
    bool isSmallScreen,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.black,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uit number display
          GestureDetector(
            onTap: () {
              if (Uit.isNotEmpty) {
                showUitEkr(context, Uit, null, order.orderId, _loadOrder);
              } else {
                print("Uit update for orderID ${order.orderId}");
                updateUit(context, order.orderId, _loadOrder);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Uit.isNotEmpty
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Uit.isNotEmpty ? Colors.green : Colors.red,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.numbers_rounded,
                    size: isSmallScreen ? 20 : 22,
                    color: Uit.isNotEmpty
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    'Uit:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    Uit,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.0),
          // Ekr number display
          GestureDetector(
            onTap: () {
              if (Ekr.isNotEmpty) {
                showUitEkr(context, null, Ekr, order.orderId, _loadOrder);
              } else {
                updateEkr(context, order.orderId, _loadOrder);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Ekr.isNotEmpty
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Ekr.isNotEmpty ? Colors.green : Colors.red,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.numbers_rounded,
                    size: isSmallScreen ? 20 : 22,
                    color: Ekr.isNotEmpty
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    'Ekr:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    Ekr,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.0),
          // Invoice and CMR boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (Invoice.isNotEmpty) {
                      ShowInvoiceCmr(
                          context, Invoice, _loadOrder, order.orderId);
                    } else {
                      print("Invoice update for order ${order.orderId}");
                      updateInvoice(context, order.orderId, _loadOrder);
                    }
                  },
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Invoice.isNotEmpty
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Invoice.isNotEmpty ? Colors.green : Colors.red,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: isSmallScreen ? 24 : 28,
                          color: Invoice.isNotEmpty
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          'Invoice',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                // Moved Expanded here
                child: GestureDetector(
                  onTap: () {
                    if (Cmr.isNotEmpty) {
                      ShowInvoiceCmr(context, Cmr, _loadOrder, order.orderId);
                    } else {
                      print("Cmr update for order ${order.orderId}");
                      updateCmr(context, order.orderId, _loadOrder);
                    }
                  },
                  child: Container(
                    // Removed the Expanded from here
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Cmr.isNotEmpty
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Cmr.isNotEmpty ? Colors.green : Colors.red,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.file_copy_outlined,
                          size: isSmallScreen ? 24 : 28,
                          color: Cmr.isNotEmpty
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          'CMR',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //CONTAINER OPTIONS
  Widget _buildContainerStatus(BuildContext context, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.black,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => updatePalets(context, order.orderId, _loadOrder),
              child: Container(
                //height: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: order.products.any((p) => p.productType == 'palette')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: order.products.any((p) => p.productType == 'palette')
                        ? Colors.green
                        : Colors.red,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/assets/images/palet.jpg',
                      height: isSmallScreen ? 56 : 60,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Palets',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: GestureDetector(
              onTap: () => updateCrates(context, order.orderId, _loadOrder),
              child: Container(
                //height: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: order.products.any((p) => p.productType == 'crate')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: order.products.any((p) => p.productType == 'crate')
                        ? Colors.green
                        : Colors.red,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/assets/images/crate.jpg',
                      height: isSmallScreen ? 56 : 60,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Crates',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //PICKUP/DELIVER BUTTON
  Widget _buildActionButton(BuildContext context, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 1, 160, 226),
          minimumSize: Size(double.infinity, isSmallScreen ? 48 : 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () => showConfirmationDialog(
          context,
          order,
          () async {
            try {
              if (order.pickedUp == '0000-00-00 00:00:00') {
                await DeliveryService().pickupOrder(order.orderId, false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Order picked up successfully')),
                  );
                }
              } else if (order.delivered == '0000-00-00 00:00:00') {
                await DeliveryService().deliverOrder(order.orderId, false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Order delivered successfully')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            }
          },
        ),
        child: Text(
          order.pickedUp == '0000-00-00 00:00:00'
              ? 'Pick Up Order'
              : order.delivered == '0000-00-00 00:00:00'
                  ? 'Deliver Order'
                  : '',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    final pickupWarehouse = order.warehouses.firstWhere(
      (wh) => wh.type == 'pickup',
      orElse: () => Warehouse(
        warehouseName: 'Unknown',
        warehouseAddress: 'N/A',
        type: 'pickup',
        coordinates: 'N/A',
      ),
    );

    final deliveryWarehouse = order.warehouses.firstWhere(
      (wh) => wh.type == 'delivery',
      orElse: () => Warehouse(
        warehouseName: 'Unknown',
        warehouseAddress: 'N/A',
        type: 'delivery',
        coordinates: 'N/A',
      ),
    );

    final pickupCompany = order.companies.firstWhere(
      (comp) => comp.type == 'pickup',
      orElse: () => Company(
        companyName: 'Unknown',
        type: 'pickup',
      ),
    );

    final deliveryCompany = order.companies.firstWhere(
      (comp) => comp.type == 'delivery',
      orElse: () => Company(
        companyName: 'Unknown',
        type: 'delivery',
      ),
    );

    final pickupContact = order.contactPeople.firstWhere(
      (cp) => cp.type == 'pickup',
      orElse: () => ContactPerson(
        name: 'Unknown',
        telephone: 'N/A',
        type: 'pickup',
      ),
    );

    final deliveryContact = order.contactPeople.firstWhere(
      (cp) => cp.type == 'delivery',
      orElse: () => ContactPerson(
        name: 'Unknown',
        telephone: 'N/A',
        type: 'delivery',
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Handle the navigation back with order refresh
        final startDate = Globals.startDate;
        final endDate = Globals.endDate;
        Globals.clearRouteDates();

        if (widget.myRoutesPage != null && widget.myRoutesPage!) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyRoutesPage(
                startDate: startDate ?? DateTime.now(),
                endDate: endDate ?? DateTime.now(),
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverPage()),
          );
        }
        // Prevent default back behavior since we're handling navigation
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              final startDate = Globals.startDate;
              final endDate = Globals.endDate;
              Globals.clearRouteDates();

              if (widget.myRoutesPage != null && widget.myRoutesPage!) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyRoutesPage(
                      startDate: startDate ?? DateTime.now(),
                      endDate: endDate ?? DateTime.now(),
                    ),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const DriverPage()),
                );
              }
            },
          ),
          title: const Center(
            child: Text(
              'Delivery Information',
              style: TextStyle(color: Colors.white),
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 1, 160, 226),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: isSmallScreen ? 8.0 : 16.0),
              child: order.pickedUp == '0000-00-00 00:00:00'
                  ? Icon(
                      Icons.keyboard_arrow_up,
                      color: const Color.fromARGB(255, 108, 226, 112),
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null ||
                    order == Order.empty() // Check if order is empty
                ? Center(
                    child: Text(
                      "Couldn't load order",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      pickupCompany.companyName,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 18.0 : 22.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MM-dd (E) HH:mm').format(
                                          DateTime.parse(order.pickupTime)),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14.0 : 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  children: [
                                    Text(
                                      'Address: ',
                                      style: TextStyle(
                                          fontSize: isSmallScreen ? 16.0 : 18.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final String address = pickupWarehouse
                                                    .coordinates?.isNotEmpty ==
                                                true
                                            ? pickupWarehouse.coordinates!
                                            : pickupWarehouse.warehouseAddress;

                                        final Uri launchUri = Uri(
                                          scheme: 'geo',
                                          path: '0,0',
                                          queryParameters: {'q': address},
                                        );

                                        try {
                                          await launchUrl(launchUri);
                                        } catch (e) {
                                          // ignore: use_build_context_synchronously
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
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16.0 : 18.0,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (pickupContact
                                                .telephone.isNotEmpty &&
                                            pickupContact.telephone != "N/A") {
                                          openContactPerson(
                                              context,
                                              pickupContact.name,
                                              pickupContact.telephone);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: (pickupContact
                                                      .name.isNotEmpty &&
                                                  pickupContact.name != "N/A" &&
                                                  pickupContact
                                                      .telephone.isNotEmpty &&
                                                  pickupContact.telephone !=
                                                      "N/A")
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: (pickupContact
                                                        .name.isNotEmpty &&
                                                    pickupContact.name !=
                                                        "N/A" &&
                                                    pickupContact
                                                        .telephone.isNotEmpty &&
                                                    pickupContact.telephone !=
                                                        "N/A")
                                                ? Colors.green
                                                : Colors.red,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person_rounded,
                                                size: isSmallScreen ? 20 : 22,
                                                color: (pickupContact
                                                            .name.isNotEmpty &&
                                                        pickupContact.name !=
                                                            "N/A" &&
                                                        pickupContact.telephone
                                                            .isNotEmpty &&
                                                        pickupContact
                                                                .telephone !=
                                                            "N/A")
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 12.0),
                                              Text(
                                                'Pickup Contact',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen
                                                      ? 14.0
                                                      : 16.0,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        width:
                                            12.0), // Spacing between containers
                                    GestureDetector(
                                      onTap: () {
                                        if (order.upNotes != null &&
                                            order.upNotes.isNotEmpty) {
                                          openNotes(context, order.upNotes);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: (order.upNotes != null &&
                                                  order.upNotes.isNotEmpty)
                                              ? Colors.amber.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: (order.upNotes != null &&
                                                    order.upNotes.isNotEmpty)
                                                ? Colors.amber
                                                : Colors.red,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.note_rounded,
                                                size: isSmallScreen ? 20 : 22,
                                                color: (order.upNotes != null &&
                                                        order
                                                            .upNotes.isNotEmpty)
                                                    ? Colors.amber.shade700
                                                    : Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 12.0),
                                              Text(
                                                'Notes',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen
                                                      ? 14.0
                                                      : 16.0,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),

                          //DELIVER LOCATION
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      deliveryCompany.companyName,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 18.0 : 22.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MM-dd (E) HH:mm').format(
                                          DateTime.parse(order.deliveryTime)),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14.0 : 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  children: [
                                    Text(
                                      'Address: ',
                                      style: TextStyle(
                                          fontSize: isSmallScreen ? 16.0 : 18.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final String address = deliveryWarehouse
                                                    .coordinates?.isNotEmpty ==
                                                true
                                            ? deliveryWarehouse.coordinates!
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
                                          // ignore: use_build_context_synchronously
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
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16.0 : 18.0,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (deliveryContact
                                                .telephone.isNotEmpty &&
                                            deliveryContact.telephone !=
                                                "N/A") {
                                          openContactPerson(
                                              context,
                                              deliveryContact.name,
                                              deliveryContact.telephone);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: (deliveryContact
                                                      .name.isNotEmpty &&
                                                  deliveryContact.name !=
                                                      "N/A" &&
                                                  deliveryContact
                                                      .telephone.isNotEmpty &&
                                                  deliveryContact.telephone !=
                                                      "N/A")
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: (deliveryContact
                                                        .name.isNotEmpty &&
                                                    deliveryContact.name !=
                                                        "N/A" &&
                                                    deliveryContact
                                                        .telephone.isNotEmpty &&
                                                    deliveryContact.telephone !=
                                                        "N/A")
                                                ? Colors.green
                                                : Colors.red,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person_rounded,
                                                size: isSmallScreen ? 20 : 22,
                                                color: (deliveryContact
                                                            .name.isNotEmpty &&
                                                        deliveryContact.name !=
                                                            "N/A" &&
                                                        deliveryContact
                                                            .telephone
                                                            .isNotEmpty &&
                                                        deliveryContact
                                                                .telephone !=
                                                            "N/A")
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 12.0),
                                              Text(
                                                'Delivery Contact',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen
                                                      ? 14.0
                                                      : 16.0,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                    GestureDetector(
                                      onTap: () {
                                        if (order.downNotes != null &&
                                            order.downNotes.isNotEmpty) {
                                          openNotes(context, order.downNotes);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: (order.downNotes != null &&
                                                  order.downNotes.isNotEmpty)
                                              ? Colors.amber.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: (order.downNotes != null &&
                                                    order.downNotes.isNotEmpty)
                                                ? Colors.amber
                                                : Colors.red,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.note_rounded,
                                                size: isSmallScreen ? 20 : 22,
                                                color:
                                                    (order.downNotes != null &&
                                                            order.downNotes
                                                                .isNotEmpty)
                                                        ? Colors.amber.shade700
                                                        : Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 12.0),
                                              Text(
                                                'Notes',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen
                                                      ? 14.0
                                                      : 16.0,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          //PRODUCTS AND CONTAINERS TABLES
                          const SizedBox(height: 16),
                          _buildProductsTable(context, isSmallScreen),
                          _buildContainersTable(context, isSmallScreen),
                          _buildOrderSummary(context, isSmallScreen),

                          //UIT,EKR, INVOICE, CMR
                          const SizedBox(height: 16),
                          _buildUitEkrInvCmr(context, order.uit, order.ekr,
                              order.invoice, order.cmr, isSmallScreen),

                          //CONTAINERS
                          const SizedBox(height: 16),
                          _buildContainerStatus(context, isSmallScreen),
                          //DELIVER/PICKUP BUTTON
                          if (Globals.vehicleID != null) ...[
                            if (order.pickedUp == '0000-00-00 00:00:00' ||
                                order.delivered == '0000-00-00 00:00:00') ...[
                              const SizedBox(height: 16),
                              _buildActionButton(context, isSmallScreen),
                            ]
                          ]
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

void openContactPerson(BuildContext context, String name, String telephone) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_rounded,
                        size: isSmallScreen ? 50 : 56,
                        color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20.0 : 24.0,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    telephone,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 28.0 : 32.0,
                      color: Colors.grey.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => openDialer(context, telephone),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: Text(
                      'Call',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      backgroundColor: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
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
  );
}

void openDialer(BuildContext context, String telephone) async {
  final Uri launchUri = Uri.parse('tel:$telephone');
  try {
    await launchUrl(launchUri);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not launch dialer.')),
    );
  }
}

void openNotes(BuildContext context, String notes) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          //width: double.infinity,
          //height: double.minPositive,
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.note_rounded,
                      color: Colors.amber.shade700,
                      size: isSmallScreen ? 50 : 56,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 28.0 : 32.0,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 24,
                      vertical: isSmallScreen ? 10 : 12,
                    ),
                    backgroundColor: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showUitEkr(BuildContext context, String? uit, String? ekr, int orderId,
    Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;

  // Determine which value to show
  String? valueToShow;
  String labelToShow;
  if (uit != null && uit.isNotEmpty) {
    valueToShow = uit;
    labelToShow = 'UIT';
  } else if (ekr != null && ekr.isNotEmpty) {
    valueToShow = ekr;
    labelToShow = 'EKR';
  } else {
    valueToShow = null;
    labelToShow = '';
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (valueToShow != null) ...[
                Text(
                  labelToShow,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 30.0 : 34.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      valueToShow,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 28.0 : 32.0,
                        height: 1.5,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (uit != null && uit.isNotEmpty) {
                        updateUit(context, orderId, reloadPage);
                      } else {
                        updateEkr(context, orderId, reloadPage);
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      backgroundColor: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      backgroundColor: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
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
  );
}

void ShowInvoiceCmr(BuildContext context, String relativePdfUrl,
    Function reloadPage, int orderId) async {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  // Show loading dialog immediately
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
              const SizedBox(height: 16),
              const Text(
                'Loading document...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    },
  );

  try {
    // Define the base URL for your server
    String baseUrl = 'https://vinczefi.com/foodexim/';
    String fullUrl = baseUrl + relativePdfUrl;
    final encodedUrl = Uri.encodeFull(fullUrl);

    // Check file type from URL
    bool isImage = fullUrl.toLowerCase().endsWith('.jpg') ||
        fullUrl.toLowerCase().endsWith('.jpeg') ||
        fullUrl.toLowerCase().endsWith('.png');

    // Get document type from URL for title
    String documentType = 'Document';
    if (relativePdfUrl.toLowerCase().contains('invoice')) {
      documentType = 'Invoice';
    } else if (relativePdfUrl.toLowerCase().contains('cmr')) {
      documentType = 'CMR';
    }

    // Generate a unique filename using timestamp and document type
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String uniqueFileName =
        '${documentType.toLowerCase()}_$timestamp${isImage ? '.jpg' : '.pdf'}';

    // Download the file from the server
    final response = await http.get(Uri.parse(encodedUrl));

    if (response.statusCode == 200) {
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/$uniqueFileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Show the appropriate viewer in a dialog
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false, // Prevent closing by tapping outside
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Container(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    documentType,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: isImage
                          ? Image.file(
                              file,
                              fit: BoxFit.contain,
                              // Disable caching for this image
                              cacheWidth: null,
                              cacheHeight: null,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    'Error loading image: $error',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              },
                            )
                          : PDFView(
                              filePath: file.path,
                              enableSwipe: true,
                              swipeHorizontal: true,
                              autoSpacing: true,
                              onError: (error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error loading PDF: $error'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (documentType == 'Invoice') {
                            updateInvoice(context, orderId, reloadPage);
                          } else {
                            updateCmr(context, orderId, reloadPage);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 20 : 24,
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                          backgroundColor: Colors.blue.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 20 : 24,
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                          backgroundColor: Colors.green.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
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
      );

      // Clean up the temporary file after dialog is closed
      if (file.existsSync()) {
        await file.delete();
      }
    } else {
      // Close loading dialog before showing error
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load document: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    // Close loading dialog before showing error
    if (!context.mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading document: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void updateUit(BuildContext context, int orderId, Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  String? newUit;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Update UIT",
                style: TextStyle(
                  fontSize: isSmallScreen ? 30.0 : 34.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter new UIT',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (value) => newUit = value,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (newUit?.isNotEmpty ?? false) {
                        try {
                          await DeliveryService()
                              .updateOrderUit(orderId, newUit!);
                          Navigator.pop(context);
                          reloadPage();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('UIT updated successfully')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Update',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void updateEkr(BuildContext context, int orderId, Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  String? newEkr;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Update EKR",
                style: TextStyle(
                  fontSize: isSmallScreen ? 30.0 : 34.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter new EKR',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (value) => newEkr = value,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (newEkr?.isNotEmpty ?? false) {
                        try {
                          await DeliveryService()
                              .updateOrderEkr(orderId, newEkr!);
                          Navigator.pop(context);
                          reloadPage();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('EKR updated successfully')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Update',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void updateInvoice(BuildContext context, int orderId, Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  List<File> selectedFiles = [];

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: screenSize.width * 0.8,
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: isSmallScreen ? 40 : 44,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Invoice',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 28.0 : 32.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images = await picker.pickMultiImage();
                      if (images.isNotEmpty) {
                        setState(() {
                          selectedFiles
                              .addAll(images.map((image) => File(image.path)));
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Select Images',
                        style: TextStyle(color: Colors.white)),
                  ),
                  if (selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.file(
                                  selectedFiles[index],
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      selectedFiles.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: selectedFiles.isEmpty
                            ? null
                            : () async {
                                try {
                                  for (var file in selectedFiles) {
                                    await DeliveryService().updateOrderInvoice(
                                        orderId, selectedFiles);
                                  }
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Invoices uploaded successfully')),
                                  );
                                  reloadPage();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error: ${e.toString()}')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Upload',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
      );
    },
  );
}

void updateCmr(BuildContext context, int orderId, Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  List<File> selectedFiles = [];

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: screenSize.width * 0.8,
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.file_copy_outlined,
                        size: isSmallScreen ? 40 : 44,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'CMR',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 28.0 : 32.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images = await picker.pickMultiImage();
                      if (images.isNotEmpty) {
                        setState(() {
                          selectedFiles
                              .addAll(images.map((image) => File(image.path)));
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Select Images',
                        style: TextStyle(color: Colors.white)),
                  ),
                  if (selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.file(
                                  selectedFiles[index],
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      selectedFiles.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: selectedFiles.isEmpty
                            ? null
                            : () async {
                                try {
                                  await DeliveryService()
                                      .updateOrderCmr(orderId, selectedFiles);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('CMR uploaded successfully')),
                                  );
                                  reloadPage();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error: ${e.toString()}')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Upload',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 16.0,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
      );
    },
  );
}

void updateCrates(BuildContext context, int orderId, Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  String? selectedCrateType;
  int crateQuantity = 0;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          'lib/assets/images/crate.jpg',
                          height: isSmallScreen ? 40 : 44,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Update Crates',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedCrateType,
                          hint: const Text('Select Crate Type'),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'm10', child: Text('M10')),
                            DropdownMenuItem(value: 'e2', child: Text('E2')),
                          ],
                          onChanged: (value) =>
                              setState(() => selectedCrateType = value),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(
                              () => crateQuantity = int.tryParse(value) ?? 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          backgroundColor: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await DeliveryService().updateCrates(orderId,
                                crateQuantity, selectedCrateType ?? '');
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Crates updated successfully')),
                            );
                            reloadPage();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 1, 160, 226),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Update',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
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

void updatePalets(BuildContext context, int orderId, Function reloadPage) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;
  String? selectedPaletType;
  int paletQuantity = 0;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          'lib/assets/images/palet.jpg',
                          height: isSmallScreen ? 40 : 44,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Update Palets',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedPaletType,
                          hint: const Text('Select Palet Type'),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'plastic', child: Text('Plastic')),
                            DropdownMenuItem(
                                value: 'lemn', child: Text('Lemn')),
                          ],
                          onChanged: (value) =>
                              setState(() => selectedPaletType = value),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(
                              () => paletQuantity = int.tryParse(value) ?? 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          backgroundColor: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await DeliveryService().updatePallets(orderId,
                                paletQuantity, selectedPaletType ?? '');
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Palets updated successfully')),
                            );
                            reloadPage();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 1, 160, 226),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Update',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
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

void showConfirmationDialog(
    BuildContext context, Order order, Function onConfirm) {
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    order.pickedUp == '0000-00-00 00:00:00'
                        ? Icons.local_shipping
                        : Icons.location_on,
                    size: isSmallScreen ? 48 : 56,
                    color: const Color.fromARGB(255, 1, 160, 226),
                  ),
                  const SizedBox(width: 8),
                  if (order.pickedUp == '0000-00-00 00:00:00') ...[
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.green,
                      size: isSmallScreen ? 74 : 80,
                    )
                  ] else
                    order.delivered == '0000-00-00 00:00:00'
                        ? Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.red,
                            size: isSmallScreen ? 74 : 80,
                          )
                        : Container(),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                order.pickedUp == '0000-00-00 00:00:00'
                    ? 'Confirm Pickup'
                    : 'Confirm Delivery',
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                order.pickedUp == '0000-00-00 00:00:00'
                    ? 'Are you sure you want to pick up this order?'
                    : 'Are you sure you want to deliver this order?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 20,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DriverPage()),
                      );
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 20,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
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
  );
}

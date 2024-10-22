import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/company.dart';
import 'package:foodex/models/contact_person.dart';
import 'package:foodex/models/warehouse.dart';
import 'package:foodex/services/order_services.dart';
import 'package:intl/intl.dart'; // To format dates

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
  const MyRoutesPage({Key? key}) : super(key: key);

  @override
  _MyRoutesPageState createState() => _MyRoutesPageState();
}

class _MyRoutesPageState extends State<MyRoutesPage> {
  final OrderService _orderService = OrderService();
  bool isLoading = true;
  DateTime? _fromDate;
  DateTime? _toDate;
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
      errorMessage = null; // Reset the error message
    });

    DateTime now = DateTime.now();
    DateTime pastDate = now.subtract(const Duration(days: 360));
    DateTime futureDate = now.add(const Duration(days: 60));

    try {
      await _orderService.fetchOrders(fromDate: pastDate, toDate: futureDate);
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching initial orders: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load orders'; // General error message
      });
    }
  }

  Future<void> fetchOrdersByDate(DateTime fromDate, DateTime toDate) async {
    setState(() {
      isLoading = true;
      isFiltered = true;
      errorMessage = null; // Reset the error message
    });

    try {
      await _orderService.fetchOrders(fromDate: fromDate, toDate: toDate);

      // Check if there are any orders after fetching
      if (_orderService.orders.isEmpty) {
        setState(() {
          errorMessage =
              'No orders found for the selected interval'; // Specific error message
        });
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching orders by date: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load orders'; // General error message
      });
    }
  }

  void clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      isFiltered = false;
      errorMessage = null; // Reset the error message
    });
    fetchInitialOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Routes", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        iconTheme: const IconThemeData(
            color: Colors.white), // Change back button color to white
      ),
      body: Column(
        children: [
          // Filter container

          const SizedBox(height: 5.0),
          Container(
            margin: const EdgeInsets.all(10.0),
            padding: const EdgeInsets.all(15.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.black, width: 1.5),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5.0,
                  spreadRadius: 2.0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Orders by Date',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (isFiltered)
                      TextButton(
                        onPressed: clearFilters,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5.0),
                          // From Date Picker
                          InkWell(
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _fromDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: const Color.fromARGB(255, 1,
                                          160, 226), // Your AppBar color
                                      colorScheme: const ColorScheme.light(
                                          primary: Color.fromARGB(255, 1, 160,
                                              226)), // For button color
                                      buttonTheme: const ButtonThemeData(
                                          textTheme: ButtonTextTheme
                                              .primary), // Make button text color white
                                    ),
                                    child: child ?? Container(),
                                  );
                                },
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _fromDate = pickedDate;
                                });

                                if (_fromDate != null && _toDate != null) {
                                  fetchOrdersByDate(_fromDate!, _toDate!);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 12.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8.0),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 4.0,
                                    spreadRadius: 1.0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                  child: Text(
                                      'From: ${_fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : 'Select From Date'}')),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5.0),
                          // To Date Picker
                          InkWell(
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _toDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: const Color.fromARGB(255, 1,
                                          160, 226), // Your AppBar color
                                      colorScheme: const ColorScheme.light(
                                          primary: Color.fromARGB(255, 1, 160,
                                              226)), // For button color
                                      buttonTheme: const ButtonThemeData(
                                          textTheme: ButtonTextTheme
                                              .primary), // Make button text color white
                                    ),
                                    child: child ?? Container(),
                                  );
                                },
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _toDate = pickedDate;
                                });

                                if (_fromDate != null && _toDate != null) {
                                  fetchOrdersByDate(_fromDate!, _toDate!);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 12.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8.0),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 4.0,
                                    spreadRadius: 1.0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                  child: Text(
                                      'To: ${_toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : 'Select To Date'}')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(10.0),
                      //padding: const EdgeInsets.all(15.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        //border: Border.all(color: Colors.black, width: 1.5),
                        color: Colors.white,
                      ),
                      child:
                          Text('Total orders loaded: ${Globals.ordersNumber}'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: errorMessage != null || _orderService.orders.isEmpty
                        ? Text(
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
                          )
                        : ListView.builder(
                            itemCount: _orderService.orders.length,
                            itemBuilder: (context, index) {
                              final order = _orderService.orders[index];

                              final pickupWarehouse = order.warehouses
                                  .firstWhere((wh) => wh.type == 'pickup',
                                      orElse: () => defaultPickupWarehouse);
                              final deliveryWarehouse = order.warehouses
                                  .firstWhere((wh) => wh.type == 'delivery',
                                      orElse: () => defaultPickupWarehouse);

                              final pickupCompany = order.companies.firstWhere(
                                  (comp) => comp.type == 'pickup',
                                  orElse: () => defaultCompany);
                              final deliveryCompany = order.companies
                                  .firstWhere((comp) => comp.type == 'delivery',
                                      orElse: () => defaultCompany);

                              final pickupContact = order.contactPeople
                                  .firstWhere((cp) => cp.type == 'pickup',
                                      orElse: () => defaultContactPerson);
                              final deliveryContact = order.contactPeople
                                  .firstWhere((cp) => cp.type == 'delivery',
                                      orElse: () => defaultContactPerson);

                              return Card(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                    const Icon(
                                                        Icons.access_time,
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
                                            Text(
                                              'Warehouse: ${pickupWarehouse.warehouseName}, ${pickupWarehouse.warehouseAddress}',
                                              style: const TextStyle(
                                                  color: Colors.grey),
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
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Phone: ${pickupContact.telephone}',
                                              style:
                                                  TextStyle(color: Colors.grey),
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
                                                    const Icon(
                                                        Icons.access_time,
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
                                            Text(
                                              'Warehouse: ${deliveryWarehouse.warehouseName}, ${deliveryWarehouse.warehouseAddress}',
                                              style: const TextStyle(
                                                  color: Colors.grey),
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
                                            Text(
                                              'Phone: ${deliveryContact.telephone}',
                                              style:
                                                  TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(
                                          height:
                                              12.0), // Space before Quantity

                                      //Quantity Field
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
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

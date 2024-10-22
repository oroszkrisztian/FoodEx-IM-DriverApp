import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart';

class ExpenseEntry {
  final int id;
  final String driver;
  final String vehicle;
  final String licensePlate;
  final int km;
  final String type;
  final double cost;
  final double amount;
  final String time;
  final String remarks;
  final String photo;

  ExpenseEntry({
    required this.id,
    required this.driver,
    required this.vehicle,
    required this.licensePlate,
    required this.km,
    required this.type,
    required this.cost,
    required this.amount,
    required this.time,
    required this.remarks,
    required this.photo,
  });

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] ?? 0,
      driver: json['driver'] ?? '',
      vehicle: json['vehicle'] ?? '',
      licensePlate: json['license_plate'] ?? '',
      km: json['mileage'] ?? 0,
      type: json['type'] ?? '',
      cost: json['cost'] != null ? double.parse(json['cost']) : 0.0,
      amount: json['amount'] != null ? double.parse(json['amount']) : 0.0,
      time: json['time'] ?? '',
      remarks: json['remarks'] ?? '',
      photo: json['photo'] ?? '',
    );
  }
}


void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ExpenseLogPage(),
    ),
  );
}

class ExpenseLogPage extends StatefulWidget {
  const ExpenseLogPage({super.key});

  @override
  _ExpenseLogPageState createState() => _ExpenseLogPageState();
}

class _ExpenseLogPageState extends State<ExpenseLogPage> {
  List<ExpenseEntry> _expenseData = [];
  List<ExpenseEntry> _filteredExpenseData = [];
  String _selectedType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  final String baseUrl = 'https://vinczefi.com/'; // Define your base URL here

  @override
  void initState() {
    super.initState();
    _fetchExpenseData(); // Fetch data initially
  }

  Future<void> _fetchExpenseData() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'expenses-filter',
          'from': _startDate != null
              ? DateFormat('yyyy-MM-dd').format(_startDate!)
              : '',
          'to': _endDate != null
              ? DateFormat('yyyy-MM-dd').format(_endDate!)
              : '',
          'type': _selectedType.toLowerCase() == 'all'
              ? 'all'
              : _selectedType.toLowerCase(),
          'driver': Globals.userId.toString(),
          'vehicle': Globals.vehicleID.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<ExpenseEntry> fetchedData =
            responseData.map((data) => ExpenseEntry.fromJson(data)).toList();
        _expenseData = fetchedData;

        _filterData();

        setState(() {
          _filteredExpenseData = _expenseData;
        });

      } else {
        _showErrorDialog('Failed to load expense data',
            'Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to load expense data: $e');
    }
  }

  void _filterData() {
    setState(() {
      _filteredExpenseData = _expenseData.where((expense) {
        DateTime time = DateTime.tryParse(expense.time) ?? DateTime(2000);
        if (_startDate != null && time.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && time.isAfter(_endDate!)) {
          return false;
        }
        if (_selectedType != 'All' &&
            expense.type.toLowerCase() != _selectedType.toLowerCase()) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[Text(message)],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _applyFilters() {
    _fetchExpenseData().then((_) {
      setState(() {
        _filteredExpenseData.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a.time) ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b.time) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      });
    });
  }

  void _filterByType(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 1, 160, 226),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 1, 160, 226),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _showImageDialog(List<String> photoUrls) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 400,
                  child: PageView.builder(
                    itemCount: photoUrls.length,
                    itemBuilder: (context, index) {
                      String photo = photoUrls[index].trim();
                      String imageUrl =
                          baseUrl + 'foodexim/' + photo; // Ensure full URL

                      return InteractiveViewer(
                        child: Image.network(
                          imageUrl,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error);
                          },
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8.0),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(
                        255, 1, 160, 226), // Blue theme color
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Log', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16.0),
            // Filter Container
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  width: 1,
                  color: Colors.black,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                        color: Colors.black),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _selectStartDate(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        child: Text(
                          _startDate != null
                              ? DateFormat('yyyy-MM-dd').format(_startDate!)
                              : 'From',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                        onPressed: () => _selectEndDate(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('yyyy-MM-dd').format(_endDate!)
                              : 'To',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Type',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            color: Colors.black),
                      ),
                      const SizedBox(height: 8.0),
                      DropdownButton<String>(
                        value: _selectedType,
                        onChanged: (value) {
                          _filterByType(value!);
                        },
                        items: ['All', 'Fuel', 'Wash', 'Others']
                            .map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type,
                                      style:
                                          const TextStyle(color: Colors.black)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            // Data Table Container
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  width: 1,
                  color: Colors.black,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'ID',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Driver',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Vehicle',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'License Plate',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'KM',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Type',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Cost',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Amount',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Time',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Remarks',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Photo',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                  rows: _filteredExpenseData.map((data) {
                    return DataRow(
                      cells: [
                        DataCell(Text(data.id.toString())),
                        DataCell(Text(data.driver)),
                        DataCell(Text(data.vehicle)),
                        DataCell(Text(data.licensePlate)),
                        DataCell(Text(data.km.toString())),
                        DataCell(Text(data.type)),
                        DataCell(Text(data.cost.toString())),
                        DataCell(Text(data.amount.toString())),
                        DataCell(Text(data.time)),
                        DataCell(Text(data.remarks)),
                        DataCell(
                          data.photo.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => _showImageDialog(
                                      [data.photo]), // Pass the photo URL(s)
                                  child: const Icon(
                                    Icons.image,
                                    color: Color.fromARGB(255, 1, 160, 226),
                                  ),
                                )
                              : const Text('No photos'),
                        )
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

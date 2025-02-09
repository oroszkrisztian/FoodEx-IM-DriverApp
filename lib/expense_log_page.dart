import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
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

class ExpenseLogPage extends StatefulWidget {
  const ExpenseLogPage({super.key});

  @override
  _ExpenseLogPageState createState() => _ExpenseLogPageState();
}

class _ExpenseLogPageState extends State<ExpenseLogPage> {
  List<ExpenseEntry> _expenseData = [];
  List<ExpenseEntry> _filteredExpenseData = [];
  bool _isLoadingData = false;
  String _selectedType = 'All';
  List<String> _expenseTypes = ['All']; // Store expense types
  bool _isLoadingTypes = true; // Loading state
  DateTime? _startDate;
  DateTime? _endDate;
  final String baseUrl = 'https://vinczefi.com/';

  @override
  void initState() {
    super.initState();
    _initializeData(); // New method to handle initialization
  }

  // Initialize both expense types and data
  Future<void> _initializeData() async {
    await _loadExpenseTypes(); // Load types first
    await _fetchExpenseData(); // Then load expense data
  }

  String _getStandardizedType(String selectedType) {
    // Check for exact matches including special characters
    switch (selectedType) {
      case 'Mosás/Spălare':
      case 'mosás/spălare':
      case 'Mosás':
      case 'Spălare':
        return 'wash';

      case 'Üzemanyag/Combustibil':
      case 'üzemanyag/combustibil':
      case 'Üzemanyag':
      case 'Combustibil':
        return 'fuel';

      case 'All':
        return 'all';

      default:
        return selectedType;
    }
  }

  // Modified to store types in state
  Future<void> _loadExpenseTypes() async {
    try {
      final response = await http.post(
          Uri.parse('https://vinczefi.com/foodexim/functions.php'),
          headers: <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'action': 'get-categories',
            'type': 'expenses'
          });

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        // Create the list of expense types, including 'All' as the first option
        List<String> types = ['All'];
        types.addAll(jsonData
            .where((type) =>
                type is Map<String, dynamic> && type.containsKey('name'))
            .map((type) => type['name'].toString())
            .toList());

        setState(() {
          _expenseTypes = types;
          _isLoadingTypes = false;
        });
      } else {
        throw Exception('Failed to load expense types');
      }
    } catch (e) {
      print('Error loading expense types: $e');
      setState(() {
        _expenseTypes = ['All'];
        _isLoadingTypes = false;
      });
    }
  }

  Future<void> _fetchExpenseData() async {
    setState(() {
      _isLoadingData = true; // Start loading
    });

    print('Raw selected type: $_selectedType');
    String standardizedType = _getStandardizedType(_selectedType);
    print('Standardized type being sent: $standardizedType');

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
          'type': standardizedType,
          'driver': Globals.userId.toString(),
          'vehicle': Globals.vehicleID.toString(),
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<ExpenseEntry> fetchedData =
            responseData.map((data) => ExpenseEntry.fromJson(data)).toList();

        // Sort the data by date (newest first)
        fetchedData.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a.time) ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b.time) ?? DateTime(2000);
          return dateB.compareTo(dateA); // Reverse order for newest first
        });

        setState(() {
          _expenseData = fetchedData;
          _filteredExpenseData = fetchedData;
          _isLoadingData = false; // End loading
        });
      } else {
        throw Exception(
            'Failed to load expense data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _fetchExpenseData: $e');
      setState(() {
        _isLoadingData = false; // End loading even on error
        _expenseData = [];
        _filteredExpenseData = [];
      });
      _showErrorDialog('Error', 'Failed to load expense data: $e');
    }
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

  void _showThemedDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 1, 160, 226),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('${Globals.getText('close')}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyFilters() {
    if (_startDate == null || _endDate == null) {
      _showThemedDialog(
          '${Globals.getText('error')}', '${Globals.getText('selectDate')}');
      return;
    }
    _fetchExpenseData();
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

  // Replace the FutureBuilder with this widget
  Widget buildTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _isLoadingTypes
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 1, 160, 226),
                  ),
                ),
              ),
            )
          : DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              underline: Container(),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Color.fromARGB(255, 1, 160, 226),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedType = newValue;
                    //_applyFilters();
                  });
                }
              },
              items: _expenseTypes.map<DropdownMenuItem<String>>((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverPage()),
          );

          // Prevent defaultR back behavior since we're handling navigation
        },
        child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverPage()),
            );
          },
        ),
        title: Text(
          '${Globals.getText('expenseLog')}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[100]!,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 16.0),
              // Filter Container
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    width: 1,
                    color: Colors.grey[300]!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${Globals.getText('logsDate')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 1, 160, 226),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _startDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                  : '${Globals.getText('logsFrom')}',
                            ),
                            onPressed: () => _selectStartDate(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _endDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                  : '${Globals.getText('logsTo')}',
                            ),
                            onPressed: () => _selectEndDate(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Globals.getText('vehicleDataType')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        buildTypeDropdown()
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 1, 160, 226),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          '${Globals.getText('logsApply')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              // Data Table Container
              _buildDataTable()
            ],
          ),
        ),
      ),
    )
    );
    
  }

  Widget _buildDataTable() {
    if (_isLoadingData) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            width: 1,
            color: Colors.grey[300]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 1, 160, 226),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${Globals.getText('loading')}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_filteredExpenseData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            width: 1,
            color: Colors.grey[300]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '${Globals.getText('noDataForDateAndType')}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          width: 1,
          color: Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 1, 160, 226),
          ),
          dataTextStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
          columnSpacing: 24,
          horizontalMargin: 12,
          columns: [
            DataColumn(
              label: Text(
                '${Globals.getText('logsTableVehicle')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const DataColumn(
              label: Text(
                'KM',
                style: TextStyle(color: Colors.black),
              ),
            ),
            DataColumn(
              label: Text(
                '${Globals.getText('vehicleDataBottomType')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            DataColumn(
              label: Text(
                '${Globals.getText('expenseSelectCost')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            DataColumn(
              label: Text(
                '${Globals.getText('expenseSelectAmount')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            DataColumn(
              label: Text(
                '${Globals.getText('logsTableTime')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            DataColumn(
              label: Text(
                '${Globals.getText('expenseSelectRemarks')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            DataColumn(
              label: Text(
                '${Globals.getText('vehicleDataBottomPhoto')}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
          rows: _filteredExpenseData.map((data) {
            return DataRow(
              cells: [
                DataCell(Text(data.vehicle)),
                DataCell(Text(data.km.toString())),
                DataCell(Text(data.type)),
                DataCell(Text(data.cost.toString())),
                DataCell(Text(data.amount.toString())),
                DataCell(Text(data.time)),
                DataCell(Text(data.remarks)),
                DataCell(
                  data.photo.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showImageDialog([data.photo]),
                          child: const Icon(
                            Icons.image,
                            color: Color.fromARGB(255, 1, 160, 226),
                          ),
                        )
                      : const Text('No photos'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

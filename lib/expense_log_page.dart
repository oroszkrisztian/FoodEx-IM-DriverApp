import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/widgets/expense_filter.dart';
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
  String _selectedType = 'all'; // Changed to lowercase
  List<String> _expenseTypes = ['all']; // Changed to lowercase
  bool _isLoadingTypes = true;
  DateTime? _startDate;
  DateTime? _endDate;
  final String baseUrl = 'https://vinczefi.com/';

  int totalLogs = 0;
  double totalCost = 0.0;
  double totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Initialize both expense types and data
  Future<void> _initializeData() async {
    await _loadExpenseTypes();
    //await _fetchExpenseData();
  }

  // Modified to store types in state with lowercase
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

        // Create the list of expense types in lowercase, including 'all' as the first option
        List<String> types = ['all'];
        types.addAll(jsonData
            .where((type) =>
                type is Map<String, dynamic> && type.containsKey('name'))
            .map((type) => type['name'].toString().toLowerCase())
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
        _expenseTypes = ['all'];
        _isLoadingTypes = false;
      });
    }
  }

  Future<void> _fetchExpenseData() async {
    setState(() {
      _isLoadingData = true;
    });

    String typeToSend = _selectedType.toLowerCase();

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
          'type': typeToSend,
          'driver': Globals.userId.toString(),
          'vehicle': Globals.vehicleID.toString(),
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        // Initialize with default values
        int logs = 0;
        double cost = 0.0;
        double amount = 0.0;

        // Handle totals from the response
        if (responseData['totals'] != null) {
          logs = int.tryParse(
                  responseData['totals']['nr_logs']?.toString() ?? '0') ??
              0;
          cost = double.tryParse(
                  responseData['totals']['total_cost']?.toString() ?? '0') ??
              0.0;
          amount = double.tryParse(
                  responseData['totals']['total_amount']?.toString() ?? '0') ??
              0.0;
        }

        setState(() {
          totalLogs = logs;
          totalCost = cost;
          totalAmount = amount;
          _expenseData = [];
          _filteredExpenseData = [];
          _isLoadingData = false;
        });

        // Only try to parse expense entries if there are any
        if (responseData is Map &&
            responseData.entries.any((e) => e.key != 'totals')) {
          List<ExpenseEntry> fetchedData = responseData.entries
              .where((e) => e.key != 'totals')
              .map((e) => ExpenseEntry.fromJson(e.value))
              .toList();

          // Sort the data by date (newest first)
          fetchedData.sort((a, b) {
            DateTime dateA = DateTime.tryParse(a.time) ?? DateTime(2000);
            DateTime dateB = DateTime.tryParse(b.time) ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });

          setState(() {
            _expenseData = fetchedData;
            _filteredExpenseData = fetchedData;
          });
        }
      } else {
        throw Exception('Failed to load expense data');
      }
    } catch (e) {
      print('Error in _fetchExpenseData: $e');
      setState(() {
        _isLoadingData = false;
        _expenseData = [];
        _filteredExpenseData = [];
        totalLogs = 0;
        totalCost = 0;
        totalAmount = 0;
      });
    }
  }

  @override
  void dispose() {
    // Clean up resources here
    super.dispose();
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

  Widget _buildSummaryCard() {
    // Convert selected type to lowercase for comparison
    String lowerType = _selectedType.toLowerCase();
    bool showAmount = lowerType == 'adblue' ||
        lowerType == 'üzemanyag/combustibil' ;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${Globals.getText('summary')}',
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
              _buildSummaryItem(
                Icons.list_alt,
                totalLogs.toString(),
                '${Globals.getText('totalLogs')}',
              ),
              _buildSummaryItem(
                Icons.attach_money,
                '${totalCost.toStringAsFixed(2)}',
                '${Globals.getText('totalCost')}',
              ),
              if (showAmount)
                _buildSummaryItem(
                  Icons.local_gas_station,
                  '${totalAmount.toStringAsFixed(2)}',
                  '${Globals.getText('totalAmount')}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color.fromARGB(255, 1, 160, 226),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverPage(),
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriverPage(),
                ),
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

                ExpenseFilterContainer(
                  startDate: _startDate,
                  endDate: _endDate,
                  expenseTypes: _expenseTypes,
                  selectedType: _selectedType,
                  isLoadingTypes: _isLoadingTypes,
                  onSelectStartDate: () => _selectStartDate(context),
                  onSelectEndDate: () => _selectEndDate(context),
                  onTypeChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedType = newValue;
                      });
                    }
                  },
                  onApplyFilters: _applyFilters,
                ),
                const SizedBox(height: 16.0),
                if (!_isLoadingData && _filteredExpenseData.isNotEmpty)
                  _buildSummaryCard(),
                const SizedBox(height: 16.0),
                // Data Table Container
                _buildDataTable()
              ],
            ),
          ),
        ),
      ),
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/my_routes_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';

class VehicleData {
  final int vehicleId;
  final String name;
  final String numberPlate;
  final int km;
  final String insuranceStartDate;
  final String insuranceEndDate;
  final bool? insuranceValidity;
  final String tuvStartDate;
  final String tuvEndDate;
  final bool? tuvValidity;
  final String oilStartDate;
  final int? oilUntilKm;
  final bool? oilValidity;

  VehicleData({
    required this.vehicleId,
    required this.name,
    required this.numberPlate,
    required this.km,
    required this.insuranceStartDate,
    required this.insuranceEndDate,
    this.insuranceValidity,
    required this.tuvStartDate,
    required this.tuvEndDate,
    this.tuvValidity,
    required this.oilStartDate,
    this.oilUntilKm,
    this.oilValidity,
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    return VehicleData(
      vehicleId: json['vehicle']['vehicle_id'] ?? 0,
      name: json['vehicle']['name'] ?? '',
      numberPlate: json['vehicle']['numberplate'] ?? '',
      km: json['vehicle']['km'] ?? 0,
      insuranceStartDate: json['insurance']['date_start'] ?? '',
      insuranceEndDate: json['insurance']['date_end'] ?? '',
      insuranceValidity: _parseValidity(json['insurance']['validity']),
      tuvStartDate: json['tuv']['date_start'] ?? '',
      tuvEndDate: json['tuv']['date_end'] ?? '',
      tuvValidity: _parseValidity(json['tuv']['validity']),
      oilStartDate: json['oil']['date_start'] ?? '',
      oilUntilKm: json['oil']['until'] ?? 0,
      oilValidity: null, // This will be calculated later
    );
  }

  static bool? _parseValidity(String? value) {
    if (value == null) return null;
    return value.toLowerCase() == 'valid';
  }

  bool isOilValid() {
    if (oilUntilKm == null) return false;
    return km <= oilUntilKm!;
  }
}

class VehicleEntry {
  final int id;
  final String make;
  final String model;
  final String licensePlate;
  final String type;
  final int mileage;
  final String startDate;
  final String endDate;
  final String details;
  final String photo;

  VehicleEntry({
    required this.id,
    required this.make,
    required this.model,
    required this.licensePlate,
    required this.type,
    required this.mileage,
    required this.startDate,
    required this.endDate,
    required this.details,
    required this.photo,
  });

  factory VehicleEntry.fromJson(Map<String, dynamic> json) {
    return VehicleEntry(
      id: json['id'] ?? 0,
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      licensePlate: json['license_plate'] ?? '',
      type: json['type'] ?? '',
      mileage: json['mileage'] ?? 0,
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      details: json['details'] ?? '',
      photo: json['photo'] ?? '',
    );
  }
}

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VehicleDataPage(),
    ),
  );
}

class VehicleDataPage extends StatefulWidget {
  const VehicleDataPage({super.key});

  @override
  _VehicleDataPageState createState() => _VehicleDataPageState();
}

class _VehicleDataPageState extends State<VehicleDataPage> {
  Future<VehicleData>? _vehicleDataFuture;
  VehicleData? _selectedCar;
  Timer? _timer;
  bool _dataLoaded = false;
  List<VehicleEntry> _vehicleData = [];
  List<VehicleEntry> _filteredVehicleData = [];
  String _selectedStatus = 'All';
  String _selectedType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  final String baseUrl = 'https://vinczefi.com'; // Define your base URL here

  @override
  void initState() {
    super.initState();
    _fetchVehicleData(); // Fetch data initially
    _checkLoginStatus();
  }

  Future<VehicleData> fetchVehicleData() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'driver-vehicle-data',
          'driver': Globals.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        var jsonData = jsonDecode(response.body);
        _dataLoaded = true;
        return VehicleData.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to load vehicle data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to load vehicle data: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    setState(() {});

    if (isLoggedIn && Globals.vehicleID != null) {
      _vehicleDataFuture = fetchVehicleData();
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_dataLoaded) {
          setState(() {
            _vehicleDataFuture = fetchVehicleData();
          });
        } else {
          _timer?.cancel();
        }
      });
    }
  }

  // Helper function to get the display text for status
  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'All':
        return Globals.getText('vehicleDataStatusSelect');
      case 'Active':
        return Globals.getText('vehicleDataStatusSelectActive');
      case 'Expired':
        return Globals.getText('vehicleDataStatusSelectExpired');
      default:
        return status;
    }
  }

// Helper function to get the display text for type
  String _getTypeDisplayText(String type) {
    switch (type) {
      case 'All':
        return Globals.getText('vehicleDataTypeSelectAll');
      case 'Oil':
        return Globals.getText('vehicleDataTypeSelectOil');
      case 'TUV':
        return Globals.getText('vehicleDataTypeSelectTUV');
      case 'Insurance':
        return Globals.getText('vehicleDataTypeSelectInsurance');
      default:
        return type;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchVehicleData() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'vehicle-data-filter',
          'from': _startDate != null
              ? DateFormat('yyyy-MM-dd').format(_startDate!)
              : '',
          'to': _endDate != null
              ? DateFormat('yyyy-MM-dd').format(_endDate!)
              : '',
          'status': _selectedStatus.toLowerCase(),
          'type': _selectedType.toLowerCase(),
          'vehicle': Globals.vehicleID?.toString() ?? 'all',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<VehicleEntry> fetchedData =
            responseData.map((data) => VehicleEntry.fromJson(data)).toList();

        _vehicleData = fetchedData;

        _filterData();

        setState(() {
          _filteredVehicleData = _vehicleData;
        });

        print('Response Body _fetchVehicleData: ${response.body}');
      } else {
        _showErrorDialog('Failed to load vehicle data',
            'Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to load vehicle data: $e');
    }
  }

  void _filterData() {
    setState(() {
      _filteredVehicleData = _vehicleData.where((vehicle) {
        DateTime startDate =
            DateTime.tryParse(vehicle.startDate) ?? DateTime(2000);
        DateTime endDate = DateTime.tryParse(vehicle.endDate) ?? DateTime(2100);
        if (_startDate != null && startDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && endDate.isAfter(_endDate!)) {
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
    _fetchVehicleData().then((_) {
      setState(() {
        _filteredVehicleData.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a.endDate) ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b.endDate) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      });
    });
  }

  void _filterByStatus(String status) {
    setState(() {
      _selectedStatus = status;
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

  void _showImage(String photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isBase64 = photo.startsWith('data:image');
        String imageUrl = isBase64
            ? photo
            : '$baseUrl/$photo'; // Append base URL if it's not a base64 string

        print('Image URL: $imageUrl');
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InteractiveViewer(
                    child: isBase64
                        ? Image.memory(
                            base64Decode(photo.split(',').last),
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.error);
                            },
                          )
                        : Image.network(
                            imageUrl,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.error);
                            },
                          ),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget _buildImagePreviewButton(String label, File? image1) {
  //   return ElevatedButton(
  //     onPressed: () => _showImage1(image1),
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: Colors.white,
  //       foregroundColor: Colors.black,
  //       side:
  //           const BorderSide(color: Color.fromARGB(255, 1, 160, 226), width: 1),
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(8.0),
  //       ),
  //     ),
  //     child: Text(label, style: const TextStyle(color: Colors.black)),
  //   );
  // }

  //moved items
  void _showImage1(File? image1) {
    if (image1 == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('No Picture'),
            content: const Text('There is no picture available.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight *
                            0.8, // Adjust the value as needed
                      ),
                      child: Image.file(
                        image1,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                            255, 1, 160, 226), // Light blue color
                        foregroundColor: Colors.white, // White text
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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

                if (startDate != null && endDate != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyRoutesPage(
                        startDate: startDate,
                        endDate: endDate,
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
            title: Text(
              '${Globals.getText('vehicleData')}',
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
              child: FutureBuilder<VehicleData>(
                future: _vehicleDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 1, 160, 226),
                          ),
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No data found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  VehicleData vehicleData = snapshot.data!;
                  _selectedCar = vehicleData;

                  return Column(
                    children: [
                      // Vehicle Information Table
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        padding: const EdgeInsets.all(16.0),
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
                            SingleChildScrollView(
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
                                      '${Globals.getText('vehicleDataTopType')}',
                                      style:
                                          const TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataTopStartDate')}',
                                      style:
                                          const TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataTopUntil')}',
                                      style:
                                          const TextStyle(color: Colors.black),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataTopStatus')}',
                                      style:
                                          const TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ],
                                rows: [
                                  DataRow(cells: [
                                    DataCell(Text(
                                        '${Globals.getText('vehicleDataTopInsurance')}')),
                                    DataCell(
                                        Text(vehicleData.insuranceStartDate)),
                                    DataCell(
                                        Text(vehicleData.insuranceEndDate)),
                                    DataCell(Text(
                                      vehicleData.insuranceValidity != null &&
                                              vehicleData.insuranceValidity!
                                          ? '${Globals.getText('vehicleDataTopStatusValid')}'
                                          : '${Globals.getText('vehicleDataTopStatusExpired')}',
                                      style: TextStyle(
                                        color: vehicleData.insuranceValidity !=
                                                    null &&
                                                vehicleData.insuranceValidity!
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    )),
                                  ]),
                                  DataRow(cells: [
                                    DataCell(Text(
                                        '${Globals.getText('vehicleDataTopTUV')}')),
                                    DataCell(Text(vehicleData.tuvStartDate)),
                                    DataCell(Text(vehicleData.tuvEndDate)),
                                    DataCell(Text(
                                      vehicleData.tuvValidity != null &&
                                              vehicleData.tuvValidity!
                                          ? '${Globals.getText('vehicleDataTopStatusValid')}'
                                          : '${Globals.getText('vehicleDataTopStatusExpired')}',
                                      style: TextStyle(
                                        color:
                                            vehicleData.tuvValidity != null &&
                                                    vehicleData.tuvValidity!
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    )),
                                  ]),
                                  DataRow(cells: [
                                    DataCell(Text(
                                        '${Globals.getText('vehicleDataTopOil')}')),
                                    DataCell(Text(vehicleData.oilStartDate)),
                                    DataCell(Text(
                                        '${vehicleData.oilUntilKm ?? 'N/A'} km')),
                                    DataCell(Text(
                                      vehicleData.isOilValid()
                                          ? '${Globals.getText('vehicleDataTopStatusValid')}'
                                          : '${Globals.getText('vehicleDataTopStatusExpired')}',
                                      style: TextStyle(
                                        color: vehicleData.isOilValid()
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    )),
                                  ]),
                                  DataRow(cells: [
                                    DataCell(Text(
                                        '${Globals.getText('vehicleDataTopKM')}')),
                                    DataCell(Text(vehicleData.km.toString())),
                                    const DataCell(Text('')),
                                    const DataCell(Text('')),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vehicle Photos Section
                      if (Globals.image1 != null ||
                          Globals.image2 != null ||
                          Globals.image3 != null ||
                          Globals.image4 != null ||
                          Globals.image5 != null)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16.0),
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
                            children: [
                              const Text(
                                'Vehicle Photos',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 1, 160, 226),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildImagePreviewButton(
                                  'Dashboard', Globals.image1),
                              const SizedBox(height: 8.0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildImagePreviewButton(
                                      'Front Left', Globals.image2),
                                  _buildImagePreviewButton(
                                      'Front Right', Globals.image3),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildImagePreviewButton(
                                      'Rear Left', Globals.image4),
                                  _buildImagePreviewButton(
                                      'Rear Right', Globals.image5),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // Filter Section
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
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.calendar_today,
                                        size: 18),
                                    label: Text(
                                      _startDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(_startDate!)
                                          : '${Globals.getText('vehicleDataFrom')}',
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
                                    icon: const Icon(Icons.calendar_today,
                                        size: 18),
                                    label: Text(
                                      _endDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(_endDate!)
                                          : '${Globals.getText('vehicleDataTo')}',
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _buildFilterDropdown(
                                    label:
                                        '${Globals.getText('vehicleDataStatus')}',
                                    value: _selectedStatus,
                                    items: ['All', 'Active', 'Expired'],
                                    onChanged: _filterByStatus,
                                    getDisplayText: _getStatusDisplayText,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFilterDropdown(
                                    label:
                                        '${Globals.getText('vehicleDataType')}',
                                    value: _selectedType,
                                    items: ['All', 'Oil', 'TUV', 'Insurance'],
                                    onChanged: _filterByType,
                                    getDisplayText: _getTypeDisplayText,
                                  ),
                                ),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                child: Text(
                                  '${Globals.getText('vehicleDataApply')}',
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
                      // Results Table
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
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
                                      '${Globals.getText('vehicleDataBottomId')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomMake')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomModel')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomLicensePlate')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomType')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomMileage')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomStartDate')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomEndDate')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomDetails')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      '${Globals.getText('vehicleDataBottomPhoto')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: _filteredVehicleData.map((data) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(data.id.toString())),
                                      DataCell(Text(data.make)),
                                      DataCell(Text(data.model)),
                                      DataCell(Text(data.licensePlate)),
                                      DataCell(Text(data.type)),
                                      DataCell(Text(data.mileage.toString())),
                                      DataCell(Text(data.startDate)),
                                      DataCell(Text(data.endDate)),
                                      DataCell(Text(data.details)),
                                      DataCell(
                                        data.photo.isNotEmpty
                                            ? GestureDetector(
                                                onTap: () =>
                                                    _showImage(data.photo),
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Color.fromARGB(
                                                      255, 1, 160, 226),
                                                ),
                                              )
                                            : const Text('No photos'),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ));
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    required String Function(String) getDisplayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: Container(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Color.fromARGB(255, 1, 160, 226),
            ),
            onChanged: (newValue) => onChanged(newValue!),
            items: items
                .map((item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        getDisplayText(item),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewButton(String label, File? image) {
    return ElevatedButton(
      onPressed: () => _showImage1(image),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(
          color: Color.fromARGB(255, 1, 160, 226),
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
        ),
      ),
    );
  }
}

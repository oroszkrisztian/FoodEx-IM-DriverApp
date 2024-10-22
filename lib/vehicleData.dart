import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

  Widget _buildImagePreviewButton(String label, File? image1) {
    return ElevatedButton(
      onPressed: () => _showImage1(image1),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side:
            const BorderSide(color: Color.fromARGB(255, 1, 160, 226), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }

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

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Vehicle Data', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<VehicleData>(
          future: _vehicleDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData) {
              return const Center(child: Text('No data found.'));
            } else {
              VehicleData vehicleData = snapshot.data!;
              _selectedCar = vehicleData;

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        width: 1,
                        color: Colors.black,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.6),
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
                              label: Text('Type',
                                  style: TextStyle(color: Colors.black))),
                          DataColumn(
                              label: Text('Start Date',
                                  style: TextStyle(color: Colors.black))),
                          DataColumn(
                              label: Text('Until',
                                  style: TextStyle(color: Colors.black))),
                          DataColumn(
                              label: Text('Status',
                                  style: TextStyle(color: Colors.black))),
                        ],
                        rows: [
                          DataRow(cells: [
                            const DataCell(Text('Insurance')),
                            DataCell(Text(vehicleData.insuranceStartDate)),
                            DataCell(Text(vehicleData.insuranceEndDate)),
                            DataCell(Text(
                              vehicleData.insuranceValidity != null &&
                                      vehicleData.insuranceValidity!
                                  ? 'VALID'
                                  : 'EXPIRED',
                              style: TextStyle(
                                color: vehicleData.insuranceValidity != null &&
                                        vehicleData.insuranceValidity!
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            )),
                          ]),
                          DataRow(cells: [
                            const DataCell(Text('TUV')),
                            DataCell(Text(vehicleData.tuvStartDate)),
                            DataCell(Text(vehicleData.tuvEndDate)),
                            DataCell(Text(
                              vehicleData.tuvValidity != null &&
                                      vehicleData.tuvValidity!
                                  ? 'VALID'
                                  : 'EXPIRED',
                              style: TextStyle(
                                color: vehicleData.tuvValidity != null &&
                                        vehicleData.tuvValidity!
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            )),
                          ]),
                          DataRow(cells: [
                            const DataCell(Text('Oil')),
                            DataCell(Text(vehicleData.oilStartDate)),
                            DataCell(
                                Text('${vehicleData.oilUntilKm ?? 'N/A'} km')),
                            DataCell(Text(
                              vehicleData.isOilValid() ? 'VALID' : 'EXPIRED',
                              style: TextStyle(
                                color: vehicleData.isOilValid()
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            )),
                          ]),
                          DataRow(cells: [
                            const DataCell(Text('KM')),
                            DataCell(Text(vehicleData.km.toString())),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  // Filter Container
                  const SizedBox(height: 16),
                  if (Globals.image1 != null ||
                      Globals.image2 != null ||
                      Globals.image3 != null ||
                      Globals.image4 != null ||
                      Globals.image5 != null)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
                            color: Colors.grey.withOpacity(0.6),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Pictures',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildImagePreviewButton('Dashboard', Globals.image1),
                          const SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildImagePreviewButton(
                                  'Front Left', Globals.image2),
                              _buildImagePreviewButton(
                                  'Front Right', Globals.image3),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                    ? DateFormat('yyyy-MM-dd')
                                        .format(_startDate!)
                                    : 'From',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.0,
                                      color: Colors.black),
                                ),
                                const SizedBox(height: 8.0),
                                DropdownButton<String>(
                                  value: _selectedStatus,
                                  onChanged: (value) {
                                    _filterByStatus(value!);
                                  },
                                  items: ['All', 'Active', 'Expired']
                                      .map((status) => DropdownMenuItem<String>(
                                            value: status,
                                            child: Text(status,
                                                style: const TextStyle(
                                                    color: Colors.black)),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16.0),
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
                                  items: ['All', 'Oil', 'TUV', 'Insurance']
                                      .map((type) => DropdownMenuItem<String>(
                                            value: type,
                                            child: Text(type,
                                                style: const TextStyle(
                                                    color: Colors.black)),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 1, 160, 226),
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
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Make',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Model',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'License Plate',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Type',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Mileage',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Start Date',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'End Date',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Details',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Photo',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
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
                                        onTap: () => _showImage(data.photo),
                                        child: const Icon(
                                          Icons.image,
                                          color:
                                              Color.fromARGB(255, 1, 160, 226),
                                        ),
                                      )
                                    : const Text('No photos'),
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
          },
        ),
      ),
    );
  }
}

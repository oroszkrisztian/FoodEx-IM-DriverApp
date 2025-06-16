import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/my_routes_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';
import 'package:foodex/services/carService.dart'; // Updated import to match your structure
import 'package:foodex/models/cars.dart'; // Import Car model

class VehicleDataPage extends StatefulWidget {
  const VehicleDataPage({super.key});

  @override
  _VehicleDataPageState createState() => _VehicleDataPageState();
}

class _VehicleDataPageState extends State<VehicleDataPage> {
  final CarInformation _carInformation = CarInformation();
  Future<VehicleData>? _vehicleDataFuture;
  VehicleData? _selectedCarData; // This holds the detailed vehicle data
  Timer? _timer;
  bool _dataLoaded = false;
  List<VehicleEntry> _vehicleData = [];
  List<VehicleEntry> _filteredVehicleData = [];
  String _selectedStatus = 'All';
  String _selectedType = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  final String baseUrl = 'https://vinczefi.com'; // Define your base URL here
  bool _isTableVisible = true;
  bool _isFilterVisible = false;
  // bool _isMaintenanceVisible = true; // Removed maintenance visibility variable

  // Car selection variables
  List<Car> _cars = [];
  Car? _selectedCar; // This holds the selected car from dropdown
  bool _isLoadingCars = true;

  @override
  void initState() {
    super.initState();

    // Auto-fill dates from 1st of current month until today
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    _startDate = firstDayOfMonth;
    _endDate = now;

    _loadCars();
  }

  Future<void> _loadCars() async {
    try {
      setState(() {
        _isLoadingCars = true;
      });

      List<Car> cars = await _carInformation.getCars();
      setState(() {
        _cars = cars;
        _isLoadingCars = false;

        // Set initial selected car
        if (Globals.vehicleID != null && _cars.isNotEmpty) {
          // Try to find the car from Globals
          try {
            _selectedCar = _cars.firstWhere(
              (car) => car.id == Globals.vehicleID,
            );
          } catch (e) {
            // If car with Globals.vehicleID not found, use first car
            _selectedCar = _cars.first;
            // Update Globals to match the selected car
            Globals.vehicleID = _cars.first.id;
          }
        } else if (_cars.isNotEmpty) {
          // Select first car if available and update Globals
          _selectedCar = _cars.first;
          Globals.vehicleID = _cars.first.id;
        } else {
          // No cars available
          _selectedCar = null;
          Globals.vehicleID = null;
        }

        // Load vehicle data for selected car
        if (_selectedCar != null) {
          _initializeData();
        }
      });
    } catch (e) {
      print('Error loading cars: $e');
      setState(() {
        _isLoadingCars = false;
      });
      _showErrorDialog('Error', 'Failed to load vehicles: $e');
    }
  }

  Future<void> _onCarSelectionChanged(Car? newCar) async {
    if (newCar != null && newCar != _selectedCar) {
      setState(() {
        _selectedCar = newCar;
        Globals.vehicleID = newCar.id != -1 ? newCar.id : null;
      });

      // Reload vehicle data for new selection
      if (newCar.id != -1) {
        await _initializeData();
        await _fetchVehicleData();
      } else {
        // Clear data if "All Vehicles" is selected
        setState(() {
          _vehicleDataFuture = null;
          _selectedCarData = null;
        });
        await _fetchVehicleData();
      }
    }
  }

  Future<void> _initializeData() async {
    if (Globals.vehicleID != null) {
      _vehicleDataFuture = _carInformation.getVehicleData(Globals.vehicleID!);
    } else if (_selectedCar != null && _selectedCar!.id != -1) {
      _vehicleDataFuture = _carInformation.getVehicleData(_selectedCar!.id);
      // Update Globals with the first car's ID
      Globals.vehicleID = _selectedCar!.id;
    }
    await _fetchVehicleData();
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
      List<VehicleEntry> fetchedData =
          await _carInformation.getFilteredVehicleData(
        startDate: _startDate,
        endDate: _endDate,
        status: _selectedStatus,
        type: _selectedType,
        vehicleId: _selectedCar?.id != -1 ? _selectedCar?.id : null,
      );

      setState(() {
        _vehicleData = fetchedData;
        _filteredVehicleData = _carInformation.filterVehicleEntriesByDate(
          _vehicleData,
          _startDate,
          _endDate,
        );
      });

      print('Fetched ${fetchedData.length} vehicle entries');
    } catch (e) {
      _showErrorDialog('Error', 'Failed to load vehicle data: $e');
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

  void _applyFilters() {
    _fetchVehicleData().then((_) {
      setState(() {
        _filteredVehicleData = _carInformation.sortVehicleEntriesByDate(
          _filteredVehicleData,
          descending: true,
        );
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
                    child: Text('${Globals.getText('close')}'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleSelectionCard() {
    // Filter out cars with model "Livezeni 18"
    final filteredCars =
        _cars.where((car) => car.model != "Livezeni 18").toList();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_car,
                color: Color.fromARGB(255, 1, 160, 226),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${Globals.getText('loginVehicleSelect')}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 1, 160, 226),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingCars
              ? Container(
                  height: 56,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 1, 160, 226),
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<Car>(
                    value: _selectedCar?.model == "Livezeni 18"
                        ? null
                        : _selectedCar,
                    isExpanded: true,
                    underline: Container(),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color.fromARGB(255, 1, 160, 226),
                    ),
                    hint: Text('${Globals.getText('loginVehicleSelect')}'),
                    onChanged: _onCarSelectionChanged,
                    items: [
                      ...filteredCars.map((car) => DropdownMenuItem<Car>(
                            value: car,
                            child: Text(
                              '${car.make} ${car.model} - ${car.licencePlate}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
        ],
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
              child: Column(
                children: [
                  // Vehicle Selection Dropdown - ALWAYS VISIBLE
                  _buildVehicleSelectionCard(),

                  // Show content only if not loading cars and vehicle data is ready
                  if (!_isLoadingCars) ...[
                    // Vehicle Information Table (only show if specific car is selected)
                    if (_selectedCar != null && _selectedCar!.id != -1)
                      FutureBuilder<VehicleData>(
                        future: _vehicleDataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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
                                child: Column(
                                  children: [
                                    Text(
                                      'Error: ${snapshot.error}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_selectedCar != null &&
                                              _selectedCar!.id != -1) {
                                            _vehicleDataFuture =
                                                _carInformation.getVehicleData(
                                                    _selectedCar!.id);
                                          }
                                        });
                                      },
                                      child:
                                          Text('${Globals.getText('retry')}'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (!snapshot.hasData) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  '${Globals.getText('noDataFound')}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          }

                          VehicleData vehicleData = snapshot.data!;
                          _selectedCarData = vehicleData;

                          return _buildVehicleInfoTable(vehicleData);
                        },
                      ),

                    // Filter Section
                    _buildFiltersSection(),

                    // Results Table
                    _buildMaintenanceRecordsTable(),
                  ],
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildVehicleInfoTable(VehicleData vehicleData) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
          GestureDetector(
            onTap: () {
              setState(() {
                _isTableVisible = !_isTableVisible;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${Globals.getText('vehicleDataInfo')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 1, 160, 226),
                      ),
                    ),
                  ),
                  Icon(
                    _isTableVisible ? Icons.expand_less : Icons.expand_more,
                    color: const Color.fromARGB(255, 1, 160, 226),
                  ),
                ],
              ),
            ),
          ),
          if (_isTableVisible) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        '${Globals.getText('vehicleDataTopType')}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '${Globals.getText('vehicleDataTopStartDate')}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '${Globals.getText('vehicleDataTopUntil')}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '${Globals.getText('vehicleDataTopStatus')}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                  rows: [
                    DataRow(cells: [
                      DataCell(Text(
                          '${Globals.getText('vehicleDataTopInsurance')}')),
                      DataCell(Text(vehicleData.insuranceStartDate)),
                      DataCell(Text(vehicleData.insuranceEndDate)),
                      DataCell(Text(
                        vehicleData.insuranceValidity != null &&
                                vehicleData.insuranceValidity!
                            ? '${Globals.getText('vehicleDataTopStatusValid')}'
                            : '${Globals.getText('vehicleDataTopStatusExpired')}',
                        style: TextStyle(
                          color: vehicleData.insuranceValidity != null &&
                                  vehicleData.insuranceValidity!
                              ? Colors.green
                              : Colors.red,
                        ),
                      )),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('${Globals.getText('vehicleDataTopTUV')}')),
                      DataCell(Text(vehicleData.tuvStartDate)),
                      DataCell(Text(vehicleData.tuvEndDate)),
                      DataCell(Text(
                        vehicleData.tuvValidity != null &&
                                vehicleData.tuvValidity!
                            ? '${Globals.getText('vehicleDataTopStatusValid')}'
                            : '${Globals.getText('vehicleDataTopStatusExpired')}',
                        style: TextStyle(
                          color: vehicleData.tuvValidity != null &&
                                  vehicleData.tuvValidity!
                              ? Colors.green
                              : Colors.red,
                        ),
                      )),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('${Globals.getText('vehicleDataTopOil')}')),
                      DataCell(Text(vehicleData.oilStartDate)),
                      DataCell(Text('${vehicleData.oilUntilKm ?? 'N/A'} km')),
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
                      DataCell(Text('${Globals.getText('vehicleDataTopKM')}')),
                      DataCell(Text(vehicleData.km.toString())),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text(
                          '${Globals.getText('vehicleDataTopConsumption')}')),
                      DataCell(Text('${vehicleData.consumption} l/100km')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
          GestureDetector(
            onTap: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${Globals.getText('logsApply')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 1, 160, 226),
                      ),
                    ),
                  ),
                  if (_startDate != null && _endDate != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 1, 160, 226)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromARGB(255, 1, 160, 226)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  Icon(
                    _isFilterVisible ? Icons.expand_less : Icons.expand_more,
                    color: const Color.fromARGB(255, 1, 160, 226),
                  ),
                ],
              ),
            ),
          ),
          if (_isFilterVisible) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
              child: Column(
                children: [
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
                              side: BorderSide(color: Colors.grey[300]!),
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
                              side: BorderSide(color: Colors.grey[300]!),
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
                          label: '${Globals.getText('vehicleDataStatus')}',
                          value: _selectedStatus,
                          items: ['All', 'Active', 'Expired'],
                          onChanged: _filterByStatus,
                          getDisplayText: _getStatusDisplayText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterDropdown(
                          label: '${Globals.getText('vehicleDataType')}',
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
                        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
          ],
        ],
      ),
    );
  }

  Widget _buildMaintenanceRecordsTable() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${Globals.getText('myLogs')}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 1, 160, 226),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: const Color.fromARGB(255, 1, 160, 226),
                  size: 20,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Add this conditional check for empty data
                if (_filteredVehicleData.isEmpty)
                  Center(
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
                  )
                else
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
                                      onTap: () => _showImage(data.photo),
                                      child: const Icon(
                                        Icons.image,
                                        color: Color.fromARGB(255, 1, 160, 226),
                                      ),
                                    )
                                  : const Icon(Icons.no_photography,
                                      color: Colors.grey),
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
      ),
    );
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
}

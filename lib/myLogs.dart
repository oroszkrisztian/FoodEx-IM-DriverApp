import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart'; // Assuming you have a globals.dart file for global variables

class LogEntry {
  final String inShiftDate;
  final String outShiftDate;
  final String vehicle;
  final String driver;
  final String from;
  final String to;
  final String totalTime;
  final int startKm;
  final int endKm;
  final String kmDifference;
  final List<String> photos;

  LogEntry({
    required this.inShiftDate,
    required this.outShiftDate,
    required this.vehicle,
    required this.driver,
    required this.from,
    required this.to,
    required this.totalTime,
    required this.startKm,
    required this.endKm,
    required this.kmDifference,
    required this.photos,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      inShiftDate: json['in_shift_date'] ?? '',
      outShiftDate: json['out_shift_date'] ?? '',
      vehicle: json['vehicle'] ?? '',
      driver: json['driver'] ?? '',
      from: json['shift_start'] ?? '',
      to: json['shift_end'] ?? '',
      totalTime: json['time_spent'] ?? '',
      startKm: json['km_start'] ?? 0,
      endKm: json['km_end'] ?? 0,
      kmDifference: (json['km_difference']?.toString() ?? '0') + ' km',
      photos: (json['photos'] ?? '')
          .toString()
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  String calculateKmDifference() {
    return kmDifference;
  }
}

class Car {
  final int id;
  final String make;
  final String model;
  final String licencePlate;

  Car({
    required this.id,
    required this.make,
    required this.model,
    required this.licencePlate,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as int,
      make: json['make'] as String,
      model: json['model'] as String,
      licencePlate:
          json['license_plate'] as String, // Adjusted to match backend
    );
  }
}

class MyLogPage extends StatefulWidget {
  const MyLogPage({super.key});

  @override
  State<MyLogPage> createState() => _MyLogPageState();
}

class _MyLogPageState extends State<MyLogPage> {
  List<LogEntry> _logData = [];
  List<LogEntry> _filteredLogData = [];
  List<Car> _cars = [];
  String? _errorMessage;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedCarId;
  bool _isLoading = false;

  final String baseUrl = 'https://vinczefi.com/'; // Define your base URL here

  @override
  void initState() {
    super.initState();
    _selectedCarId = -1; // Default to "All Vehicles"
    getCars();
  }

  Future<void> getCars() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${baseUrl}foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-cars',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          var jsonResponse = jsonDecode(response.body);

          // Check if jsonResponse is a list
          if (jsonResponse is List) {
            List<Car> cars = jsonResponse
                .map((json) => Car.fromJson(json as Map<String, dynamic>))
                .toList();

            // Add "All Vehicles" option
            cars.insert(
                0,
                Car(
                  id: -1,
                  make: 'All Vehicles',
                  model: '',
                  licencePlate: '',
                ));

            setState(() {
              _cars = cars;
              _isLoading = false;
            });
          } else if (jsonResponse is Map) {
            // Handle the case where the response is a map
            setState(() {
              _errorMessage = 'Unexpected data format';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'No cars data received.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load cars: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching cars: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLogData() async {
    if (_startDate == null || _endDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${baseUrl}foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'vehicle-logs-filter',
          'from': DateFormat('yyyy-MM-dd').format(_startDate!),
          'to': DateFormat('yyyy-MM-dd').format(_endDate!),
          'vehicle': _selectedCarId == -1
              ? 'all'
              : _selectedCarId.toString(), // Convert to String
          'driver': Globals.userId == null
              ? 'all'
              : Globals.userId.toString(), // Convert to String
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print(response.body);
        // Check for valid response structure
        if (jsonResponse is List) {
          setState(() {
            _logData = jsonResponse
                .map((data) => LogEntry.fromJson(data as Map<String, dynamic>))
                .toList();
            _sortLogData();
            _filteredLogData = _logData;
            _filterByDate();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Unexpected response format';
            _isLoading = false;
          });
        }
      } else {
        _showErrorDialog(
            'Failed to load logs', 'Status code: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortLogData() {
    _logData.sort((a, b) {
      DateTime dateTimeA =
          DateFormat('yyyy-MM-dd HH:mm').parse('${a.inShiftDate} ${a.from}');
      DateTime dateTimeB =
          DateFormat('yyyy-MM-dd HH:mm').parse('${b.inShiftDate} ${b.from}');
      return dateTimeB.compareTo(dateTimeA);
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

  void _filterByDate() {
    setState(() {
      if (_startDate == null && _endDate == null) {
        _filteredLogData = _logData;
      } else {
        _filteredLogData = _logData.where((log) {
          DateTime logDate = DateFormat('yyyy-MM-dd').parse(log.inShiftDate);
          if (_startDate != null && logDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null && logDate.isAfter(_endDate!)) {
            return false;
          }
          return true;
        }).toList();
      }
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
              primary: Color.fromARGB(255, 1, 160, 226), // Blue theme color
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
              primary: Color.fromARGB(255, 1, 160, 226), // Blue theme color
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

  void _applyFilters() {
    _fetchLogData().then((_) {
      setState(() {
        _filteredLogData.sort((a, b) {
          DateTime dateTimeA = DateFormat('yyyy-MM-dd HH:mm')
              .parse('${a.inShiftDate} ${a.from}');
          DateTime dateTimeB = DateFormat('yyyy-MM-dd HH:mm')
              .parse('${b.inShiftDate} ${b.from}');
          return dateTimeB.compareTo(dateTimeA);
        });
      });
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedCarId = -1; // Reset to "All Vehicles"
      _filteredLogData = _logData;
    });
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

                      // Print the full image URL to the console
                      print('Image URL: $imageUrl');

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
        title: const Text('My Logs', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor:
            const Color.fromARGB(255, 1, 160, 226), // Blue theme color
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16.0),
                  DateSelectionContainer(
                    startDate: _startDate,
                    endDate: _endDate,
                    cars: _cars,
                    selectedCarId: _selectedCarId,
                    onSelectStartDate: () => _selectStartDate(context),
                    onSelectEndDate: () => _selectEndDate(context),
                    onVehicleChanged: (newValue) {
                      setState(() {
                        _selectedCarId = newValue;
                      });
                    },
                    onApplyFilters: _applyFilters,
                  ),
                  const SizedBox(height: 16.0),
                  LogDataTable(
                    logData: _filteredLogData,
                    onImageTap: _showImageDialog,
                  ),
                ],
              ),
            ),
    );
  }
}

class DateSelectionContainer extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<Car> cars;
  final int? selectedCarId;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<int?> onVehicleChanged;
  final VoidCallback onApplyFilters;

  const DateSelectionContainer({
    super.key,
    this.startDate,
    this.endDate,
    required this.cars,
    this.selectedCarId,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onVehicleChanged,
    required this.onApplyFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onSelectStartDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: Text(
                  startDate == null
                      ? 'From'
                      : DateFormat('yyyy-MM-dd').format(startDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16.0),
              ElevatedButton(
                onPressed: onSelectEndDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: Text(
                  endDate == null
                      ? 'To'
                      : DateFormat('yyyy-MM-dd').format(endDate!),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Vehicles',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          const SizedBox(height: 8.0),
          Center(
            child: DropdownButton<int>(
              value: selectedCarId,
              onChanged: onVehicleChanged,
              items: cars.map((Car cars) {
                return DropdownMenuItem<int>(
                  value: cars.id,
                  child: Text(
                    cars.id == -1
                        ? 'All Vehicles'
                        : '${cars.make} ${cars.model} - ${cars.licencePlate}',
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              }).toList(),
              hint: Text(
                selectedCarId == null
                    ? 'Select Car'
                    : cars.firstWhere((car) => car.id == selectedCarId).make,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
              dropdownColor: Colors.white,
              underline: Container(
                height: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Center(
            child: ElevatedButton(
              onPressed: onApplyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color.fromARGB(255, 1, 160, 226), // Blue theme color
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
          ),
        ],
      ),
    );
  }
}

class LogDataTable extends StatelessWidget {
  final List<LogEntry> logData;
  final ValueChanged<List<String>> onImageTap;

  const LogDataTable({
    super.key,
    required this.logData,
    required this.onImageTap,
  });

  String formatDateTime(String date, String time) {
    try {
      // Combine date and time
      DateTime dateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$date $time');
      // Format to show both date and time
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return '$date $time'; // Fallback if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                label: Text('Date',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Vehicle',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Driver',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('From',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('To',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Time',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Start KM',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('End KM',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Difference',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Photos',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: logData.map((log) {
            return DataRow(
              cells: [
                DataCell(Text(log.inShiftDate)),
                DataCell(Text(log.vehicle)),
                DataCell(Text(log.driver)),
                DataCell(Text(formatDateTime(log.inShiftDate, log.from))),
                DataCell(Text(formatDateTime(log.outShiftDate, log.to))),
                DataCell(Text(log.totalTime)),
                DataCell(Text(log.startKm.toString())),
                DataCell(Text(log.endKm.toString())),
                DataCell(Text(log.kmDifference)),
                DataCell(
                  log.photos.isNotEmpty
                      ? GestureDetector(
                          onTap: () => onImageTap(log.photos),
                          child: const Icon(
                            Icons.image,
                            color: Color.fromARGB(255, 1, 160, 226),
                          ),
                        )
                      : const Icon(Icons.no_photography, color: Colors.grey),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
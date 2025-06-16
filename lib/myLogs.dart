import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/models/summary.dart';
import 'package:foodex/services/carService.dart';
import 'package:foodex/widgets/logs_summary_card.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'globals.dart';
import 'models/cars.dart';

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
  LogSummary _summary = LogSummary.empty();

  // Create instance of CarInformation service
  final CarInformation _carService = CarInformation();

  final String baseUrl = 'https://vinczefi.com/';

  @override
  void initState() {
    super.initState();
    _selectedCarId = -1; // Default to "All Vehicles"
    _initializePage();
  }

  // Initialize page with pre-filtering
  Future<void> _initializePage() async {
    // Set default date range: 1st of current month to today
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    setState(() {
      _startDate = firstDayOfMonth;
      _endDate = now;
      _isLoading = true;
    });

    // Load cars first, then fetch log data
    await _loadCars();
    await _fetchLogData();
  }

  // Load cars using the CarInformation service
  Future<void> _loadCars() async {
    try {
      final cars = await _carService.getCars();

      // Add "All Vehicles" option at the beginning
      List<Car> allCars = [
        Car(
          id: -1,
          make: '${Globals.getText('logsVehiclesSelect')}',
          model: '',
          licencePlate: '',
        ),
        ...cars,
      ];

      setState(() {
        _cars = allCars;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cars: $e';
        // Ensure we still have the "All Vehicles" option even if loading fails
        _cars = [
          Car(
            id: -1,
            make: '${Globals.getText('logsVehiclesSelect')}',
            model: '',
            licencePlate: '',
          ),
        ];
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
          'vehicle': _selectedCarId == -1 ? 'all' : _selectedCarId.toString(),
          'driver': Globals.userId == null ? 'all' : Globals.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print(response.body);

        List<LogEntry> logs = [];
        LogSummary summary = LogSummary.empty();

        if (jsonResponse is Map<String, dynamic>) {
          // Extract summary
          if (jsonResponse.containsKey('summary')) {
            summary = LogSummary.fromJson(jsonResponse['summary']);
          }

          // Extract log entries
          jsonResponse.forEach((key, value) {
            if (key != 'summary' && value is Map<String, dynamic>) {
              logs.add(LogEntry.fromJson(value));
            }
          });

          setState(() {
            _logData = logs;
            _sortLogData();
            _filteredLogData = _logData;
            _filterByDate();
            _summary = summary;
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

  @override
  void dispose() {
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

  void _applyFilters() {
    if (_startDate == null || _endDate == null) {
      _showThemedDialog(
          '${Globals.getText('error')}', '${Globals.getText('selectDate')}');
      return;
    }
    _fetchLogData();
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
                      String imageUrl = baseUrl + 'foodexim/' + photo;

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
                    backgroundColor: const Color.fromARGB(255, 1, 160, 226),
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
            '${Globals.getText('logs')}',
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
          height: MediaQuery.of(context).size.height,
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
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
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
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16.0),
                      LogSummaryCard(
                        summary: _summary,
                        hasData: _startDate != null &&
                            _endDate != null &&
                            _filteredLogData.isNotEmpty,
                        startDate: _startDate,
                        endDate: _endDate,
                      ),
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
                        startDate: _startDate,
                        endDate: _endDate,
                      ),
                    ],
                  ),
                ),
        ),
      ),
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
}

class DateSelectionContainer extends StatefulWidget {
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
  State<DateSelectionContainer> createState() => _DateSelectionContainerState();
}

class _DateSelectionContainerState extends State<DateSelectionContainer> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Container(
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
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color.fromARGB(255, 1, 160, 226),
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              widget.startDate == null
                                  ? '${Globals.getText('logsFrom')}'
                                  : DateFormat('yyyy-MM-dd')
                                      .format(widget.startDate!),
                            ),
                            onPressed: widget.onSelectStartDate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
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
                              widget.endDate == null
                                  ? '${Globals.getText('logsTo')}'
                                  : DateFormat('yyyy-MM-dd')
                                      .format(widget.endDate!),
                            ),
                            onPressed: widget.onSelectEndDate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
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
                    Text(
                      '${Globals.getText('logsVehicles')}',
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
                      child: DropdownButton<int>(
                        value: widget.selectedCarId,
                        isExpanded: true,
                        underline: Container(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color.fromARGB(255, 1, 160, 226),
                        ),
                        onChanged: widget.onVehicleChanged,
                        items: widget.cars.map((Car car) {
                          return DropdownMenuItem<int>(
                            value: car.id,
                            child: Text(
                              car.id == -1
                                  ? car
                                      .make // This will be the localized "All Vehicles" text
                                  : car.licencePlate.isEmpty
                                      ? '${car.make} ${car.model}'
                                      : '${car.make} ${car.model} - ${car.licencePlate}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onApplyFilters,
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
            ],
          ],
        ),
      ),
    );
  }
}

class LogDataTable extends StatefulWidget {
  final List<LogEntry> logData;
  final ValueChanged<List<String>> onImageTap;
  final DateTime? startDate;
  final DateTime? endDate;

  const LogDataTable({
    super.key,
    required this.logData,
    required this.onImageTap,
    this.startDate,
    this.endDate,
  });

  @override
  State<LogDataTable> createState() => _LogDataTableState();
}

class _LogDataTableState extends State<LogDataTable> {
  bool isExpanded = true;

  String formatDateTime(String date, String time) {
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$date $time');
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return '$date $time';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                isExpanded = !isExpanded;
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
                      '${Globals.getText('logs')}',
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
          ),
          if (isExpanded) ...[
            if (widget.logData.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
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
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
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
                          '${Globals.getText('logsTableDate')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '${Globals.getText('logsTableVehicle')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '${Globals.getText('logsTableFrom')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '${Globals.getText('logsTableTo')}',
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
                          '${Globals.getText('logsTableStartKm')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '${Globals.getText('logsTableEndKm')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '${Globals.getText('logsTableDifference')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '${Globals.getText('logsTablePhotos')}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                    rows: widget.logData.map((log) {
                      return DataRow(
                        cells: [
                          DataCell(Text(log.inShiftDate)),
                          DataCell(Text(log.vehicle)),
                          DataCell(
                              Text(formatDateTime(log.inShiftDate, log.from))),
                          DataCell(
                              Text(formatDateTime(log.outShiftDate, log.to))),
                          DataCell(Text(log.totalTime)),
                          DataCell(Text(log.startKm.toString())),
                          DataCell(Text(log.endKm.toString())),
                          DataCell(Text(log.kmDifference)),
                          DataCell(
                            log.photos.isNotEmpty
                                ? GestureDetector(
                                    onTap: () => widget.onImageTap(log.photos),
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
              ),
          ],
        ],
      ),
    );
  }
}

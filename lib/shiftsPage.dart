import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/colections.dart';
import 'package:foodex/my_routes_page.dart';
import 'package:foodex/services/shift_service.dart';
import 'package:foodex/models/shift.dart';
import 'package:intl/intl.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  _ShiftsPageState createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  final ShiftService _shiftService =
      ShiftService(baseUrl: 'https://vinczefi.com');
  List<Shift>? _shifts;
  bool _isLoading = false;
  String? _error;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _calculateDateRange();
    _loadShifts();
  }

  void _calculateDateRange() {
    // Start from today
    _startDate = DateTime.now();

    // Find next week's Sunday
    _endDate = _startDate;

    // First, go to this week's Sunday
    while (_endDate.weekday != DateTime.sunday) {
      _endDate = _endDate.add(const Duration(days: 1));
    }

    // Then add 7 days to get to next week's Sunday
    _endDate = _endDate.add(const Duration(days: 7));

    // Set time to end of day (23:59:59)
    _endDate = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
    );
  }

  Future<void> _loadShifts() async {
    if (Globals.userId == null) {
      setState(() {
        _error = 'User ID not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shifts = await _shiftService.loadShifts(
        driverId: Globals.userId.toString(),
        dateFrom: _startDate,
        dateTo: _endDate,
      );

      print(_endDate);

      setState(() {
        _shifts = shifts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Handle the navigation back with order refresh
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
            MaterialPageRoute(
              builder: (context) => const DriverPage(),
            ),
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
                  MaterialPageRoute(
                    builder: (context) => const DriverPage(),
                  ),
                );
              }
            },
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${Globals.getText('shiftTitle')}',
                  style: TextStyle(color: Colors.white)),
              Text(
                '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: const Color.fromARGB(255, 1, 160, 226),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadShifts,
            ),
          ],
        ),
        body: _buildBody(_startDate, _endDate),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up resources here
    super.dispose();
  }

  Widget _buildBody(DateTime start, DateTime end) {
    final themeColor = const Color.fromARGB(255, 1, 160, 226);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    Widget buildDateRange() {
      return Column(
        children: [
          Text(
            'From: ${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: themeColor,
          strokeWidth: 3,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: themeColor,
                      size: isSmallScreen ? 40 : 48,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    buildDateRange(),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      '${Globals.getText('shiftNoFuture')}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              ElevatedButton.icon(
                onPressed: _loadShifts,
                icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
                label: Text(
                  '${Globals.getText('checkAgain')}',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 24,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_shifts == null || _shifts!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: isSmallScreen ? 48 : 64,
              color: themeColor.withOpacity(0.5),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            buildDateRange(),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              '${Globals.getText('shiftNoFound')}',
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
              child: Text(
                '${Globals.getText('shiftNoScheduled')}',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isSmallScreen ? 20 : 24),
            ElevatedButton.icon(
              onPressed: _loadShifts,
              icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
              label: Text(
                '${Globals.getText('checkAgain')}',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 24,
                  vertical: isSmallScreen ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      itemCount: _shifts!.length,
      itemBuilder: (context, index) {
        final shift = _shifts![index];
        print('total weight ${shift.totalWeight}');
        return _buildShiftCard(
            shift.vehicle,
            shift.startTime.toString(),
            shift.endTime.toString(),
            shift.remarks,
            shift.totalOrder,
            shift.totalWeight,
            shift.collectionUnits);
      },
    ); // Return your shifts list here
  }

  Widget _buildShiftCard(
      String vehicleName,
      String startDate,
      String endDate,
      String? remarks,
      int totalOrders,
      double totalWeight,
      List<CollectionUnit> collectionUnits) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final duration = calculateDuration(startDate, endDate);

    // Format collection units into a single string
    String formatCollectionUnits(List<CollectionUnit> units) {
      if (units.isEmpty) return '';

      List<String> formattedUnits = units.map((unit) {
        return '${unit.quantity} x ${unit.name}';
      }).toList();

      return formattedUnits.join('; ');
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyRoutesPage(
              startDate: start,
              endDate: end,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            width: 1,
            color: Colors.black,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 22, color: Colors.grey.shade700),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            '${Globals.getText(DateFormat('E').format(start))} ${DateFormat('dd.MM').format(start)}, ${DateFormat('HH:mm').format(start)} - '
                            '${Globals.getText(DateFormat('E').format(end))} ${start.day != end.day ? "${DateFormat('dd.MM').format(end)} " : ""}'
                            '${DateFormat('HH:mm').format(end)}',
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 34.0, top: 8.0),
                      child: Row(
                        children: [
                          Text(
                            '${Globals.getText('shiftDuration')}: ',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Text(
                              formatDuration(duration),
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Icon(Icons.local_shipping_rounded,
                      size: 22, color: Colors.grey.shade700),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      vehicleName,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (remarks != null && remarks.isNotEmpty) ...[
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note_rounded,
                          size: 22, color: Colors.amber.shade700),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          remarks,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_rounded,
                            size: 22, color: Colors.green.shade700),
                        const SizedBox(width: 8.0),
                        Text(
                          '$totalOrders ${Globals.getText('shiftOrders')}',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.scale_rounded,
                            size: 22, color: Colors.green.shade700),
                        const SizedBox(width: 8.0),
                        Text(
                          '$totalWeight kg',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (collectionUnits.isNotEmpty) ...[
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.recycling,
                              size: 22, color: Colors.purple.shade700),
                          const SizedBox(width: 12.0),
                          Text(
                            '${Globals.getText('collectionRequirements')}:',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Padding(
                        padding: const EdgeInsets.only(left: 34.0),
                        child: Text(
                          formatCollectionUnits(collectionUnits),
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey.shade800,
                            height: 1.4,
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
      ),
    );
  }

  String formatDuration(double hours) {
    final hoursPart = hours.floor();
    final minutesPart = ((hours - hoursPart) * 60).round();

    if (minutesPart == 0) {
      return '$hoursPart ${Globals.getText('shiftHours')}';
    } else {
      return '$hoursPart ${Globals.getText('shiftHours')} $minutesPart ${Globals.getText('shiftMin')}';
    }
  }

  double calculateDuration(String startDate, String endDate) {
    DateTime start = DateTime.parse(startDate);
    DateTime end = DateTime.parse(endDate);
    Duration duration = end.difference(start);
    return duration.inMinutes / 60.0; // Convert to hours with decimal points
  }
}

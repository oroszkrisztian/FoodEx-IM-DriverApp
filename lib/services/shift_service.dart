import 'dart:convert';
import 'package:foodex/models/shift.dart';
import 'package:http/http.dart' as http;

class ShiftService {
  final String baseUrl;

  ShiftService({required this.baseUrl});

  Future<List<Shift>> loadShifts({
    required String driverId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    print("Fromdate: $dateFrom");
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/foodexim/functions.php'),
        body: {
          'action': 'load-shifts',
          'driver': driverId,
          'date-from': dateFrom.toIso8601String().split('T')[0],
          'date-to': dateTo.toIso8601String().split('T')[0],
        },
      );

      print(
          'Raw JSON Response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> shiftsData = jsonResponse['data'];
          final shifts =
              shiftsData.map((shiftData) => Shift.fromJson(shiftData)).toList();

          // Print fetched data to console
          print('Fetched ${shifts.length} shifts:');
          shifts.forEach((shift) {
            print('\nShift ID: ${shift.id}');
            print('Driver: ${shift.driverName}');
            print('Vehicle: ${shift.vehicle}');
            print('Start Time: ${shift.startTime}');
            print('End Time: ${shift.endTime}');
            print("Orders ${shift.orders.length}");
            print("Collection${shift.collectionUnits}");
          });

          return shifts;
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load shifts');
        }
      } else {
        throw Exception(
            'Failed to load shifts. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading shifts: $e');
      rethrow;
    }
  }
}

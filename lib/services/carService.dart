import 'dart:convert';
import 'package:foodex/globals.dart';
import 'package:foodex/models/cars.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Data Models
class VehicleData {
  final int vehicleId;
  final String name;
  final String numberPlate;
  final int km;
  final String consumption;
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
    required this.consumption,
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
    try {
      print('VehicleData: Parsing JSON data: $json');

      // Helper function to safely parse integers from dynamic values
      int _parseInt(dynamic value, int defaultValue) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value) ?? defaultValue;
        }
        return defaultValue;
      }

      // Helper function to safely parse nullable integers
      int? _parseNullableInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value);
        }
        return null;
      }

      // Helper function to safely parse strings
      String _parseString(dynamic value, String defaultValue) {
        if (value == null) return defaultValue;
        return value.toString();
      }

      final vehicleData = VehicleData(
        vehicleId: _parseInt(json['vehicle']['vehicle_id'], 0),
        name: _parseString(json['vehicle']['name'], ''),
        numberPlate: _parseString(json['vehicle']['numberplate'], ''),
        km: _parseInt(json['vehicle']['km'], 0),
        consumption: _parseString(json['vehicle']['consumption'], '0'),
        insuranceStartDate: _parseString(json['insurance']['date_start'], ''),
        insuranceEndDate: _parseString(json['insurance']['date_end'], ''),
        insuranceValidity: _parseValidity(json['insurance']['validity']),
        tuvStartDate: _parseString(json['tuv']['date_start'], ''),
        tuvEndDate: _parseString(json['tuv']['date_end'], ''),
        tuvValidity: _parseValidity(json['tuv']['validity']),
        oilStartDate: _parseString(json['oil']['date_start'], ''),
        oilUntilKm: _parseNullableInt(json['oil']['until']),
        oilValidity: null, // This will be calculated later
      );

      print(
          'VehicleData: Successfully parsed vehicle data for: ${vehicleData.name}');
      print(
          'VehicleData: Parsed values - ID: ${vehicleData.vehicleId}, KM: ${vehicleData.km}, Oil Until: ${vehicleData.oilUntilKm}');
      return vehicleData;
    } catch (e) {
      print('VehicleData: Error parsing JSON: $e');
      print('VehicleData: JSON data: $json');
      rethrow;
    }
  }

  static bool? _parseValidity(String? value) {
    try {
      print('VehicleData: Parsing validity value: $value');
      if (value == null || value == 'NO DATA') {
        print('VehicleData: Validity value is null or NO DATA');
        return null;
      }
      bool isValid = value.toLowerCase() == 'valid';
      print('VehicleData: Parsed validity as: $isValid');
      return isValid;
    } catch (e) {
      print('VehicleData: Error parsing validity "$value": $e');
      return null;
    }
  }

  bool isOilValid() {
    try {
      print(
          'VehicleData: Checking oil validity - current km: $km, oil until km: $oilUntilKm');
      if (oilUntilKm == null) {
        print('VehicleData: Oil until km is null, returning false');
        return false;
      }
      bool isValid = km <= oilUntilKm!;
      print('VehicleData: Oil is valid: $isValid');
      return isValid;
    } catch (e) {
      print('VehicleData: Error checking oil validity: $e');
      return false;
    }
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
    try {
      print('VehicleEntry: Parsing JSON data: $json');

      // Helper function to safely parse integers from dynamic values
      int _parseInt(dynamic value, int defaultValue) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value) ?? defaultValue;
        }
        return defaultValue;
      }

      // Helper function to safely parse strings
      String _parseString(dynamic value, String defaultValue) {
        if (value == null) return defaultValue;
        return value.toString();
      }

      final entry = VehicleEntry(
        id: _parseInt(json['id'], 0),
        make: _parseString(json['make'], ''),
        model: _parseString(json['model'], ''),
        licensePlate: _parseString(json['license_plate'], ''),
        type: _parseString(json['type'], ''),
        mileage: _parseInt(json['mileage'], 0),
        startDate: _parseString(json['start_date'], ''),
        endDate: _parseString(json['end_date'], ''),
        details: _parseString(json['details'], ''),
        photo: _parseString(json['photo'], ''),
      );

      print(
          'VehicleEntry: Successfully parsed entry ID: ${entry.id}, type: ${entry.type}');
      return entry;
    } catch (e) {
      print('VehicleEntry: Error parsing JSON: $e');
      print('VehicleEntry: JSON data: $json');
      rethrow;
    }
  }
}

class CarInformation {
  List<Car> _cars = [];
  String? errorMessage;
  final String baseUrl = 'https://vinczefi.com/';

  // Existing method to get all cars
  Future<List<Car>> getCars() async {
    try {
      print('CarInformation: Fetching cars from API...');
      final response = await http.post(
        Uri.parse('${baseUrl}foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'action': 'get-cars', 'driver': Globals.userId.toString()},
      );

      print('CarInformation: getCars response status: ${response.statusCode}');
      print('CarInformation: getCars response body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse is List) {
          _cars = jsonResponse
              .map((json) => Car.fromJson(json as Map<String, dynamic>))
              .toList();

          print('CarInformation: Successfully loaded ${_cars.length} cars');
          return _cars;
        } else {
          print(
              'CarInformation: Invalid response format - expected List but got ${jsonResponse.runtimeType}');
          throw Exception('Invalid response format');
        }
      } else {
        print(
            'CarInformation: HTTP error ${response.statusCode}: ${response.body}');
        throw Exception('Failed to load cars: ${response.statusCode}');
      }
    } catch (e) {
      print('CarInformation: Error in getCars(): $e');
      errorMessage = 'Error fetching cars: $e';
      return [];
    }
  }

  // New method to get vehicle data using vehicle-vehicle-data action
  Future<VehicleData> getVehicleData(int vehicleId) async {
    try {
      print('CarInformation: Fetching vehicle data for vehicleId: $vehicleId');
      final response = await http.post(
        Uri.parse('${baseUrl}foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'vehicle-vehicle-data',
          'vehicle': vehicleId.toString(),
        },
      );

      print(
          'CarInformation: getVehicleData response status: ${response.statusCode}');
      print('CarInformation: getVehicleData response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('CarInformation: Empty response from server');
          throw Exception('Empty response from server');
        }
        print("raw response vehicle-vehicle-data");
        print(response.body);
        var jsonData = jsonDecode(response.body);

        // Check if response indicates success
        if (jsonData['success'] == false) {
          print('CarInformation: API returned error: ${jsonData['message']}');
          throw Exception(jsonData['message'] ?? 'Unknown error occurred');
        }

        print(
            'CarInformation: Successfully parsed vehicle data for vehicle: ${jsonData['vehicle']?['name'] ?? 'Unknown'}');
        return VehicleData.fromJson(jsonData);
      } else {
        print(
            'CarInformation: HTTP error ${response.statusCode}: ${response.body}');
        throw Exception(
            'Failed to load vehicle data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('CarInformation: Error in getVehicleData(): $e');
      throw Exception('Failed to load vehicle data: $e');
    }
  }

  // Method to get filtered vehicle maintenance data
  Future<List<VehicleEntry>> getFilteredVehicleData({
    DateTime? startDate,
    DateTime? endDate,
    String status = 'all',
    String type = 'all',
    int? vehicleId,
  }) async {
    try {
      print('CarInformation: Fetching filtered vehicle data with params:');
      print('  - startDate: $startDate');
      print('  - endDate: $endDate');
      print('  - status: $status');
      print('  - type: $type');
      print('  - vehicleId: $vehicleId');

      final response = await http.post(
        Uri.parse('${baseUrl}foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'vehicle-data-filter',
          'from': startDate != null
              ? DateFormat('yyyy-MM-dd').format(startDate)
              : '',
          'to': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : '',
          'status': status.toLowerCase(),
          'type': type.toLowerCase(),
          'vehicle': vehicleId?.toString() ?? 'all',
        },
      );

      print(
          'CarInformation: getFilteredVehicleData response status: ${response.statusCode}');
      print(
          'CarInformation: getFilteredVehicleData response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<VehicleEntry> fetchedData =
            responseData.map((data) => VehicleEntry.fromJson(data)).toList();

        print(
            'CarInformation: Successfully loaded ${fetchedData.length} vehicle entries');
        return fetchedData;
      } else {
        print('CarInformation: HTTP error ${response.statusCode}');
        throw Exception(
            'Failed to load vehicle data: Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('CarInformation: Error in getFilteredVehicleData(): $e');
      throw Exception('Failed to load vehicle data: $e');
    }
  }

  List<VehicleEntry> filterVehicleEntriesByDate(
    List<VehicleEntry> entries,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    try {
      print(
          'CarInformation: Filtering ${entries.length} entries by date range: $startDate to $endDate');

      final filtered = entries.where((vehicle) {
        try {
          DateTime vehicleStartDate =
              DateTime.tryParse(vehicle.startDate) ?? DateTime(2000);
          DateTime vehicleEndDate =
              DateTime.tryParse(vehicle.endDate) ?? DateTime(2100);

          // New logic: Check if the vehicle's date range overlaps with the filter range
          // An overlap exists if: vehicleStartDate <= filterEndDate AND vehicleEndDate >= filterStartDate

          if (startDate != null && endDate != null) {
            // Check for overlap: vehicle range overlaps with filter range
            bool hasOverlap = vehicleStartDate
                    .isBefore(endDate.add(Duration(days: 1))) &&
                vehicleEndDate.isAfter(startDate.subtract(Duration(days: 1)));

            print(
                'CarInformation: Vehicle ${vehicle.id} (${vehicle.startDate} to ${vehicle.endDate}) - overlap with filter: $hasOverlap');
            return hasOverlap;
          } else if (startDate != null) {
            // Only start date filter: show entries that end on or after start date
            bool isValid =
                vehicleEndDate.isAfter(startDate.subtract(Duration(days: 1)));
            print(
                'CarInformation: Vehicle ${vehicle.id} ends after start date: $isValid');
            return isValid;
          } else if (endDate != null) {
            // Only end date filter: show entries that start on or before end date
            bool isValid =
                vehicleStartDate.isBefore(endDate.add(Duration(days: 1)));
            print(
                'CarInformation: Vehicle ${vehicle.id} starts before end date: $isValid');
            return isValid;
          }

          // No date filters applied
          return true;
        } catch (e) {
          print(
              'CarInformation: Error parsing dates for vehicle entry ${vehicle.id}: $e');
          print('  - startDate: ${vehicle.startDate}');
          print('  - endDate: ${vehicle.endDate}');
          return false; // Exclude entries with invalid dates
        }
      }).toList();

      print('CarInformation: Filtered to ${filtered.length} entries');
      return filtered;
    } catch (e) {
      print('CarInformation: Error in filterVehicleEntriesByDate(): $e');
      return entries; // Return original list if filtering fails
    }
  }

  // Helper method to sort vehicle entries by date
  List<VehicleEntry> sortVehicleEntriesByDate(
    List<VehicleEntry> entries, {
    bool descending = true,
  }) {
    try {
      print(
          'CarInformation: Sorting ${entries.length} entries by date (descending: $descending)');

      entries.sort((a, b) {
        try {
          DateTime dateA = DateTime.tryParse(a.endDate) ?? DateTime(2000);
          DateTime dateB = DateTime.tryParse(b.endDate) ?? DateTime(2000);
          return descending ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
        } catch (e) {
          print(
              'CarInformation: Error comparing dates for entries ${a.id} and ${b.id}: $e');
          print('  - Entry A endDate: ${a.endDate}');
          print('  - Entry B endDate: ${b.endDate}');
          return 0; // Keep original order if comparison fails
        }
      });

      print('CarInformation: Successfully sorted entries');
      return entries;
    } catch (e) {
      print('CarInformation: Error in sortVehicleEntriesByDate(): $e');
      return entries; // Return original list if sorting fails
    }
  }

  // Method to check if vehicle data is valid/expired
  bool isVehicleDataValid(VehicleEntry entry) {
    try {
      DateTime endDate = DateTime.tryParse(entry.endDate) ?? DateTime(2000);
      bool isValid = endDate.isAfter(DateTime.now());
      print(
          'CarInformation: Vehicle entry ${entry.id} validity check - endDate: ${entry.endDate}, isValid: $isValid');
      return isValid;
    } catch (e) {
      print(
          'CarInformation: Error checking validity for entry ${entry.id}: $e');
      print('  - endDate: ${entry.endDate}');
      return false; // Assume invalid if we can't parse the date
    }
  }

  // Method to get vehicle status text
  String getVehicleStatusText(VehicleEntry entry) {
    try {
      String status = isVehicleDataValid(entry) ? 'VALID' : 'EXPIRED';
      print('CarInformation: Vehicle entry ${entry.id} status: $status');
      return status;
    } catch (e) {
      print(
          'CarInformation: Error getting status text for entry ${entry.id}: $e');
      return 'UNKNOWN';
    }
  }

  // Method to get vehicles by type
  List<VehicleEntry> filterVehiclesByType(
    List<VehicleEntry> entries,
    String type,
  ) {
    try {
      print(
          'CarInformation: Filtering ${entries.length} entries by type: $type');

      if (type.toLowerCase() == 'all') {
        print('CarInformation: Type filter is "all", returning all entries');
        return entries;
      }

      final filtered = entries
          .where(
              (entry) => entry.type.toLowerCase().contains(type.toLowerCase()))
          .toList();

      print('CarInformation: Filtered to ${filtered.length} entries by type');
      return filtered;
    } catch (e) {
      print('CarInformation: Error in filterVehiclesByType(): $e');
      return entries; // Return original list if filtering fails
    }
  }

  // Method to get vehicles by status
  List<VehicleEntry> filterVehiclesByStatus(
    List<VehicleEntry> entries,
    String status,
  ) {
    try {
      print(
          'CarInformation: Filtering ${entries.length} entries by status: $status');

      if (status.toLowerCase() == 'all') {
        print('CarInformation: Status filter is "all", returning all entries');
        return entries;
      }

      final filtered = entries.where((entry) {
        try {
          bool isValid = isVehicleDataValid(entry);
          if (status.toLowerCase() == 'active' ||
              status.toLowerCase() == 'valid') {
            return isValid;
          } else if (status.toLowerCase() == 'expired') {
            return !isValid;
          }
          return true;
        } catch (e) {
          print(
              'CarInformation: Error checking validity for entry ${entry.id} in status filter: $e');
          return false; // Exclude entries that can't be validated
        }
      }).toList();

      print('CarInformation: Filtered to ${filtered.length} entries by status');
      return filtered;
    } catch (e) {
      print('CarInformation: Error in filterVehiclesByStatus(): $e');
      return entries; // Return original list if filtering fails
    }
  }

  // Clear error message
  void clearError() {
    print('CarInformation: Clearing error message: $errorMessage');
    errorMessage = null;
  }
}

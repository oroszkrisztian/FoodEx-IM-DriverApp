import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/cars.dart';
import 'package:http/http.dart' as http;

import 'package:foodex/models/user.dart';
import 'package:foodex/services/carService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final String baseUrl;
  Car? _car;
  final CarInformation _carService = CarInformation();
  UserService({required this.baseUrl});

  Future<User?> loadUser(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/foodexim/functions.php'),
        body: {
          'action': 'load-user',
          'id': userId.toString(),
        },
      );

      print('Loading user with ID: $userId');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        checkVehicleLogin();
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final userData = jsonResponse['data'];
          final rights = jsonResponse['rights'] as List<dynamic>;

          final user = User.fromJson(userData, rights);

          // Print fetched data to console
          print('\nUser Details:');
          print('ID: ${user.id}');
          print('Name: ${user.name}');
          print('Type: ${user.type}');
          print('Status: ${user.status}');
          print('Rights: ${user.rights}');

          if (user.status == "OUT") {
            Globals.vehicleID = null;
            Globals.vehicleName = null;
          }

          return user;
        } else {
          print('Error message: ${jsonResponse['message']}');
          return null;
        }
      } else {
        throw Exception(
            'Failed to load user. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading user: $e');
      rethrow;
    }
  }

  Future<int?> checkVehicleLogin() async {
    try {
      final body = {
        'action': 'get-vehicle-id-simple',
        'driver': Globals.userId.toString()
      };
      debugPrint("Getting vehicle ID for driver: ${Globals.userId}");
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      if (response.statusCode == 200) {
        debugPrint('Response: ${response.body}');
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final vehicleId = data['data']['vehicle_id'];
          if (vehicleId != null) {
            int? parsedVehicleId;
            if (vehicleId is String) {
              parsedVehicleId = int.tryParse(vehicleId);
            } else if (vehicleId is int) {
              parsedVehicleId = vehicleId;
            }
            if (parsedVehicleId != null) {
              Globals.vehicleID = parsedVehicleId;
              final vehicleData =
                  await _carService.getVehicleData(parsedVehicleId);
              Globals.vehicleName =
                  '${vehicleData.name} - ${vehicleData.numberPlate}';

              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('selected_vehicle_id', parsedVehicleId);
                await prefs.setString(
                    'selected_vehicle_name', Globals.vehicleName!);
                debugPrint(
                    'Vehicle data saved to SharedPreferences: ID=$parsedVehicleId, Name=${Globals.vehicleName}');
              } catch (prefsError) {
                debugPrint(
                    'Error saving vehicle data to SharedPreferences: $prefsError');
              }

              debugPrint('Vehicle ID: $parsedVehicleId');
              return parsedVehicleId;
            }
          }
          Globals.vehicleID = null;
          debugPrint('Vehicle id set to : ${Globals.vehicleID}');
          return null;
        }
        debugPrint('Request failed: ${data['message']}');
        return null;
      }
      debugPrint('HTTP Error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error getting vehicle ID: $e');
      return null;
    }
  }
}

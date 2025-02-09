import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'driverPage.dart'; // Import DriverPage
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'globals.dart';
import 'package:workmanager/workmanager.dart';

import 'main.dart';

class Car {
  final int id;
  final String make;
  final String model;
  final String licencePlate;

  Car(
      {required this.id,
      required this.make,
      required this.model,
      required this.licencePlate});

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _kmController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _image1;
  File? _image2;
  File? _image3;
  File? _image4;
  File? _image5;
  File? parcursIn;

  int? _selectedCarId;
  List<Car> _cars = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _lastKm;

  @override
  void initState() {
    super.initState();
    getCars();
    getLastKm(Globals.userId, Globals.vehicleID);
  }

  Future<void> getCars() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-cars',
        },
      );

      // Debug: Print the raw response body
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          try {
            // Parse the JSON response as a List
            List<dynamic> carList = jsonDecode(response.body);

            // Ensure carList is a list of maps
            List<Car> cars = carList
                .map((json) => Car.fromJson(json as Map<String, dynamic>))
                .toList();

            setState(() {
              _cars = cars;
              _isLoading = false;
            });
          } catch (e) {
            setState(() {
              _errorMessage = 'Failed to parse cars data: $e';
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

  Future<bool> getLastKm(int? driverId, int? vehicleId) async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-last-km',
          'driver_id': driverId.toString(),
          'vehicle_id': _selectedCarId.toString(),
        },
      );

      Globals.vehicleID = vehicleId;
      print('Setting Vehicle ID: ${Globals.vehicleID}');

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print('Response data: $data'); // Debug print to check the response

        if (data is bool && data == false) {
          setState(() {
            _lastKm = 0; // Set to 0 if no data is found for the vehicle
            _errorMessage = null; // Clear any previous error messages
          });
          return true; // Allow the process to continue since we handle the default value
        } else if (data != null &&
            (data is int || int.tryParse(data.toString()) != null)) {
          setState(() {
            _lastKm = int.parse(data.toString());
            _errorMessage = null;
          });
          return true;
        } else {
          setState(() {
            _errorMessage = 'Invalid response data';
          });
          return false;
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load last KM: ${response.statusCode}';
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching last KM: $e';
      });
      return false;
    }
  }

  Future<void> _getImage(int imageNumber) async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        setState(() {
          switch (imageNumber) {
            case 1:
              _image1 = File(pickedFile.path);
              break;
            case 2:
              _image2 = File(pickedFile.path);
              break;
            case 3:
              _image3 = File(pickedFile.path);
              break;
            case 4:
              _image4 = File(pickedFile.path);
              break;
            case 5:
              _image5 = File(pickedFile.path);
              break;
            case 6:
              parcursIn = File(pickedFile.path);
          }
        });
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _showImage(File? image, int imageNumber) {
    if (image == null) {
      _getImage(imageNumber);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _getImage(imageNumber);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text('Take New Photo'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageInput(int imageNumber, File? image, bool isSmallScreen) {
    final Map<int, String> labels = {
      1: 'loginVehicleDashboard',
      2: 'loginVehicleFrontLeft',
      3: 'loginVehicleFrontRight',
      4: 'loginVehicleRearLeft',
      5: 'loginVehicleRearRight',
      6: 'loginVehicleLogbook',
    };

    final screenWidth = MediaQuery.of(context).size.width;
    final totalHorizontalPadding = isSmallScreen ? 48.0 : 64.0;
    final containerWidth = (screenWidth - totalHorizontalPadding - 24) / 2;
    final primaryColor = const Color.fromARGB(255, 1, 160, 226);

    return GestureDetector(
      onTap: () => _showImage(image, imageNumber),
      child: SizedBox(
        height: isSmallScreen ? 120 : 140,
        width: containerWidth,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: image != null ? primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 10,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: image != null
                        ? primaryColor.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          '${Globals.getText(labels[imageNumber] ?? 'Unknown')}',
                          style: TextStyle(
                            color: image != null
                                ? primaryColor
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize:
                                isSmallScreen ? 13 : 15, // Increased font size
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (image != null) ...[
                        SizedBox(width: 4),
                        Icon(
                          Icons.check_circle,
                          color: primaryColor,
                          size: isSmallScreen ? 14 : 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Icon(
                image != null
                    ? Icons.remove_red_eye_outlined
                    : Icons.camera_alt_outlined,
                size: isSmallScreen ? 28 : 32, // Increased icon size
                color: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoggingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 1, 160, 226), // Light blue color
                  ),
                ),
                SizedBox(width: 16),
                Text("Logging into vehicle"),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoggingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _submitData() async {
    try {
      // Validate KM input
      if (_kmController.text.isEmpty) {
        await _showErrorDialog('Please enter the KM.');
        return;
      }

      // Validate all images are present
      if (_image1 == null ||
          _image2 == null ||
          _image3 == null ||
          _image4 == null ||
          _image5 == null ||
          parcursIn == null) {
        await _showErrorDialog('Please take all required pictures.');
        return;
      }

      // Validate user ID and vehicle ID
      int? userID = Globals.userId;
      int? carId = Globals.vehicleID;

      print('Setting User ID: ${Globals.userId}');
      print('Setting Vehicle ID: ${Globals.vehicleID}');

      if (userID == null || carId == null) {
        await _showErrorDialog('User ID or Vehicle ID is missing.');
        return;
      }

      // Store data in globals
      Globals.image1 = _image1;
      Globals.image2 = _image2;
      Globals.image3 = _image3;
      Globals.image4 = _image4;
      Globals.image5 = _image5;
      Globals.kmValue = _kmController.text;
      Globals.parcursIn = parcursIn;

      // Validate KM against last recorded value
      bool isKmValid = await getLastKm(userID, carId);
      if (!isKmValid || _lastKm == null) {
        await _showErrorDialog(
            'Unable to retrieve or validate KM data. Please try again.');
        return;
      }

      // Validate user input KM
      int? userInputKm = int.tryParse(_kmController.text);
      if (userInputKm == null) {
        await _showErrorDialog('Please enter a valid number for KM.');
        return;
      }

      if (userInputKm < _lastKm!) {
        await _showErrorDialog(
            'The entered KM must be greater than or equal to the last logged KM.\nLast km: $_lastKm');
        return;
      }

      // Show loading dialog
      _showLoggingDialog();

      // Attempt to login vehicle
      bool loginSuccessful = await loginVehicle();

      if (loginSuccessful) {
        // Register background task for image upload
        await Workmanager().registerOneOffTask(
          "1",
          uploadImageTask,
          inputData: {
            'userId': userID.toString(),
            'vehicleID': carId.toString(),
            'km': _kmController.text,
            'image1': Globals.image1?.path,
            'image2': Globals.image2?.path,
            'image3': Globals.image3?.path,
            'image4': Globals.image4?.path,
            'image5': Globals.image5?.path,
            'image6': Globals.parcursIn?.path
          },
        );

        _hideLoggingDialog();

        // Navigate to driver page
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverPage(),
          ),
        );
      } else {
        _hideLoggingDialog();

        if (!mounted) return;
        // Show login failed dialog
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Login Failed'),
              content: const Text(
                  'There was an error logging in the vehicle. The vehicle data will now be reset.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DriverPage(),
                      ),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      _hideLoggingDialog();
      await _showErrorDialog('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
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
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final primaryColor = const Color.fromARGB(255, 1, 160, 226);

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          Globals.vehicleID = null;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverPage(),
            ),
          );
          // Prevent defaultR back behavior since we're handling navigation
        },
        child: Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Globals.vehicleID = null;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverPage(),
                  ),
                );
              },
            ),
            elevation: 0,
            title: Text(
              "${Globals.getText('loginVehicleTitle')}",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 18 : 20,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            backgroundColor: primaryColor,
          ),
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor)),
                      const SizedBox(height: 16),
                      Text(
                        'Loading vehicles...',
                        style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: isSmallScreen ? 14 : 16),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: isSmallScreen ? 40 : 48,
                                color: primaryColor),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: primaryColor,
                                  fontSize: isSmallScreen ? 14 : 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12.0 : 16.0,
                              vertical: isSmallScreen ? 12.0 : 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Vehicle Details Card
                              _buildVehicleDetailsCard(
                                  isSmallScreen, primaryColor),
                              SizedBox(height: isSmallScreen ? 12 : 20),

                              // Documentation Card
                              _buildDocumentationCard(
                                  isSmallScreen, primaryColor),
                              SizedBox(height: isSmallScreen ? 12 : 20),

                              // Vehicle Photos Card
                              _buildVehiclePhotosCard(
                                  isSmallScreen, primaryColor),
                              SizedBox(height: isSmallScreen ? 20 : 24),

                              // Submit Button
                              SizedBox(
                                height: isSmallScreen ? 48 : 56,
                                child: ElevatedButton(
                                  onPressed: _submitData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: Text(
                                    '${Globals.getText('loginVehicleBottomButton')}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 16 : 24),
                            ],
                          ),
                        ),
                      ),
                    ),
        ));
  }

  Widget _buildVehicleDetailsCard(bool isSmallScreen, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${Globals.getText('loginVehicleDetails')}',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            DropdownButtonFormField<int>(
              value: _selectedCarId,
              items: _cars.map((Car car) {
                return DropdownMenuItem<int>(
                  value: car.id,
                  child: Text(
                    '${car.make} ${car.model} - ${car.licencePlate}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (newValue) async {
                setState(() {
                  _selectedCarId = newValue;
                });
                int? driverId = Globals.userId;
                if (_selectedCarId != null && driverId != null) {
                  await getLastKm(driverId, _selectedCarId);
                }
              },
              decoration: InputDecoration(
                labelText: '${Globals.getText('loginVehicleSelect')}',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '${Globals.getText('loginVehicleMileage')}',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: _lastKm != null
                    ? '${Globals.getText('loginVehicleLast')} $_lastKm km'
                    : 'Enter current mileage',
                prefixIcon: Icon(Icons.speed, color: primaryColor),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentationCard(bool isSmallScreen, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  color: Colors.grey.shade800,
                  size: isSmallScreen ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${Globals.getText('loginVehicleDocumentation')}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildImageInput(1, _image1, isSmallScreen),
                _buildImageInput(6, parcursIn, isSmallScreen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclePhotosCard(bool isSmallScreen, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.car_crash_outlined,
                  color: Colors.grey.shade800,
                  size: isSmallScreen ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${Globals.getText('loginVehicleCondition')}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildImageInput(2, _image2, isSmallScreen),
                    _buildImageInput(3, _image3, isSmallScreen),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildImageInput(4, _image4, isSmallScreen),
                    _buildImageInput(5, _image5, isSmallScreen),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }
}

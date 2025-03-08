import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'globals.dart';
import 'driverPage.dart'; // Import DriverPage

import 'main.dart';

class Car {
  final int id;
  final String name;
  final String numberPlate;

  Car({required this.id, required this.name, required this.numberPlate});

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as int,
      name: json['name'] as String,
      numberPlate: json['numberplate'] as String,
    );
  }
}

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  final _kmController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _image6;
  File? _image7;
  File? _image8;
  File? _image9;
  File? _image10;
  File? parcursOut;

  bool _isLoading = false; // No longer fetching car details
  String? _errorMessage;
  int? _lastKm;

  @override
  void initState() {
    super.initState();
    getLastKm(Globals.userId, Globals.vehicleID);
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
          'vehicle_id': vehicleId.toString(),
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print('Response data: $data'); // Debug print to check the response

        if (data is bool && data == false) {
          setState(() {
            _lastKm = 0; // Set to 0 if no data is found
            _errorMessage = null; // Clear any previous error messages
          });
          return true; // Allow the process to continue
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
              _image6 = File(pickedFile.path);
              break;
            case 2:
              _image7 = File(pickedFile.path);
              break;
            case 3:
              _image8 = File(pickedFile.path);
              break;
            case 4:
              _image9 = File(pickedFile.path);
              break;
            case 5:
              _image10 = File(pickedFile.path);
              break;
            case 6:
              parcursOut = File(pickedFile.path);
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

  void _showLoggingOutDialog() {
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
                Text("Logging out of vehicle"),
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
    if (_kmController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please enter the KM.'),
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

    if (_image6 == null ||
        _image7 == null ||
        _image8 == null ||
        _image9 == null ||
        _image10 == null ||
        parcursOut == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please take all required pictures.'),
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

    Globals.image6 = _image6;
    Globals.image7 = _image7;
    Globals.image8 = _image8;
    Globals.image9 = _image9;
    Globals.image10 = _image10;
    Globals.kmValue = _kmController.text;
    Globals.parcursOut = parcursOut;

    int? userID = Globals.userId;
    int? carId = Globals.vehicleID;

    bool isKmValid = await getLastKm(userID!, carId!);
    if (!isKmValid) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Invalid KM data. Please check and try again.'),
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

    // Handle user input KM validation
    if (int.tryParse(_kmController.text) != null) {
      int userInputKm = int.parse(_kmController.text);

      // Allow user input KM to be equal to or greater than last KM
      if (userInputKm < _lastKm!) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(
                  'The entered KM must be greater than or equal to the last logged KM.\nLast km: $_lastKm'),
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
    }

    _showLoggingOutDialog(); // Show logging out dialog
    bool loginSuccessful = await loginVehicle();

    if (loginSuccessful) {

      _hideLoggingDialog();
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.remove('vehicleId');
      Globals.vehicleID = null;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DriverPage(),
        ),
      );
    } else {
      _hideLoggingDialog();

      // Show an error message to the user
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Login Failed'),
            content: const Text(
                'There was an error logging in the vehicle. The vehicle data will now be reset.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  //Navigator.of(context).pop();
                  //_resetVehicleData(); // Reset vehicle-related data only
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
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final primaryColor = const Color.fromARGB(255, 1, 160, 226);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
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
              "${Globals.getText('logoutVehicleTitle')}",
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
                        'Loading vehicle details...',
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
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      isSmallScreen ? 12.0 : 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Vehicle Details',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 18 : 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 12 : 16),
                                      TextField(
                                        controller: _kmController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        decoration: InputDecoration(
                                          labelText:
                                              '${Globals.getText('loginVehicleMileage')}',
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.always,
                                          hintText: _lastKm != null
                                              ? '${Globals.getText('loginVehicleLast')} $_lastKm km'
                                              : 'Enter current mileage',
                                          prefixIcon: Icon(Icons.speed,
                                              color: primaryColor),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 12 : 16,
                                            vertical: isSmallScreen ? 8 : 12,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: primaryColor, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 12 : 20),

                              // Documentation Card
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      isSmallScreen ? 12.0 : 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildImageInput(
                                              1, _image6, isSmallScreen),
                                          _buildImageInput(
                                              6, parcursOut, isSmallScreen),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 12 : 20),

                              // Vehicle Photos Card
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      isSmallScreen ? 12.0 : 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildImageInput(
                                                  2, _image7, isSmallScreen),
                                              _buildImageInput(
                                                  3, _image8, isSmallScreen),
                                            ],
                                          ),
                                          SizedBox(
                                              height: isSmallScreen ? 8 : 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildImageInput(
                                                  4, _image9, isSmallScreen),
                                              _buildImageInput(
                                                  5, _image10, isSmallScreen),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                                    '${Globals.getText('logoutVehicleBottomButton')}',
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

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }
}

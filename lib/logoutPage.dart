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

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  final _kmController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // State variable to track if photos section is visible
  bool _showPhotosSection = false;

  File? _image1;
  File? _imageFront;
  File? _imageBack;
  File? _imageBox;
  File? parcursIn;
  File? parcursOut;

  bool _isLoading = false;
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
        print('Response data: $data');

        if (data is bool && data == false) {
          setState(() {
            _lastKm = 0;
            _kmController.text = "0"; // Set the text field to 0
            _errorMessage = null; // Clear any previous error messages
          });
          return true; // Allow the process to continue
        } else if (data != null &&
            (data is int || int.tryParse(data.toString()) != null)) {
          int lastKm = int.parse(data.toString());
          setState(() {
            _lastKm = lastKm;
            _kmController.text = lastKm.toString();
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

  Future<bool> validateKm(int? driverId, int? vehicleId) async {
    try {
      if (driverId == null || vehicleId == null) {
        return false;
      }

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

        if (data is bool && data == false) {
          return true;
        } else if (data != null &&
            (data is int || int.tryParse(data.toString()) != null)) {
          int lastKm = int.parse(data.toString());
          setState(() {
            _lastKm = lastKm;
          });
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _getImage(int imageNumber,
      {ImageSource source = ImageSource.camera}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          switch (imageNumber) {
            case 1:
              _image1 = File(pickedFile.path);
              break;
            case 2:
              _imageFront = File(pickedFile.path);
              break;
            case 3:
              _imageBack = File(pickedFile.path);
              break;
            case 4:
              _imageBox = File(pickedFile.path);
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

  void _showImagePickerOptions(int imageNumber) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Camera Option
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _getImage(imageNumber, source: ImageSource.camera);
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: isSmallScreen ? 36 : 40,
                              color: const Color.fromARGB(255, 1, 160, 226),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),

                    // Gallery Option
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _getImage(imageNumber, source: ImageSource.gallery);
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.photo_library,
                              size: isSmallScreen ? 36 : 40,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Cancel Button
                SizedBox(
                  width: 150,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      '${Globals.getText('orderCancel')}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImage(File? image, int imageNumber) {
    if (image == null) {
      _showImagePickerOptions(imageNumber);
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
                        _showImagePickerOptions(imageNumber);
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
      2: 'loginVehicleFront',
      3: 'loginVehicleBack',
      4: 'loginVehicleBox',
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

  // Function to toggle the photos section visibility
  void _togglePhotosSection() {
    setState(() {
      _showPhotosSection = !_showPhotosSection;
    });
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

  Future<void> _submitData() async {
    try {
      // Validate KM input
      if (_kmController.text.isEmpty) {
        await _showErrorDialog('Please enter the KM.');
        return;
      }

      // Validate user ID and vehicle ID
      int? userID = Globals.userId;
      int? carId = Globals.vehicleID;

      if (userID == null || carId == null) {
        await _showErrorDialog('User ID or Vehicle ID is missing.');
        return;
      }

      Globals.image5 = _image1;
      Globals.image6 = _imageFront;
      Globals.image7 = _imageBack;
      Globals.image8 = _imageBox;

      Globals.kmValue = _kmController.text;
      Globals.parcursOut = parcursOut;

      // Validate KM against last recorded value
      bool isKmValid = await validateKm(userID, carId);
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
      _showLoggingOutDialog();

      // Attempt to logout vehicle
      bool logoutSuccessful = await loginVehicle();

      if (Globals.image5 != null ||
          Globals.image6 != null ||
          Globals.image7 != null ||
          Globals.image8 != null ||
          Globals.parcursOut != null) {
        Map<String, dynamic> inputData = {
          'image1': Globals.image5?.path,
          'image2': Globals.image6?.path,
          'image3': Globals.image7?.path,
          'image4': Globals.image8?.path,
          'image5': Globals.parcursOut?.path,
        };
        await uploadImages(inputData);
      }

      if (logoutSuccessful) {
        _hideLoggingDialog();

        // Clear vehicle ID
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_vehicle_id');
        await prefs.remove('selected_vehicle_name');

        Globals.vehicleID = null;
        Globals.vehicleName = null;

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
        // Show logout failed dialog
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Logout Failed'),
              content: const Text(
                  'There was an error logging out of the vehicle. The vehicle data will now be reset.'),
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
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Display vehicle name from Globals.vehicleName
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                '${Globals.vehicleName ?? ""}',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
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
                helperText: _lastKm != null
                    ? '${Globals.getText('loginVehicleLast')} $_lastKm km'
                    : null,
                helperStyle: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey.shade600,
                ),
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
                _buildImageInput(6, parcursOut, isSmallScreen),
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
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildImageInput(2, _imageFront, isSmallScreen),
                    _buildImageInput(3, _imageBack, isSmallScreen),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildImageInput(4, _imageBox, isSmallScreen),
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
                            _buildVehicleDetailsCard(
                                isSmallScreen, primaryColor),
                            SizedBox(height: isSmallScreen ? 12 : 20),

                            // Documentation Card
                            _buildDocumentationCard(
                                isSmallScreen, primaryColor),
                            SizedBox(height: isSmallScreen ? 12 : 20),

                            // Toggle Photos Button
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                onTap: _togglePhotosSection,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      isSmallScreen ? 12.0 : 16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
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
                                      Icon(
                                        _showPhotosSection
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: primaryColor,
                                        size: isSmallScreen ? 24 : 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Vehicle Photos Card (only shown when toggled)
                            if (_showPhotosSection) ...[
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              _buildVehiclePhotosCard(
                                  isSmallScreen, primaryColor),
                            ],

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
      ),
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'globals.dart'; // Import your globals.dart file
import 'package:workmanager/workmanager.dart';

// Constants for task names
const String uploadImageTask = "uploadImageTask";
const String uploadExpenseTask = "uploadExpenseTask";

// Callback dispatcher for handling background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case uploadImageTask:
        return await handleImageUpload(inputData);
      // case uploadExpenseTask:
      //   return await handleExpenseUpload(inputData);
      default:
        return Future.value(false);
    }
  });
}

// Handling image upload task
Future<bool> handleImageUpload(Map<String, dynamic>? inputData) async {
  try {
    await uploadImages(inputData);
    return Future.value(true);
  } catch (e) {
    print('Error in image upload task check: $e');
    return Future.value(false);
  }
}

// Handling expense upload task
// Future<bool> handleExpenseUpload(Map<String, dynamic>? inputData) async {
//   try {
//     await uploadExpense(inputData);
//     return Future.value(true);
//   } catch (e) {
//     print('Error in expense upload task: $e');
//     return Future.value(false);
//   }
// }

// Function to upload images in the background
Future<void> uploadImages(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    print("No input data for image upload");
    return;
  }

  var request = http.MultipartRequest(
    'POST',
    Uri.parse('https://vinczefi.com/foodexim/functions.php'),
  );

  request.fields['action'] = 'photo-upload';
  request.fields['driver'] = inputData['userId'] ?? '';
  request.fields['vehicle'] = inputData['vehicleID'] ?? '';
  request.fields['km'] = inputData['km'] ?? '';

  print('Action: ${request.fields['action']}');
  print('Driver ID: ${request.fields['driver']}');
  print('Vehicle ID: ${request.fields['vehicle']}');
  print('KM: ${request.fields['km']}');

  for (int i = 1; i <= 6; i++) {
    String? imagePath = inputData['image$i'];
    if (imagePath != null && imagePath.isNotEmpty) {
      print(
          'Adding photo$i: $imagePath'); // Print the path of the image being added
      request.files
          .add(await http.MultipartFile.fromPath('photo$i', imagePath));
    } else {
      print(
          'No path provided for photo$i'); // Print a message if no path is provided
    }
  }

  try {
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      print("Image upload complete");
    } else {
      print("Image upload failed: ${response.statusCode}");
      print(
          "Response body: $responseBody"); // Print the full response body for debugging
    }
  } catch (e) {
    print('Error uploading images: $e');
  }
}

// Function to upload expenses in the background

// Function to handle vehicle login
// This function should be in the page or class where it is used
Future<bool> loginVehicle() async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://vinczefi.com/foodexim/functions.php'),
    );

    request.fields['action'] = 'vehicle-login';
    request.fields['driver'] = Globals.userId.toString();
    request.fields['vehicle'] = Globals.vehicleID.toString();
    request.fields['km'] = Globals.kmValue.toString();

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    var jsonResponse = jsonDecode(responseBody);

    if (jsonResponse['success'] == true) {
      return true;
    } else {
      // Error handling
      print('Login Failed: ${jsonResponse['message']}');
      return false;
    }
  } catch (e) {
    // Error handling
    print('Error during vehicle login: $e');
    return false;
  }
}

//levente commit 7
//commit kriszti 4

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  if (isLoggedIn) {
    Globals.userId = int.tryParse(prefs.getString('userId') ?? '');
    Globals.vehicleID = prefs.getInt('vehicleId'); // Correctly retrieve as int
    await _loadImagesFromPrefs1();
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

// Function to load images from SharedPreferences
Future<void> _loadImagesFromPrefs1() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? imagePath1 = prefs.getString('image1');
  String? imagePath2 = prefs.getString('image2');
  String? imagePath3 = prefs.getString('image3');
  String? imagePath4 = prefs.getString('image4');
  String? imagePath5 = prefs.getString('image5');
  String? imagePath6 = prefs.getString('image6');
  String? imagePath7 = prefs.getString('image7');
  String? imagePath8 = prefs.getString('image8');
  String? imagePath9 = prefs.getString('image9');
  String? imagePath10 = prefs.getString('image10');
  String? imagePathParcursIn = prefs.getString('parcursIn');
  String? imagePathParcursOut = prefs.getString('parcursout');

  if (imagePath1 != null) Globals.image1 = File(imagePath1);
  if (imagePath2 != null) Globals.image2 = File(imagePath2);
  if (imagePath3 != null) Globals.image3 = File(imagePath3);
  if (imagePath4 != null) Globals.image4 = File(imagePath4);
  if (imagePath5 != null) Globals.image5 = File(imagePath5);
  if (imagePath6 != null) Globals.image1 = File(imagePath6);
  if (imagePath7 != null) Globals.image2 = File(imagePath7);
  if (imagePath8 != null) Globals.image3 = File(imagePath8);
  if (imagePath9 != null) Globals.image4 = File(imagePath9);
  if (imagePath10 != null) Globals.image5 = File(imagePath10);
  if (imagePathParcursIn != null) Globals.parcursIn = File(imagePathParcursIn);
  if (imagePathParcursOut != null)
    Globals.parcursIn = File(imagePathParcursOut);
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodEx Driver',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 1, 160, 226),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide:
                BorderSide(color: Color.fromARGB(255, 1, 160, 226), width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.black),
        ),
      ),
      home: isLoggedIn ? const DriverPage() : const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;

  void _togglePasswordVisibility() {
    setState(() {
      _isObscure = !_isObscure;
    });
  }

  Future<void> login() async {
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
                    Color.fromARGB(255, 1, 160, 226),
                  ),
                ),
                SizedBox(width: 16),
                Text("Logging user in"),
              ],
            ),
          ),
        );
      },
    );

    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'login',
          'username': _usernameController.text,
          'password': _passwordController.text,
          'type': 'driver',
        },
      );

      var data = json.decode(response.body);

      Navigator.of(context).pop(); // Hide loading dialog

      // Debugging: Print the response body to see what the server is returning
      print("Response: ${response.body}");

      if (data['success']) {
        Globals.userId = data['driver_id'];

        // Print the driver ID from Globals
        print("Driver ID from Globals: ${Globals.userId}");

        Fluttertoast.showToast(
          msg: data['message'],
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', Globals.userId.toString());

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverPage(),
          ),
        );
      } else {
        Fluttertoast.showToast(
          backgroundColor: Colors.red,
          textColor: Colors.white,
          msg: data['message'],
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Hide loading dialog
      print("Error: $e");
      Fluttertoast.showToast(
        backgroundColor: Colors.red,
        textColor: Colors.white,
        msg: "An error occurred: $e",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final primaryColor = const Color.fromARGB(255, 1, 160, 226);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and Title Section
                  Column(
                    children: [
                      Icon(
                        Icons.local_shipping_rounded,
                        size: isSmallScreen ? 64 : 80,
                        color: primaryColor,
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      Text(
                        'Food Ex-Im Driver',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 24 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 32 : 48),

                  // Login Form Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Username Field
                          TextField(
                            controller: _usernameController,
                            cursorColor: primaryColor,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle:
                                  TextStyle(color: Colors.grey.shade600),
                              prefixIcon: Icon(Icons.person_outline,
                                  color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: _isObscure,
                            cursorColor: primaryColor,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle:
                                  TextStyle(color: Colors.grey.shade600),
                              prefixIcon:
                                  Icon(Icons.lock_outline, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isObscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                          SizedBox(height: isSmallScreen ? 24 : 32),

                          // Login Button
                          SizedBox(
                            height: isSmallScreen ? 48 : 56,
                            child: ElevatedButton(
                              onPressed: login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer Section
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  Text(
                    '© 2024 Food Ex-Im. All rights reserved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

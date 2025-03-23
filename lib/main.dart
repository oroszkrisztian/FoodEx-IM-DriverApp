import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:foodex/ServerUpdate.dart';
import 'package:foodex/driverPage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

import 'globals.dart'; // Import your globals.dart file

Future<void> checkForUpdates(BuildContext context) async {
  try {
    // Skip if a dialog is already showing
    if (Globals.isUpdateDialogShowing) {
      print('Update dialog is already visible, skipping update check');
      return;
    }

    // Skip if updates are postponed
    if (Globals.isUpdatePostponed) {
      print(
          'Updates postponed until ${Globals.updatePostponedUntil}, skipping check');
      return;
    }

    // Get current app version
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    // Make API request
    final response = await http.post(
      Uri.parse('https://vinczefi.com/foodexim/functions.php'),
      body: {
        'action': 'get-application-data',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        final serverVersion = responseData['data']['version'];
        final downloadLink = responseData['data']['link'];

        // Compare versions
        bool needsUpdate = _compareVersions(currentVersion, serverVersion);

        // Only show dialog if update is needed
        if (needsUpdate && context.mounted) {
          Globals.isUpdateDialogShowing = true;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) => const ServerUpdateDialog(),
          ).then((_) {
            // Reset flag when dialog is closed
            Globals.isUpdateDialogShowing = false;
          });
        }
      }
    }
  } catch (e) {
    print('Error checking for updates on startup: $e');
  }
}

// Compare version strings (returns true if server version is newer)
bool _compareVersions(String currentVersion, String serverVersion) {
  try {
    List<int> current =
        currentVersion.split('.').map((e) => int.parse(e)).toList();
    List<int> server =
        serverVersion.split('.').map((e) => int.parse(e)).toList();

    // Ensure both lists have the same length
    while (current.length < server.length) {
      current.add(0);
    }
    while (server.length < current.length) {
      server.add(0);
    }

    // Compare version components
    for (int i = 0; i < current.length; i++) {
      if (server[i] > current[i]) {
        return true;
      } else if (server[i] < current[i]) {
        return false;
      }
    }

    return false; // versions are equal
  } catch (e) {
    print('Error comparing versions: $e');
    return false;
  }
}

// Function to upload images in the background
Future<bool> uploadImages(Map<String, dynamic>? inputData) async {
  if (inputData == null) {
    return false;
  }
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('https://vinczefi.com/foodexim/functions.php'),
  );

  request.fields['action'] = 'photo-upload';
  request.fields['driver'] = Globals.userId.toString();
  request.fields['vehicle'] = Globals.vehicleID.toString();
  request.fields['km'] = Globals.kmValue.toString();

  print('Action: ${request.fields['action']}');
  print('Driver ID: ${request.fields['driver']}');
  print('Vehicle ID: ${request.fields['vehicle']}');
  print('KM: ${request.fields['km']}');

  for (int i = 1; i <= 6; i++) {
    String? imagePath = inputData['image$i'];
    if (imagePath != null && imagePath.isNotEmpty) {
      print('Adding photo$i: $imagePath');
      request.files
          .add(await http.MultipartFile.fromPath('photo$i', imagePath));
    } else {
      print('No path provided for photo$i');
    }
  }

  try {
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      print("Image upload complete");
      return true;
    } else {
      print("Image upload failed: ${response.statusCode}");
      print("Response body: $responseBody");
      return false;
    }
  } catch (e) {
    print('Error uploading images: $e');
    return false;
  }
}

// Function to handle vehicle login
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
      print('Login Failed: ${jsonResponse['message']}');
      return false;
    }
  } catch (e) {
    print('Error during vehicle login: $e');
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  if (isLoggedIn) {
    Globals.userId = int.tryParse(prefs.getString('userId') ?? '');
    Globals.vehicleID = prefs.getInt('vehicleId');
  }

  // Load the update postpone time
  await Globals.loadPostponeTime();

  // Run the app first
  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(MyApp(isLoggedIn: isLoggedIn, navigatorKey: navigatorKey));

  // Schedule update check for after app is built, with a delay
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Add a small delay to ensure the app is fully initialized
    Future.delayed(const Duration(seconds: 2), () {
      if (navigatorKey.currentContext != null) {
        checkForUpdates(navigatorKey.currentContext!);
      }
    });
  });
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
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp(
      {super.key, required this.isLoggedIn, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodEx Driver',
      navigatorKey: navigatorKey,
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
      home: isLoggedIn
          ? UpdateCheckWrapper(child: const DriverPage())
          : UpdateCheckWrapper(child: const MyHomePage()),
    );
  }
}

// New WidgetBindingObserver class to check for updates when app is resumed
class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;

  const UpdateCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper>
    with WidgetsBindingObserver {
  bool _isCheckingForUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isCheckingForUpdates) {
      // Check for updates when app is resumed from background
      // but only if we're not already checking
      print('App resumed - checking for updates');
      _isCheckingForUpdates = true;
      // Use Future.delayed to allow the UI to settle
      Future.delayed(Duration.zero, () async {
        await checkForUpdates(context);
        _isCheckingForUpdates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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

  // Add ServerUpdateButton for direct access
  Widget _buildServerUpdateButton() {
    return ServerUpdateButton(
      buttonColor: const Color.fromARGB(255, 1, 160, 226),
      textColor: Colors.white,
    );
  }

  void _showUpdateDialog() {
    // Skip if a dialog is already showing
    if (Globals.isUpdateDialogShowing) {
      print('Update dialog is already visible');
      return;
    }

    Globals.isUpdateDialogShowing = true;
    showDialog(
      context: context,
      builder: (BuildContext context) => const ServerUpdateDialog(),
    ).then((_) {
      // Reset flag when dialog is closed
      Globals.isUpdateDialogShowing = false;
    });
  }

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
            builder: (context) => const UpdateCheckWrapper(child: DriverPage()),
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
                        'Foode Ex-Im Driver App',
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

                          // Additional buttons/options
                          SizedBox(height: isSmallScreen ? 16 : 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showUpdateDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color.fromARGB(255, 1, 160, 226),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    Globals.getText('checkForUpdates') ??
                                        'Check For Updates',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

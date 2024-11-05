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

//only push lib folder content

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
  if (imagePathParcursOut != null) Globals.parcursIn = File(imagePathParcursOut);
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
        title: const Text('Food Ex-Im Driver',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _usernameController,
                  cursorColor: const Color.fromARGB(255, 1, 160, 226),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 1, 160, 226),
                        width: 2.0,
                      ),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  cursorColor: const Color.fromARGB(255, 1, 160, 226),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 1, 160, 226),
                        width: 2.0,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: _togglePasswordVisibility,
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16.0),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 80.0,
                      vertical: 20.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                  ),
                  onPressed: login,
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

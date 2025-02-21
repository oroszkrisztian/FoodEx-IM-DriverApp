import 'dart:async';
import 'dart:io';
import 'dart:convert'; // Import json package
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Import the http package
import 'package:mime/mime.dart';
import 'globals.dart';
import 'package:path/path.dart' as path;

// Define the constant for the expense upload task
const String uploadExpenseTask = "uploadExpenseTask";

class VehicleExpensePage extends StatefulWidget {
  const VehicleExpensePage({super.key});

  @override
  _VehicleExpensePageState createState() => _VehicleExpensePageState();
}

class _VehicleExpensePageState extends State<VehicleExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController? _remarksController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController? _amountController = TextEditingController();
  String? _selectedType;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isFuelSelected = false;
  String? _errorMessage;
  int? _lastKm;
  List<Map<String, dynamic>> _expenseTypes = [];
  bool _isLoading = true;

  String _selectedCurrency = 'RON';

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
    getLastKm(Globals.userId, Globals.vehicleID);
  }

  Future<void> _loadExpenseTypes() async {
    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'action': 'get-categories',
          'type': 'expenses',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _expenseTypes = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load expense types: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading expense types: $e';
        _isLoading = false;
      });
    }
  }

  /// Pick an image using the camera
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // Validate file size
        final size = await imageFile.length();
        if (size > 10 * 1024 * 1024) {
          throw Exception('Image size too large. Maximum size is 10MB.');
        }

        setState(() {
          _image = imageFile;
        });

        print('Image picked successfully:');
        print('- Path: ${pickedFile.path}');
        print('- Size: $size bytes');
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorDialog('Error capturing image: $e');
    }
  }

  /// Show an image preview dialog
  void _showImagePreview(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${Globals.getText('expensePreview')}'),
          content: Image.file(image),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                foregroundColor: Colors.white,
              ),
              child: Text('${Globals.getText('expenseClose')}'),
            ),
          ],
        );
      },
    );
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

  /// Submit the expense data
  Future<bool> _submitExpense() async {
    if (!_formKey.currentState!.validate()) {
      print("Invalid form data for expense upload");
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
      );

      // Set up the basic fields
      Map<String, String> fields = {
        'action': 'vehicle-expense',
        'driver': Globals.userId.toString(),
        'vehicle': Globals.vehicleID.toString(),
        'km': _kmController.text,
        'type': _selectedType ?? '',
        'remarks': _remarksController?.text ?? '',
        'cost': _costController.text
            .replaceAll(',', '.'), // Ensure decimal point is correct
        'amount': _amountController?.text ?? '',
        'currency': _selectedCurrency.toLowerCase(),
      };

      request.fields.addAll(fields);

      // Add expense photo if exists
      if (_image != null) {
        try {
          // Read file as bytes
          final bytes = await _image!.readAsBytes();
          final size = bytes.length;

          // Validate file size (e.g., max 10MB)
          if (size > 10 * 1024 * 1024) {
            throw Exception('File size too large. Maximum size is 10MB.');
          }

          // Get file extension and name
          final extension = path.extension(_image!.path).toLowerCase();
          final fileName = path.basename(_image!.path);

          // Determine MIME type
          String mimeType;
          switch (extension) {
            case '.jpg':
            case '.jpeg':
              mimeType = 'image/jpeg';
              break;
            case '.png':
              mimeType = 'image/png';
              break;
            case '.gif':
              mimeType = 'image/gif';
              break;
            default:
              throw Exception(
                  'Unsupported file type. Please use JPG, PNG, or GIF.');
          }

          // Create MultipartFile
          final multipartFile = http.MultipartFile.fromBytes(
            'photo',
            bytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          );

          print('Preparing to upload file:');
          print('- Path: ${_image!.path}');
          print('- Name: $fileName');
          print('- MIME: $mimeType');
          print('- Size: $size bytes');

          request.files.add(multipartFile);
        } catch (e) {
          print('Error preparing file upload: $e');
          _showErrorDialog('Error preparing file for upload: $e');
          return false;
        }
      }

      print("Sending expense request...");
      print("Request fields: ${request.fields}");

      if (request.files.isNotEmpty) {
        print("Files to upload: ${request.files.length}");
        for (var file in request.files) {
          print("File details:");
          print("- Field: ${file.field}");
          print("- Filename: ${file.filename}");
          print("- Content-Type: ${file.contentType}");
          print("- Length: ${file.length} bytes");
        }
      }

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
      });

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      print("Response status code: ${response.statusCode}");
      print("Response headers: ${response.headers}");
      print("Response data: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            _showSuccessDialog();
            _resetForm();
            return true;
          } else {
            throw Exception(
                responseData['message'] ?? 'Unknown error occurred');
          }
        } catch (e) {
          throw Exception('Invalid response format: ${response.body}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading expense: $e');
      _showErrorDialog(e.toString());
      return false;
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  /// Reset the form to its initial state
  void _resetForm() {
    setState(() {
      _formKey.currentState!.reset(); // Reset all form fields
      _kmController.clear();
      _remarksController?.clear();
      _costController.clear();
      _amountController?.clear();
      _selectedType = null; // Reset the dropdown to its initial state
      _image = null;
      _isFuelSelected = false;
    });
  }

  /// Show a success dialog when the expense is scheduled
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${Globals.getText('expenseCompletedSuccess')}'),
          content: Text('${Globals.getText('expenseCompletedSuccessMessage')}'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // Close the dialog
                Navigator.of(context).pop();
                // Navigate to DriverPage
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverPage(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show an error dialog if the expense submission fails
  void _showErrorDialog(String message) {
    showDialog(
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
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                foregroundColor: Colors.white,
              ),
              child: Text('${Globals.getText('expenseClose')}'),
            ),
          ],
        );
      },
    );
  }

  /// Build a widget to display an image container
  Widget _buildImageContainer(String label, File? image) {
    return Container(
      height: 150,
      width: 160,
      decoration: BoxDecoration(
        color: image != null
            ? const Color.fromARGB(255, 1, 160, 226)
            : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          width: 1,
          color: Colors.black,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.black),
                  ),
                  if (image != null)
                    const Icon(Icons.check, color: Colors.black),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(
                      color: Color.fromARGB(255, 1, 160, 226), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text('${Globals.getText('expensePicture')}'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed:
                    image != null ? () => _showImagePreview(image) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(
                      color: Color.fromARGB(255, 1, 160, 226), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text('${Globals.getText('expensePreview')}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    _remarksController?.dispose();
    _costController.dispose();
    _amountController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${Globals.getText('expenseTitle')}',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 1, 160, 226),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            width: 1,
                            color: Colors.black,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.6),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText:
                                    '${Globals.getText('expenseSelectType')}',
                              ),
                              items: _expenseTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type['name'],
                                  child: Text(
                                    type['name'],
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              }).toList(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select an expense type';
                                }
                                return null;
                              },
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedType = newValue;
                                  _isFuelSelected =
                                      newValue?.toLowerCase() == 'fuel';
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _kmController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'KM',
                                hintText: _lastKm != null
                                    ? 'Last KM: $_lastKm'
                                    : 'Fetching last KM...', // Check if _lastKm is available
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter KM';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _remarksController,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                  labelText:
                                      '${Globals.getText('expenseSelectRemarks')}'),
                              validator: (value) {
                                // No longer mandatory, so return null to indicate it's valid
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText:
                                      '${Globals.getText('expenseSelectCost')}'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter cost';
                                }
                                return null;
                              },
                            ),
                            if (_isFuelSelected) const SizedBox(height: 16),
                            if (_isFuelSelected)
                              TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'Amount'),
                                validator: (value) {
                                  if (_isFuelSelected &&
                                      (value == null || value.isEmpty)) {
                                    return 'Please enter the amount';
                                  }
                                  return null;
                                },
                              ),
                            // Add this just before _buildImageContainer call
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText:
                                    '${Globals.getText('expenseSelectCurrency')}',
                              ),
                              value: _selectedCurrency,
                              items:
                                  ['RON', 'HUF', 'EUR'].map((String currency) {
                                return DropdownMenuItem<String>(
                                  value: currency,
                                  child: Text(currency,
                                      style:
                                          const TextStyle(color: Colors.black)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedCurrency = newValue;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 16.0),
                            _buildImageContainer(
                                '${Globals.getText('expenseImage')}', _image),
                            if (_image == null)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16.0),
                      Text(
                        'Uploading Expense...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ElevatedButton(
          onPressed: _submitExpense,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 1, 160, 226),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            '${Globals.getText('expenseSubmit')}',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

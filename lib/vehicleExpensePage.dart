import 'dart:async';
import 'dart:io';
import 'dart:convert'; // Import json package
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Import the http package
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

  String _selectedCurrency = 'RON'; // Default currency

  final List<String> _expenseTypes = ['Fuel', 'Wash', 'Others'];

  @override
  void initState() {
    super.initState();
    // Removed getCarDetails call since it's not needed
    getLastKm(Globals.userId, Globals.vehicleID);
  }

  /// Pick an image using the camera
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
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
    
    // Set up the basic fields from form controllers
    request.fields['action'] = 'vehicle-expense';
    request.fields['driver'] = Globals.userId.toString();
    request.fields['vehicle'] = Globals.vehicleID.toString();
    request.fields['km'] = _kmController.text;
    request.fields['type'] = (_selectedType ?? '').toLowerCase();
    request.fields['remarks'] = (_remarksController?.text ?? '').toLowerCase();
    request.fields['cost'] = _costController.text;
    request.fields['amount'] = _amountController!.text;
    request.fields['currency'] = _selectedCurrency;
    
    // Add expense photo if exists
    if (_image != null && _image!.path.isNotEmpty) {
      print('Adding photo: ${_image!.path}');
      request.files.add(await http.MultipartFile.fromPath('photo', _image!.path));
    } else {
      print('No photo path provided');
    }
    
    print("Sending expense request...");
    print("Request fields: ${request.fields}");
    
    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    
    print("Response status code: ${response.statusCode}");
    print("Response data: $responseData");
    
    if (response.statusCode == 200) {
      var data = json.decode(responseData);
      if (data['success'] == true) {
        _showSuccessDialog();
        _resetForm();
        return true;
      }
    }
    
    _showErrorDialog(response.statusCode == 200 
      ? (json.decode(responseData)['message'] ?? 'Failed to submit expense')
      : 'Server error: ${response.statusCode}');
    return false;
    
  } catch (e) {
    print('Error uploading expense: $e');
    _showErrorDialog('Error submitting expense: $e');
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
                                labelText: '${Globals.getText('expenseSelectType')}'),
                            items: _expenseTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type,
                                    style:
                                        const TextStyle(color: Colors.black)),
                              );
                            }).toList(),
                            validator: (value) {
                              if (value == null) {
                                return 'Please select an expense type';
                              }
                              return null;
                            },
                            onChanged: (newValue) {
                              setState(() {
                                _selectedType = newValue;
                                _isFuelSelected = newValue == 'Fuel';
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
                            decoration:
                                InputDecoration(labelText: '${Globals.getText('expenseSelectRemarks')}'),
                            validator: (value) {
                              // No longer mandatory, so return null to indicate it's valid
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration:
                                InputDecoration(labelText: '${Globals.getText('expenseSelectCost')}'),
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
                              labelText: '${Globals.getText('expenseSelectCurrency')}',
                            ),
                            value: _selectedCurrency,
                            items: ['RON', 'HUF', 'EUR'].map((String currency) {
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
                          _buildImageContainer('${Globals.getText('expenseImage')}', _image),
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

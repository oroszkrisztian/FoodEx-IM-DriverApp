import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/translations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'globals.dart';
import 'package:path/path.dart' as path;

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
  int? _lastKm;

  bool get _isCarWash => _selectedType?.toLowerCase() == 'mosás/spălare';
  bool get _isCarFuel =>
      _selectedType?.toLowerCase() == 'üzemanyag/combustibil';
  bool get _isAdBLue => _selectedType?.toLowerCase() == 'adblue';

  String _selectedCurrency = 'RON';

  List<Map<String, dynamic>> _expenseCategories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    getLastKm(Globals.userId, Globals.vehicleID);
    _fetchExpenseCategories();
  }

  Future<void> _fetchExpenseCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://vinczefi.com/foodexim/functions.php'),
        headers: {
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
          _expenseCategories = List<Map<String, dynamic>>.from(data);
          _isLoadingCategories = false;
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  void _showImagePickerOptions() {
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
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
                        Text(
                          Translations.getText('expenseCamera', Globals.currentLanguage),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
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
                        Text(
                          Translations.getText('expenseGallery', Globals.currentLanguage),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),
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
                      Translations.getText('expenseCancel', Globals.currentLanguage),
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showImagePreview(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Translations.getText('expenseImagePreview', Globals.currentLanguage),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 1, 160, 226),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(Translations.getText('close', Globals.currentLanguage)),
                ),
              ],
            ),
          ),
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
        print('Response data: $data');

        if (data is bool && data == false) {
          setState(() {
            _lastKm = 0;
            _kmController.text = "0";
          });
          return true;
        } else if (data != null &&
            (data is int || int.tryParse(data.toString()) != null)) {
          int lastKm = int.parse(data.toString());
          setState(() {
            _lastKm = lastKm;
            _kmController.text = lastKm.toString();
          });
          return true;
        } else {
          setState(() {});
          return false;
        }
      } else {
        setState(() {});
        return false;
      }
    } catch (e) {
      setState(() {});
      return false;
    }
  }

  Future<bool> _submitExpense() async {
    if (_isCarWash && _image == null) {
      _showErrorDialog(Translations.getText('expensePictureRequired', Globals.currentLanguage));
      return false;
    }

    if (!_isCarWash && !_formKey.currentState!.validate()) {
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

      request.fields['action'] = 'vehicle-expense';
      request.fields['driver'] = Globals.userId.toString();
      request.fields['vehicle'] = Globals.vehicleID.toString();
      request.fields['km'] = _isCarWash
          ? (_kmController.text.isEmpty ? '0' : _kmController.text)
          : _kmController.text;
      request.fields['type'] = (_selectedType ?? '').toLowerCase();
      request.fields['remarks'] =
          (_remarksController?.text ?? '').toLowerCase();
      request.fields['cost'] = _isCarWash
          ? (_costController.text.isEmpty
              ? '0'
              : _costController.text.replaceAll(',', '.'))
          : _costController.text.replaceAll(',', '.');
      request.fields['amount'] = _isCarWash
          ? (_amountController!.text.isEmpty
              ? '0'
              : _amountController!.text.replaceAll(',', '.'))
          : (_amountController?.text ?? '').replaceAll(',', '.');
      request.fields['currency'] = _selectedCurrency.toLowerCase();

      if (_image != null && _image!.path.isNotEmpty) {
        print('Adding photo: ${_image!.path}');
        request.files
            .add(await http.MultipartFile.fromPath('photo', _image!.path));
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

  void _resetForm() {
    setState(() {
      _formKey.currentState!.reset();
      _kmController.clear();
      _remarksController?.clear();
      _costController.clear();
      _amountController?.clear();
      _selectedType = null;
      _image = null;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(Translations.getText('expenseCompletedSuccess', Globals.currentLanguage)),
          content: Text(Translations.getText('expenseCompletedSuccessMessage', Globals.currentLanguage)),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const DriverPage()),
                );
              },
              child: Text(Translations.getText('expenseOK', Globals.currentLanguage)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(Translations.getText('error', Globals.currentLanguage)),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(Translations.getText('close', Globals.currentLanguage)),
            ),
          ],
        );
      },
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    const primaryColor = Color.fromARGB(255, 1, 160, 226);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          Translations.getText('expenseTitle', Globals.currentLanguage),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 18 : 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12.0 : 16.0,
                  vertical: isSmallScreen ? 12.0 : 20.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
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
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: Colors.grey.shade800,
                                    size: isSmallScreen ? 20 : 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    Translations.getText('expenseDetails', Globals.currentLanguage),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 16 : 20),

                              if (_isLoadingCategories)
                                const Center(child: CircularProgressIndicator())
                              else
                                DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  items: _expenseCategories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category['name'],
                                      child: Text(
                                        category['name'],
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 13 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedType = newValue;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: Translations.getText('expenseSelectType', Globals.currentLanguage),
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
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.red, width: 2),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.red, width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null) {
                                      return Translations.getText('expenseSelectTypeRequired', Globals.currentLanguage);
                                    }
                                    return null;
                                  },
                                ),

                              SizedBox(height: isSmallScreen ? 12 : 16),

                              TextFormField(
                                controller: _kmController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: Translations.getText('expenseKM', Globals.currentLanguage),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  helperText: _lastKm != null
                                      ? Translations.getText('expenseKMCurrent', Globals.currentLanguage)
                                      : Translations.getText('expenseKMLoading', Globals.currentLanguage),
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
                                validator: (value) {
                                  if (!_isCarWash && (value == null || value.isEmpty)) {
                                    return Translations.getText('expenseKMRequired', Globals.currentLanguage);
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isSmallScreen ? 12 : 16),

                              TextFormField(
                                controller: _remarksController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                minLines: 2,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  labelText: Translations.getText('expenseSelectRemarks', Globals.currentLanguage),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  alignLabelWithHint: true,
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(bottom: 40),
                                    child: Icon(Icons.notes, color: primaryColor),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 12 : 16,
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

                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _costController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: Translations.getText('expenseSelectCost', Globals.currentLanguage),
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        prefixIcon: Icon(Icons.euro, color: primaryColor),
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
                                      validator: (value) {
                                        if (!_isCarWash && (value == null || value.isEmpty)) {
                                          return Translations.getText('expenseSelectCostRequired', Globals.currentLanguage);
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedCurrency,
                                      items: ['RON', 'HUF', 'EUR'].map((String currency) {
                                        return DropdownMenuItem<String>(
                                          value: currency,
                                          child: Text(
                                            currency,
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 13 : 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedCurrency = newValue;
                                          });
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: Translations.getText('expenseSelectCurrency', Globals.currentLanguage),
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
                                  ),
                                ],
                              ),

                              if (_isCarFuel || _isAdBLue) ...[
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: Translations.getText('expenseSelectAmount', Globals.currentLanguage),
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                    prefixIcon: Icon(Icons.local_gas_station, color: primaryColor),
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
                                  validator: (value) {
                                    if ((_isCarFuel || _isAdBLue) && (value == null || value.isEmpty)) {
                                      return Translations.getText('expenseSelectAmountRequired', Globals.currentLanguage);
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 12 : 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _pickImage(ImageSource.camera),
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _image != null ? primaryColor : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: isSmallScreen ? 40 : 48,
                                    color: _image != null ? primaryColor : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                Translations.getText('expenseCamera', Globals.currentLanguage),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: _image != null ? primaryColor : Colors.grey.shade700,
                                ),
                              ),
                              if (_image != null)
                                Icon(
                                  Icons.check_circle,
                                  color: primaryColor,
                                  size: 20,
                                ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _pickImage(ImageSource.gallery),
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _image != null ? Colors.green : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.photo_library,
                                    size: isSmallScreen ? 40 : 48,
                                    color: _image != null ? Colors.green : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                Translations.getText('expenseGallery', Globals.currentLanguage),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: _image != null ? Colors.green : Colors.grey.shade700,
                                ),
                              ),
                              if (_image != null)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                            ],
                          ),
                        ],
                      ),

                      if (_image != null) ...[
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                            child: Column(
                              children: [
                                Text(
                                  Translations.getText('expenseSelectedImage', Globals.currentLanguage),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () => _showImagePreview(_image!),
                                  child: Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: primaryColor),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _image!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  Translations.getText('expenseTapPreview', Globals.currentLanguage),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: isSmallScreen ? 20 : 24),

                      SizedBox(
                        height: isSmallScreen ? 48 : 56,
                        child: ElevatedButton(
                          onPressed: _submitExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            Translations.getText('expenseSubmit', Globals.currentLanguage),
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

            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 1, 160, 226),
                        ),
                      ),
                      SizedBox(height: 16.0),
                      Text(
                        Translations.getText('expenseUploading', Globals.currentLanguage),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
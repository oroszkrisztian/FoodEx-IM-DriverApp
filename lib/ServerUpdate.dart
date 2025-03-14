import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:foodex/globals.dart';

import 'dart:io' show Platform;

class ServerUpdateButton extends StatelessWidget {
  final Color buttonColor;
  final Color textColor;
  
  const ServerUpdateButton({
    Key? key, 
    this.buttonColor = Colors.green, 
    this.textColor = Colors.white
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        _showServerUpdateDialog(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(Globals.getText('checkServerUpdate') ?? 'Check Server Update'),
    );
  }

  void _showServerUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const ServerUpdateDialog(),
    );
  }
}

class ServerUpdateDialog extends StatefulWidget {
  const ServerUpdateDialog({Key? key}) : super(key: key);

  @override
  State<ServerUpdateDialog> createState() => _ServerUpdateDialogState();
}

class _ServerUpdateDialogState extends State<ServerUpdateDialog> {
  bool _isChecking = false;
  String _statusMessage = '';
  String _currentVersion = '';
  String _serverVersion = '';
  String _downloadLink = '';
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
      });
    } catch (e) {
      print('Error getting app version: $e');
      setState(() {
        _currentVersion = 'unknown';
      });
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _statusMessage = Globals.getText('checkingForUpdates') ?? 'Checking for updates...';
    });

    // First get the current app version
    await _getAppVersion();

    try {
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
          bool needsUpdate = _compareVersions(_currentVersion, serverVersion);
          
          setState(() {
            _serverVersion = serverVersion;
            _downloadLink = downloadLink;
            _updateAvailable = needsUpdate;
            _isChecking = false;
            _statusMessage = needsUpdate 
                ? (Globals.getText('newVersionAvailable') ?? 'New version available!')
                : (Globals.getText('appIsUpToDate') ?? 'Your app is up to date.');
          });
        } else {
          setState(() {
            _isChecking = false;
            _statusMessage = responseData['message'] ?? 'Error checking for updates';
          });
        }
      } else {
        setState(() {
          _isChecking = false;
          _statusMessage = '${Globals.getText('serverError') ?? 'Server error'}: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error checking for updates: $e');
      setState(() {
        _isChecking = false;
        _statusMessage = '${Globals.getText('updateCheckFailed') ?? 'Update check failed'}: $e';
      });
    }
  }

  // Compare version strings (returns true if server version is newer)
  bool _compareVersions(String currentVersion, String serverVersion) {
    try {
      List<int> current = currentVersion.split('.').map((e) => int.parse(e)).toList();
      List<int> server = serverVersion.split('.').map((e) => int.parse(e)).toList();
      
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

  // Launch URL to download the update
  Future<void> _downloadUpdate() async {
    if (_downloadLink.isEmpty) return;
    
    // Check if it's a Google Drive link
    bool isGoogleDriveLink = _downloadLink.contains('drive.google.com');
    
    if (Platform.isAndroid && isGoogleDriveLink) {
      // Handle Google Drive links on Android using Android Intent
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: _downloadLink,
          package: 'com.google.android.apps.docs',  // Google Drive package
        );
        await intent.launch();
        Navigator.of(context).pop(); // Close dialog after launching
      } catch (e) {
        print('Error launching Google Drive with intent: $e');
        // Fallback to browser if Google Drive app isn't installed
        _launchInBrowser(_downloadLink);
      }
    } else {
      // Handle other links or iOS
      _launchInBrowser(_downloadLink);
    }
  }
  
  Future<void> _launchInBrowser(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      
      // First try external application
      if (await canLaunchUrl(url)) {
        bool launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          Navigator.of(context).pop();
          return;
        }
      }
      
      // If that fails, try platform default
      await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );
      Navigator.of(context).pop();
    } catch (e) {
      print('Error launching URL in browser: $e');
      setState(() {
        _statusMessage = '${Globals.getText('errorOpeningUrl') ?? 'Error opening URL'}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Globals.getText('checkForUpdates') ?? 'Server Update Check',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_isChecking) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 15),
              Text(_statusMessage),
            ] else ...[
              Icon(
                _updateAvailable ? Icons.system_update : Icons.check_circle,
                color: _updateAvailable ? Colors.orange : Colors.green,
                size: 60,
              ),
              const SizedBox(height: 15),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              
              if (_currentVersion.isNotEmpty)
                Text('${Globals.getText('currentVersion') ?? 'Current version'}: $_currentVersion'),
              
              if (_updateAvailable && _serverVersion.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text('${Globals.getText('serverVersion') ?? 'Server version'}: $_serverVersion'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _downloadUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(Globals.getText('downloadUpdate') ?? 'Download Update'),
                ),
              ],
            ],
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(Globals.getText('close') ?? 'Close'),
            ),
          ],
        ),
      ),
    );
  }
}
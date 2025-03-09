import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodex/driverPage.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/main.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShorebirdUpdateScreen extends StatefulWidget {
  final Widget child;
  final Color primaryColor;

  const ShorebirdUpdateScreen({
    Key? key,
    required this.child,
    this.primaryColor = const Color.fromARGB(255, 1, 160, 226),
  }) : super(key: key);

  @override
  State<ShorebirdUpdateScreen> createState() => _ShorebirdUpdateScreenState();
}

class _ShorebirdUpdateScreenState extends State<ShorebirdUpdateScreen> {
  final ShorebirdCodePush _shorebirdCodePush = ShorebirdCodePush();
  bool _isCheckingForUpdate = true;
  bool _updateAvailable = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _updateDownloaded = false;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      // Check if an update was previously downloaded but not applied
      final prefs = await SharedPreferences.getInstance();
      final updateDownloaded = prefs.getBool('updateDownloaded') ?? false;

      if (updateDownloaded) {
        setState(() {
          _updateDownloaded = true;
          _isCheckingForUpdate = false;
        });
        return;
      }

      // Check if an update is available
      final isUpdateAvailable =
          await _shorebirdCodePush.isNewPatchAvailableForDownload();

      if (isUpdateAvailable) {
        setState(() {
          _updateAvailable = true;
          _isCheckingForUpdate = false;
        });
      } else {
        setState(() {
          _isCheckingForUpdate = false;
        });
      }
    } catch (e) {
      print('Error checking for Shorebird updates: $e');
      setState(() {
        _isCheckingForUpdate = false;
      });
    }
  }

  Future<void> _downloadUpdate() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // The downloadUpdate method doesn't have onProgress parameter
      // We'll simulate progress with a simple timer instead
      _progressTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_downloadProgress < 0.95) {
          setState(() {
            _downloadProgress += 0.01;
          });
        } else {
          timer.cancel();
        }
      });

      await _shorebirdCodePush.downloadUpdateIfAvailable();
      _progressTimer?.cancel();

      // Update succeeded, set progress to 100%
      setState(() {
        _downloadProgress = 1.0;
      });

      // Store that we successfully downloaded an update
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          'updateDownloaded', true); // Mark that an update is ready
      await prefs.setBool(
          'justUpdated', true); // For post-update initialization

      // Small delay to show 100% before continuing
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _updateAvailable = false;
          _updateDownloaded = true;
        });
      }
    } catch (e) {
      _progressTimer?.cancel();
      print('Error downloading update: $e');

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isCheckingForUpdate = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to restart the app
  void _restartApp(BuildContext context) {
    // Clear the downloaded flag before restarting
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('updateDownloaded', false);

      try {
        // Try to use the Restart package
        Restart.restartApp();
      } catch (e) {
        print('Restart failed: $e');
        // Fallback to exit
        exit(0);
      }
    });
  }

  void _closeScreen() async {
    if (Globals.userId != null) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DriverPage(),
        ),
      );
    }else{
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyHomePage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If checking for updates or there's an update available or downloaded, show the update screen
    if (_isCheckingForUpdate || _updateAvailable || _updateDownloaded) {
      return Material(
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and App name
                  Icon(
                    Icons.local_shipping_rounded,
                    size: 80,
                    color: widget.primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Food Ex-Im Driver',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Show loading or update UI
                  if (_isCheckingForUpdate &&
                      !_updateAvailable &&
                      !_updateDownloaded) ...[
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(widget.primaryColor),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${Globals.getText('checkingForUpdates')}...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _closeScreen,
                      child: Text(
                        Globals.getText('cancel'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ] else if (_updateDownloaded) ...[
                    // Update downloaded UI
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.restart_alt,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            Globals.getText('updateComplete'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Globals.getText('restartToApply'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _closeScreen,
                                child: Text(
                                  Globals.getText('later'),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => _restartApp(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  Globals.getText('restartNow'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (_updateAvailable) ...[
                    if (_isDownloading) ...[
                      // Download progress
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                widget.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${Globals.getText('downloadingUpdate')}: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _closeScreen,
                            child: Text(
                              Globals.getText('orderCancel'),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Update available UI
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.system_update_outlined,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              Globals.getText('newUpdateAvailable'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Globals.getText('wouldYouLikeToUpdate'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: _closeScreen,
                                  child: Text(
                                    Globals.getText('later'),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _downloadUpdate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    Globals.getText('updateNow'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            Globals.getText('noUpdatesAvailable'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Globals.getText('appIsUpToDate'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: _closeScreen,
                            child: Text(
                              Globals.getText('orderCancel'),
                              style: TextStyle(
                                color: widget.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // No updates available
                ],
              ),
            ),
          ),
        ),
      );
    }

    // If no update or done with the update process, show the app
    return widget.child;
  }
}

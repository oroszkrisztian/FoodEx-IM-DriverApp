import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _currentVersion = 'Current';
  String _newVersion = 'New';

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      // Check if we should skip update checks based on user preference
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateCheck = prefs.getInt('lastUpdateCheck') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Only check for updates once per day if user selected "Later"
      if (currentTime - lastUpdateCheck < 24 * 60 * 60 * 1000) {
        setState(() {
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

          // We don't have direct API methods to get version numbers, so just show update is available
          // In a production app, you might want to implement version tracking yourself
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

      final progressTimer =
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
      progressTimer.cancel();

      // Update succeeded, set progress to 100%
      setState(() {
        _downloadProgress = 1.0;
      });

      // Store that we successfully updated
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastUpdateCheck'); // Clear the delay timer

      // Small delay to show 100% before continuing
      await Future.delayed(const Duration(milliseconds: 500));

      // Show restart app dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                'Update Downloaded',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'The update has been downloaded successfully. The app will restart now to apply the update.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Restart the app to apply the update
                    _restartApp(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: widget.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Restart Now',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            );
          },
        );
      } else {
        setState(() {
          _isDownloading = false;
          _updateAvailable = false;
          _isCheckingForUpdate = false;
        });
      }
    } catch (e) {
      print('Error downloading update: $e');
      setState(() {
        _isDownloading = false;
        _isCheckingForUpdate = false;
      });

      if (mounted) {
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
    Restart.restartApp();
  }

  void _remindLater() async {
    // Save the timestamp of when the user chose to be reminded later
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'lastUpdateCheck', DateTime.now().millisecondsSinceEpoch);

    setState(() {
      _updateAvailable = false;
      _isCheckingForUpdate = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If checking for updates or there's an update available, show the update screen
    if (_isCheckingForUpdate || _updateAvailable) {
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
                  if (_isCheckingForUpdate && !_updateAvailable) ...[
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(widget.primaryColor),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Checking for updates...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
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
                            'Downloading update: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
                            const Text(
                              'Update Available',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'A new version of the app is available',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _downloadUpdate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Download Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _remindLater,
                              child: Text(
                                'Remind me later',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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

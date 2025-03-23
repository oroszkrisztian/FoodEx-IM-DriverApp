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

  const ServerUpdateButton(
      {Key? key,
      this.buttonColor = Colors.green,
      this.textColor = Colors.white})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showServerUpdateDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(Globals.getText('checkForUpdates') ?? 'Check For Updates'),
    );
  }

  void _showServerUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while checking
      builder: (BuildContext context) => const ServerUpdateDialog(),
    );
  }
}

class UpdateState {
  final bool isChecking;
  final String statusMessage;
  final String currentVersion;
  final String serverVersion;
  final String downloadLink;
  final bool updateAvailable;
  final bool hasError;

  const UpdateState({
    this.isChecking = false,
    this.statusMessage = '',
    this.currentVersion = '',
    this.serverVersion = '',
    this.downloadLink = '',
    this.updateAvailable = false,
    this.hasError = false,
  });

  UpdateState copyWith({
    bool? isChecking,
    String? statusMessage,
    String? currentVersion,
    String? serverVersion,
    String? downloadLink,
    bool? updateAvailable,
    bool? hasError,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      statusMessage: statusMessage ?? this.statusMessage,
      currentVersion: currentVersion ?? this.currentVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      downloadLink: downloadLink ?? this.downloadLink,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      hasError: hasError ?? this.hasError,
    );
  }
}

class ServerUpdateDialog extends StatefulWidget {
  const ServerUpdateDialog({Key? key}) : super(key: key);

  @override
  State<ServerUpdateDialog> createState() => _ServerUpdateDialogState();
}

class _ServerUpdateDialogState extends State<ServerUpdateDialog> {
  late UpdateState _state;
  final Color primaryColor = const Color.fromARGB(255, 1, 160, 226);

  @override
  void initState() {
    super.initState();
    _state = UpdateState(
      isChecking: true,
      statusMessage:
          Globals.getText('downloadingUpdateFile') ?? 'Checking for updates...',
    );
    _checkForUpdates();
  }

  Future<void> _getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _state = _state.copyWith(
          currentVersion: packageInfo.version,
        );
      });
      print('Current version: ${_state.currentVersion}');
    } catch (e) {
      print('Error getting app version: $e');
      setState(() {
        _state = _state.copyWith(
          currentVersion: 'unknown',
          hasError: true,
        );
      });
    }
  }

  Future<void> _checkForUpdates() async {
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
          bool needsUpdate =
              _compareVersions(_state.currentVersion, serverVersion);

          setState(() {
            _state = _state.copyWith(
              serverVersion: serverVersion,
              downloadLink: downloadLink,
              updateAvailable: needsUpdate,
              isChecking: false,
              statusMessage: needsUpdate
                  ? (Globals.getText('updateAvailable') ?? 'Update Available')
                  : (Globals.getText('versionInfo') ?? 'Version Information'),
            );
          });
        } else {
          setState(() {
            _state = _state.copyWith(
              isChecking: false,
              statusMessage: responseData['message'] ??
                  Globals.getText('updateFailed') ??
                  'Update failed',
              hasError: true,
            );
          });
        }
      } else {
        setState(() {
          _state = _state.copyWith(
            isChecking: false,
            statusMessage:
                '${Globals.getText('error') ?? 'Error'}: ${response.statusCode}',
            hasError: true,
          );
        });
      }
    } catch (e) {
      print('Error checking for updates: $e');
      setState(() {
        _state = _state.copyWith(
          isChecking: false,
          statusMessage:
              '${Globals.getText('updateFailed') ?? 'Update failed'}: $e',
          hasError: true,
        );
      });
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

  // Launch URL to download the update
  Future<void> _downloadUpdate() async {
    if (_state.downloadLink.isEmpty) return;

    // Check if it's a Google Drive link
    bool isGoogleDriveLink = _state.downloadLink.contains('drive.google.com');

    if (Platform.isAndroid && isGoogleDriveLink) {
      // Handle Google Drive links on Android using Android Intent
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: _state.downloadLink,
          package: 'com.google.android.apps.docs',
        );
        await intent.launch();
        Navigator.of(context).pop();
      } catch (e) {
        print('Error launching Google Drive with intent: $e');
        // Fallback to browser if Google Drive app isn't installed
        _launchInBrowser(_state.downloadLink);
      }
    } else {
      // Handle other links or iOS
      _launchInBrowser(_state.downloadLink);
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
        _state = _state.copyWith(
          statusMessage:
              '${Globals.getText('updateFailed') ?? 'Update failed'}: $e',
          hasError: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 2,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              isSmallScreen ? screenSize.width * 0.85 : screenSize.width * 0.5,
          maxHeight: screenSize.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                _buildHeader(isSmallScreen),
                SizedBox(height: 20),

                // Content Section
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child: _state.isChecking
                      ? _buildLoadingState(isSmallScreen)
                      : _buildResultState(isSmallScreen),
                ),

                SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.update_rounded,
          color: primaryColor,
          size: isSmall ? 28 : 32,
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            _state.updateAvailable
                ? (Globals.getText('updateAvailable') ?? 'Update Available')
                : (Globals.getText('versionInfo') ?? 'Version Information'),
            style: TextStyle(
              fontSize: isSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isSmall) {
    return Container(
      key: const ValueKey('loading'),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            _state.statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(bool isSmall) {
    return Container(
      key: const ValueKey('result'),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Status Icon with animation
          TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _state.updateAvailable
                          ? Colors.orange.withOpacity(0.1)
                          : _state.hasError
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _state.updateAvailable
                          ? Icons.system_update_rounded
                          : _state.hasError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                      size: 40,
                      color: _state.updateAvailable
                          ? Colors.orange
                          : _state.hasError
                              ? Colors.red
                              : Colors.green,
                    ),
                  ),
                );
              }),
          SizedBox(height: 16),

          // Status Message
          Text(
            _state.statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.w500,
              color:
                  _state.hasError ? Colors.red.shade700 : Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16),

          // Version Tags
          if (_state.currentVersion.isNotEmpty ||
              (_state.updateAvailable && _state.serverVersion.isNotEmpty)) ...[
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 500),
              child: _state.updateAvailable && _state.serverVersion.isNotEmpty
                  ? LayoutBuilder(builder: (context, constraints) {
                      // For very small screens, use column layout
                      if (constraints.maxWidth < 200) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildVersionTag(
                              context,
                              _state.currentVersion,
                              Colors.grey.shade600,
                              isSmall,
                            ),
                            SizedBox(height: 8),
                            Icon(Icons.arrow_downward,
                                color: Colors.grey.shade400, size: 16),
                            SizedBox(height: 8),
                            _buildVersionTag(
                              context,
                              _state.serverVersion,
                              primaryColor,
                              isSmall,
                            ),
                          ],
                        );
                      }

                      // For larger screens, use row with flexible tags
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _buildVersionTag(
                              context,
                              _state.currentVersion,
                              Colors.grey.shade600,
                              isSmall,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward,
                              color: Colors.grey.shade400, size: 16),
                          SizedBox(width: 12),
                          Flexible(
                            child: _buildVersionTag(
                              context,
                              _state.serverVersion,
                              primaryColor,
                              isSmall,
                            ),
                          ),
                        ],
                      );
                    })
                  : _buildVersionTag(
                      context,
                      _state.currentVersion,
                      Colors.green,
                      isSmall,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Close Button
        Expanded(
          child: TextButton(
            onPressed: () async {
              Globals.isUpdateDialogShowing = false;
              if (_state.updateAvailable) {
                // Use the global method to postpone updates
                await Globals.postponeUpdates();

                // Show a toast or snackbar notification before closing
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(Globals.getText('updatePostponed1Hour') ??
                          'Update postponed for 1 hour'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(
              _state.updateAvailable
                  ? (Globals.getText('later1Hour') ?? 'Later (1 hour)')
                  : (Globals.getText('close') ?? 'Close'),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Download Button - only show if update available
        if (_state.updateAvailable &&
            _state.serverVersion.isNotEmpty &&
            !_state.isChecking) ...[
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _downloadUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                Globals.getText('update') ?? 'Update Now',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper method to create version tag widgets
  Widget _buildVersionTag(
      BuildContext context, String version, Color color, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 2),
          Text(
            version,
            style: TextStyle(
              fontSize: isSmall ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

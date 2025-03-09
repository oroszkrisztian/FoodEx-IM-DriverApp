import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:restart_app/restart_app.dart';
import 'package:foodex/globals.dart';

class ShorebirdService {
  // Singleton pattern
  static final ShorebirdService _instance = ShorebirdService._internal();
  factory ShorebirdService() {
    return _instance;
  }
  ShorebirdService._internal();

  final ShorebirdCodePush _shorebirdCodePush = ShorebirdCodePush();

  // API Methods

  // Check if an update is available
  Future<bool> isUpdateAvailable() async {
    try {
      return await _shorebirdCodePush.isNewPatchAvailableForDownload();
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }

  // Download the available update
  Future<void> downloadUpdate() async {
    try {
      await _shorebirdCodePush.downloadUpdateIfAvailable();

      // Store that we successfully downloaded an update
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('updateDownloaded', true);
    } catch (e) {
      print('Error downloading update: $e');
      rethrow;
    }
  }

  // Check if update button should be shown
  Future<bool> shouldShowUpdateButton() async {
    try {
      return await _shorebirdCodePush.isNewPatchAvailableForDownload();
    } catch (e) {
      print('Error checking if update button should be shown: $e');
      return false;
    }
  }

  // Check if a downloaded update is pending restart
  Future<bool> isRestartNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('updateDownloaded') ?? false;
    } catch (e) {
      print('Error checking if restart is needed: $e');
      return false;
    }
  }

  // Simulate download progress (since the API doesn't provide progress updates)
  Stream<double> simulateDownloadProgress() {
    StreamController<double> controller = StreamController<double>();
    double progress = 0.0;

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      progress += 0.01;
      if (progress >= 0.95) {
        progress = 0.95; // Hold at 95% until actual completion
        timer.cancel();
        controller.add(progress);
      } else {
        controller.add(progress);
      }
    });

    return controller.stream;
  }

  // Restart the app to apply the update
  Future<void> restartApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('updateDownloaded', false);
    await prefs.setBool('justUpdated', true);

    // Flush any pending SharedPreferences writes
    await prefs.commit();

    try {
      // Approach 1: Use the Restart package
      Restart.restartApp();
    } catch (e) {
      print('Primary restart method failed: $e');

      // Fallback: Use exit (requires user to manually restart on iOS)
      exit(0);
    }
  }

  // UI Methods

  // Shows the update popup dialog
  void showUpdatePopup(BuildContext context) async {
    // Show the dialog with initial checking state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _UpdateDialog(
          shorebirdService: this,
          parentContext: context,
          dialogContext: dialogContext,
        );
      },
    );
  }

  // Checking for updates UI
  Widget _buildCheckingUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const CircularProgressIndicator(
          color: Color.fromARGB(255, 1, 160, 226),
        ),
        const SizedBox(height: 20),
        Text(
          '${Globals.getText('checkingForUpdates')}...',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Error UI
  Widget _buildErrorUI(String errorMessage) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Downloading UI
  Widget _buildDownloadingUI(double progress) {
    return Column(
      children: [
        const SizedBox(height: 20),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color.fromARGB(255, 1, 160, 226),
          ),
          minHeight: 10,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 16),
        Text(
          '${Globals.getText('downloadingUpdate')}: ${(progress * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Download complete UI
  Widget _buildDownloadCompleteUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          Globals.getText('updateComplete'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          Globals.getText('restartToApply'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Update available UI
  Widget _buildUpdateAvailableUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(
          Icons.system_update,
          color: Colors.blue,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          Globals.getText('newVersionAvailable'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          Globals.getText('wouldYouLikeToUpdate'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // No updates UI
  Widget _buildNoUpdatesUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          Globals.getText('noUpdatesAvailable'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          Globals.getText('appUpToDate'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Build action buttons based on current state
  List<Widget> _buildActions({
    required bool isCheckingUpdate,
    required bool isUpdateAvailable,
    required bool isDownloading,
    required bool isDownloadComplete,
    required String? errorMessage,
    required Function() onCancel,
    required Function() onRetry,
    required Function() onDownloadUpdate,
    required Function() onRestartApp,
    required Function() onLater,
  }) {
    if (isCheckingUpdate) {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            Globals.getText('cancel'),
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
      ];
    } else if (errorMessage != null) {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            Globals.getText('close'),
            style: const TextStyle(
              color: Color.fromARGB(255, 1, 160, 226),
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            Globals.getText('tryAgain'),
            style: const TextStyle(
              color: Color.fromARGB(255, 1, 160, 226),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ];
    } else if (isDownloading) {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            Globals.getText('cancel'),
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
      ];
    } else if (isDownloadComplete) {
      return [
        TextButton(
          onPressed: onLater,
          child: Text(
            Globals.getText('later'),
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onRestartApp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 1, 160, 226),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(Globals.getText('restartNow')),
        ),
      ];
    } else if (isUpdateAvailable) {
      return [
        TextButton(
          onPressed: onLater,
          child: Text(
            Globals.getText('later'),
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onDownloadUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 1, 160, 226),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(Globals.getText('updateNow')),
        ),
      ];
    } else {
      return [
        TextButton(
          onPressed: onCancel,
          child: Text(
            Globals.getText('orderCancel'),
            style: const TextStyle(
              color: Color.fromARGB(255, 1, 160, 226),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ];
    }
  }
}

// Stateful widget to handle the update dialog
class _UpdateDialog extends StatefulWidget {
  final ShorebirdService shorebirdService;
  final BuildContext parentContext;
  final BuildContext dialogContext;

  const _UpdateDialog({
    Key? key,
    required this.shorebirdService,
    required this.parentContext,
    required this.dialogContext,
  }) : super(key: key);

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool isCheckingUpdate = true;
  bool isUpdateAvailable = false;
  bool isDownloading = false;
  bool isDownloadComplete = false;
  double downloadProgress = 0.0;
  String? errorMessage;
  StreamSubscription? progressSubscription;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  @override
  void dispose() {
    progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateAvailable = await widget.shorebirdService.isUpdateAvailable();

      if (mounted) {
        setState(() {
          isCheckingUpdate = false;
          isUpdateAvailable = updateAvailable;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isCheckingUpdate = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    if (mounted) {
      setState(() {
        isDownloading = true;
        isUpdateAvailable = false;
      });
    }

    // Start progress simulation
    progressSubscription =
        widget.shorebirdService.simulateDownloadProgress().listen(
      (progress) {
        if (mounted) {
          setState(() {
            downloadProgress = progress;
          });
        }
      },
    );

    try {
      await widget.shorebirdService.downloadUpdate();

      if (mounted) {
        // Complete the progress to 100%
        setState(() {
          downloadProgress = 1.0;
          isDownloading = false;
          isDownloadComplete = true;
        });
      }

      progressSubscription?.cancel();
    } catch (e) {
      progressSubscription?.cancel();

      if (mounted) {
        setState(() {
          isDownloading = false;
          errorMessage = 'Download failed: ${e.toString()}';
        });
      }
    }
  }

  void _onCancel() {
    progressSubscription?.cancel();
    Navigator.of(widget.dialogContext).pop();
  }

  void _onRetry() {
    if (mounted) {
      setState(() {
        isCheckingUpdate = true;
        errorMessage = null;
      });
    }
    _checkForUpdates();
  }

  void _onLater() {
    // Simply close the dialog without saving any timestamps
    progressSubscription?.cancel();
    Navigator.of(widget.dialogContext).pop();
  }

  void _onRestartApp() {
    progressSubscription?.cancel();
    Navigator.of(widget.dialogContext).pop();
    widget.shorebirdService.restartApp();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.all(0),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 1, 160, 226),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              Globals.getText('checkForUpdates'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show different UI based on the current state
              if (isCheckingUpdate) ...[
                widget.shorebirdService._buildCheckingUI(),
              ] else if (errorMessage != null) ...[
                widget.shorebirdService._buildErrorUI(errorMessage!),
              ] else if (isDownloading) ...[
                widget.shorebirdService._buildDownloadingUI(downloadProgress),
              ] else if (isDownloadComplete) ...[
                widget.shorebirdService._buildDownloadCompleteUI(),
              ] else if (isUpdateAvailable) ...[
                widget.shorebirdService._buildUpdateAvailableUI(),
              ] else ...[
                widget.shorebirdService._buildNoUpdatesUI(),
              ],
            ],
          ),
        ),
      ),
      actions: widget.shorebirdService._buildActions(
        isCheckingUpdate: isCheckingUpdate,
        isUpdateAvailable: isUpdateAvailable,
        isDownloading: isDownloading,
        isDownloadComplete: isDownloadComplete,
        errorMessage: errorMessage,
        onCancel: _onCancel,
        onRetry: _onRetry,
        onDownloadUpdate: _downloadUpdate,
        onRestartApp: _onRestartApp,
        onLater: _onLater,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}

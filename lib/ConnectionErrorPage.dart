import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foodex/globals.dart';

class ConnectionErrorPage extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onReloadApp;

  const ConnectionErrorPage({
    Key? key,
    required this.onRetry,
    required this.onReloadApp,
  }) : super(key: key);

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.wifi_off,
                          color: Colors.red,
                          size: isSmallScreen ? 48 : 56,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      Text(
                        Globals.getText('connectionProblem') ?? 'Connection Problem',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        Globals.getText('connectionErrorMessage') ?? 
                        'Unable to connect to the server.\nPlease check your internet connection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade700,
                              size: isSmallScreen ? 16 : 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              Globals.getText('checkConnection') ?? 'Check WiFi or mobile data',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 24 : 32),
                
                // Primary retry button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      
                      // Show loading state
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      );
                      
                      // Check connection
                      final hasConnection = await _hasInternetConnection();
                      Navigator.of(context).pop(); // Close loading dialog
                      
                      if (hasConnection) {
                        onRetry();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              Globals.getText('stillNoConnection') ?? 'Still no connection. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.refresh,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    label: Text(
                      Globals.getText('retryConnection') ?? 'Retry Connection',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 24 : 32,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 12 : 16),
                
                // Secondary reload app button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onReloadApp();
                    },
                    icon: Icon(
                      Icons.settings_backup_restore,
                      size: isSmallScreen ? 18 : 20,
                      color: const Color.fromARGB(255, 1, 160, 226),
                    ),
                    label: Text(
                      Globals.getText('reloadAppData') ?? 'Reload App Data',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: const Color.fromARGB(255, 1, 160, 226),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 24 : 32,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color.fromARGB(255, 1, 160, 226),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 20 : 24),
                
                // Help text
                Text( 
                  Globals.getText('connectionHelpText') ?? 
                  'If the problem persists, please contact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
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
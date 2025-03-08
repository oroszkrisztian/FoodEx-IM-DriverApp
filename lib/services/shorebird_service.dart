// shorebird_service.dart
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  // Singleton pattern
  static final ShorebirdService _instance = ShorebirdService._internal();
  
  factory ShorebirdService() {
    return _instance;
  }
  
  ShorebirdService._internal();
  
  final ShorebirdCodePush _shorebirdCodePush = ShorebirdCodePush();
  
  Future<bool> isUpdateAvailable() async {
    try {
      return await _shorebirdCodePush.isNewPatchAvailableForDownload();
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }
  
  Future<void> downloadUpdate() async {
    try {
      await _shorebirdCodePush.downloadUpdateIfAvailable();
    } catch (e) {
      print('Error downloading update: $e');
      rethrow;
    }
  }
  
  
  Future<bool> shouldShowUpdateButton() async {
    try {
      return await _shorebirdCodePush.isNewPatchAvailableForDownload();
    } catch (e) {
      print('Error checking if update button should be shown: $e');
      return false;
    }
  }
}
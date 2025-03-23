// This is the fix for the Globals.dart file
// The issue is that you have global flags for update dialog in both main.dart and Globals class

import 'dart:io';
import 'package:foodex/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Globals {
  static int? userId;
  static String? vehicleName;
  static int? vehicleID;
  static String? kmValue;
  static DateTime? startDate;
  static DateTime? endDate;
  static File? image1;
  static File? image2;
  static File? image3;
  static File? image4;
  static File? image5;
  static File? image6;
  static File? image7;
  static File? image8;
  static File? image9;
  static File? image10;
  static File? image;
  static int? ordersNumber;
  static File? parcursIn;
  static File? parcursOut;
  static var driver;

  // These are now the single source of truth for update dialog state
  static bool isUpdateDialogShowing = false;
  static DateTime? updatePostponedUntil;
  static String currentLanguage = 'en';

  

  static void clearRouteDates() {
    startDate = null;
    endDate = null;
  }

  static String getText(String key) {
    return Translations.getText(key, currentLanguage);
  }

  static bool get isUpdatePostponed {
    if (updatePostponedUntil == null) return false;
    return DateTime.now().isBefore(updatePostponedUntil!);
  }

  // Modified to persist the postponed time to SharedPreferences
  static Future<void> postponeUpdates() async {
    updatePostponedUntil = DateTime.now().add(const Duration(hours: 1));
    print('Updates postponed until: $updatePostponedUntil');

    // Save this to SharedPreferences so it persists between app sessions
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'updatePostponedUntil', updatePostponedUntil!.millisecondsSinceEpoch);
      print('Saved postpone time to SharedPreferences');
    } catch (e) {
      print('Error saving postpone time: $e');
    }
  }

  // Add a method to load the postponed time from SharedPreferences
  static Future<void> loadPostponeTime() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? postponedMillis = prefs.getInt('updatePostponedUntil');

      if (postponedMillis != null) {
        updatePostponedUntil =
            DateTime.fromMillisecondsSinceEpoch(postponedMillis);
        print('Loaded postpone time: $updatePostponedUntil');

        // If the loaded time is in the past, clear it
        if (updatePostponedUntil != null &&
            DateTime.now().isAfter(updatePostponedUntil!)) {
          updatePostponedUntil = null;
          await prefs.remove('updatePostponedUntil');
          print('Postpone time was in the past, cleared it');
        }
      }
    } catch (e) {
      print('Error loading postpone time: $e');
    }
  }
}

library my_app.globals;

import 'dart:io';

import 'package:foodex/translations.dart';

class Globals {
  static int? userId;
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


  static String currentLanguage = 'en';

  static void clearRouteDates() {
    startDate = null;
    endDate = null;
  }

  static String getText(String key) {
    return Translations.getText(key, currentLanguage);
  }
}

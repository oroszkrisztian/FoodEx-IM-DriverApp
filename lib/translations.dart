// This file contains all text translations for the app
class Translations {
  // Creating maps for each language containing the translated strings
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'driverPage': 'Driver Page',
      'myLogs': 'My Logs',
      'myCar': 'My Car',
      'expense': 'Expense',
      'shifts': 'Shifts',
      'loginVehicle': 'Login Vehicle',
      'logoutVehicle': 'Logout Vehicle',
      'loginAccount': 'Login Account',
      'logoutAccount': 'Logout Account',
      'submit': 'Submit',
      'logs': 'Logs',
      'selectLanguage': 'Select Language',
      'noOrdersFound': 'No orders found for today',
      'checkAgain': 'Check Again',
      'pleaseLoginVehicle': 'Please log in to a vehicle',
      'partner': 'Partner',
      'address': 'Address',
    },
    'hu': {
      'driverPage': 'Sofőr Oldal',
      'myLogs': 'Naplóim',
      'myCar': 'Autóm',
      'expense': 'Költség',
      'shifts': 'Műszakok',
      'loginVehicle': 'Jármű Bejelentkezés',
      'logoutVehicle': 'Jármű Kijelentkezés',
      'loginAccount': 'Fiók Bejelentkezés',
      'logoutAccount': 'Fiók Kijelentkezés',
      'submit': 'Küldés',
      'logs': 'Naplók',
      'selectLanguage': 'Nyelv Választása',
      'noOrdersFound': 'Nincs rendelés a mai napra',
      'checkAgain': 'Ellenőrzés Újra',
      'pleaseLoginVehicle': 'Kérjük, jelentkezzen be egy járműbe',
      'partner': 'Partner',
      'address': 'Cím',
    },
    'ro': {
      'driverPage': 'Pagina Șofer',
      'myLogs': 'Jurnalele Mele',
      'myCar': 'Mașina Mea',
      'expense': 'Cheltuială',
      'shifts': 'Ture',
      'loginVehicle': 'Conectare Vehicul',
      'logoutVehicle': 'Deconectare Vehicul',
      'loginAccount': 'Conectare Cont',
      'logoutAccount': 'Deconectare Cont',
      'submit': 'Trimite',
      'logs': 'Jurnale',
      'selectLanguage': 'Selectează Limba',
      'noOrdersFound': 'Nu există comenzi pentru astăzi',
      'checkAgain': 'Verifică Din Nou',
      'pleaseLoginVehicle': 'Vă rugăm să vă conectați la un vehicul',
      'partner': 'Partener',
      'address': 'Adresă',
    },
  };

  // Helper method to get translated text
  static String getText(String key, String language) {
    // Default to English if translation is missing
    return translations[language]?[key] ?? translations['en']![key]!;
  }
}
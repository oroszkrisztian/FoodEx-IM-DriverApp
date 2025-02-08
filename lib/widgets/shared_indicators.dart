import 'package:flutter/material.dart';

class SharedIndicators {
  static Widget buildIcon(IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color, width: 1.0),
      ),
      child: Icon(icon, size: 14, color: color[700]),
    );
  }

  static Widget buildContactStatus({
    required String name,
    required String telephone,
    required bool isSmallScreen,
  }) {
    final hasValidContact = name.isNotEmpty &&
        name != "N/A" &&
        telephone.isNotEmpty &&
        telephone != "N/A";
    final color = hasValidContact ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color, width: 1.0),
      ),
      child: Icon(
        Icons.person_rounded,
        size: isSmallScreen ? 14 : 16,
        color: color[700],
      ),
    );
  }

  static Widget buildDocumentIndicator(String text, bool isPresent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPresent ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

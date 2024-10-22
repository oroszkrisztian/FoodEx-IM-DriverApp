// lib/models/company.dart
class Company {
  final String companyName;
  final String type;

  Company({
    required this.companyName,
    required this.type,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      companyName: json['company_name'],
      type: json['type'],
    );
  }
}

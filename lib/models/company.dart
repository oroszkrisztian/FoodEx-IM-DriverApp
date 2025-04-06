// lib/models/company.dart
class Company {
  final String companyName;
  final String type;
  final int id;
  String details;
  String address;
  String telephone;
  String coordinates;
  List<String> photos;
  List<Map<String, String>> contactPeople;

  Company({
    required this.companyName,
    required this.type,
    required this.id,
    this.details = '',
    this.address = '',
    this.telephone = '',
    this.coordinates = '',
    List<String>? photos,
    List<Map<String, String>>? contactPeople,
  })  : photos = photos ?? [],
        contactPeople = contactPeople ?? [];

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['company_id'],
      companyName: json['company_name'],
      type: json['type'],
      details: json['details'] ?? '',
      address: json['address'] ?? '',
      telephone: json['telephone'] ?? '',
      coordinates: json['coordinates'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      contactPeople:
          List<Map<String, String>>.from(json['contact_people'] ?? []),
    );
  }
}

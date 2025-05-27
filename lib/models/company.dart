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
  }) : photos = photos ?? [],
       contactPeople = contactPeople ?? [];

  factory Company.fromJson(Map<String, dynamic> json) {
    // Handle photos - convert from various types to List<String>
    List<String> photosList = [];
    if (json['photos'] is List) {
      photosList = (json['photos'] as List)
          .map((photo) => photo.toString())
          .toList();
    }

    // Handle contact_people - convert from various types to List<Map<String, String>>
    List<Map<String, String>> contactPeopleList = [];
    if (json['contact_people'] is List) {
      contactPeopleList = (json['contact_people'] as List)
          .map((contact) {
            if (contact is Map) {
              return {
                'name': contact['name']?.toString() ?? '',
                'telephone': contact['telephone']?.toString() ?? '',
              };
            }
            return <String, String>{};
          })
          .where((contact) => contact.isNotEmpty)
          .toList();
    }

    return Company(
      id: json['company_id'] ?? json['id'] ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      coordinates: json['coordinates']?.toString() ?? '',
      photos: photosList,
      contactPeople: contactPeopleList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': id,
      'id': id, // For compatibility
      'company_name': companyName,
      'type': type,
      'details': details,
      'address': address,
      'telephone': telephone,
      'coordinates': coordinates,
      'photos': photos,
      'contact_people': contactPeople,
    };
  }
}
class ContactPerson {
  final String name;
  final String telephone;
  final String type;

  ContactPerson({
    required this.name,
    required this.telephone,
    required this.type,
  });

  factory ContactPerson.fromJson(Map<String, dynamic> json) {
    return ContactPerson(
      name: json['contact_person_name'] ?? 'Unknown',
      telephone: json['contact_person_telephone'] ?? 'N/A',
      type: json['type'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contact_person_name': name,
      'contact_person_telephone': telephone,
      'type': type,
    };
  }
}
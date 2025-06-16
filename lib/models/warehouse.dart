class Warehouse {
  final int id;
  final String warehouseName;
  final String warehouseAddress;
  final String warehouseLocation;
  final String type;
  final String? coordinates;
  String telephone;
  List<Map<String, String>> contactPeople;
  List<String> photos;

  Warehouse({
    required this.id,
    required this.warehouseName,
    required this.warehouseAddress,
    required this.warehouseLocation,
    required this.type,
    this.telephone = '',
    this.coordinates,
    List<String>? photos,
    List<Map<String, String>>? contactPeople,
  }) : photos = photos ?? [],
       contactPeople = contactPeople ?? [];

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    List<String> photosList = [];
    if (json['photos'] is List) {
      photosList = (json['photos'] as List)
          .map((photo) => photo.toString())
          .toList();
    }

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

    return Warehouse(
      id: json['warehouse_id'] ?? json['id'] ?? 0,
      warehouseName: json['warehouse_name']?.toString() ?? '',
      warehouseAddress: json['warehouse_address']?.toString() ?? '',
      warehouseLocation: json['warehouse_location']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      coordinates: json['coordinates']?.toString(),
      photos: photosList,
      contactPeople: contactPeopleList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warehouse_id': id,
      'id': id, 
      'warehouse_name': warehouseName,
      'warehouse_address': warehouseAddress,
      'warehouse_location' : warehouseLocation,
      'type': type,
      'telephone': telephone,
      'coordinates': coordinates,
      'photos': photos,
      'contact_people': contactPeople,
    };
  }
}
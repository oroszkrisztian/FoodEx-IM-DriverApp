class Warehouse {
  final String warehouseName;
  final String warehouseAddress;
  final String type;
  final String? coordinates; // Make this nullable

  Warehouse({
    required this.warehouseName,
    required this.warehouseAddress,
    required this.type,
    this.coordinates, // Nullable
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      warehouseName: json['warehouse_name'],
      warehouseAddress: json['warehouse_address'],
      type: json['type'],
      coordinates: json['warehouse_location'], // Will be null if not present
    );
  }
}

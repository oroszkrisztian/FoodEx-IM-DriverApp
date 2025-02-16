class CollectionUnit {
  final String id;
  final String type;
  final String name;
  final int quantity;

  CollectionUnit({
    required this.id,
    required this.type,
    required this.name,
    required this.quantity,
  });

  factory CollectionUnit.fromJson(Map<String, dynamic> json) {
    return CollectionUnit(
      id: json['collection_unit_id']?.toString() ?? '',
      type: json['collection_type']?.toString() ?? '',
      name: json['collection_unit_name']?.toString() ?? '',
      quantity: json['collection_quantity'] is int 
          ? json['collection_quantity'] 
          : int.tryParse(json['collection_quantity']?.toString() ?? '0') ?? 0,
    );
  }
}
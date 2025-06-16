class Car {
  final int id;
  final String make;
  final String model;
  final String licencePlate;

  Car({
    required this.id,
    required this.make,
    required this.model,
    required this.licencePlate,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id'] as int,
      make: json['make'] as String,
      model: json['model'] as String,
      licencePlate:
          json['license_plate'] as String, 
    );
  }
}

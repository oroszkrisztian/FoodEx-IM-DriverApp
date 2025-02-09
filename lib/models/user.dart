// lib/models/user.dart

class User {
  final int id;
  final String name;
  final String password;
  final String telephone;
  final String email;
  final int active;
  final String birthdate;
  final String drivingLicence;
  final String drivingLicenceValidity;
  final String drivingLicenceCategories;
  final String remarks;
  final int type;
  final String joinDate;
  final String status;
  final List<dynamic>? rights;

  User({
    required this.id,
    required this.name,
    required this.password,
    required this.telephone,
    required this.email,
    required this.active,
    required this.birthdate,
    required this.drivingLicence,
    required this.drivingLicenceValidity,
    required this.drivingLicenceCategories,
    required this.remarks,
    required this.type,
    required this.joinDate,
    required this.status,
    this.rights,
  });

  factory User.fromJson(Map<String, dynamic> json, [List<dynamic>? rights]) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      password: json['password'] as String,
      telephone: json['telephone'] as String,
      email: json['email'] as String,
      active: json['active'] as int,
      birthdate: json['birthdate'] as String,
      drivingLicence: json['driving_licence'] as String,
      drivingLicenceValidity: json['driving_licence_validity'] as String,
      drivingLicenceCategories: json['driving_licence_categories'] as String,
      remarks: json['remarks'] as String,
      type: json['type'] as int,
      joinDate: json['join_date'] as String,
      status: json['status'] as String,
      rights: rights,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'telephone': telephone,
      'email': email,
      'active': active,
      'birthdate': birthdate,
      'driving_licence': drivingLicence,
      'driving_licence_validity': drivingLicenceValidity,
      'driving_licence_categories': drivingLicenceCategories,
      'remarks': remarks,
      'type': type,
      'join_date': joinDate,
      'status': status,
      'rights': rights,
    };
  }
}
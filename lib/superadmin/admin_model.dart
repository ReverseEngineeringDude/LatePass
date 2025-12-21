import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  final String adminId;
  final String name;
  final String department;
  final bool isFaculty;
  final String email;
  final String password;

  Admin({
    required this.adminId,
    required this.name,
    required this.department,
    required this.isFaculty,
    required this.email,
    required this.password,
  });

  factory Admin.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Admin(
      adminId: doc.id,
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      isFaculty: data['isFaculty'] ?? false,
      email: data['email'] ?? '',
      password: data['password'] ?? '',
    );
  }

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      adminId: json['adminId'] ?? '',
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      isFaculty: json['isFaculty'] ?? false,
      email: json['email'] ?? '',
      password: json['password'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId,
      'name': name,
      'department': department,
      'isFaculty': isFaculty,
      'email': email,
      'password': password,
    };
  }
}

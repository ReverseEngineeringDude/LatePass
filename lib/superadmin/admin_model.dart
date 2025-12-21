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

class Student {
  final String id;
  final String name;
  final String department;
  final int year;

  Student({required this.id, required this.name, required this.department, required this.year});

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      department: json['department'],
      year: json['year'],
    );
  }
}

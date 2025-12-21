import 'package:flutter/material.dart';
import 'package:latepass/admin/show_reports_page.dart';
import 'package:latepass/superadmin/admin_model.dart';
import '../student/student_page.dart';
import '../admin/admin_page.dart';
import '../superadmin/superadmin_page.dart';

class LoginPage extends StatefulWidget {
  final List<Admin> admins;

  const LoginPage({super.key, required this.admins});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true;

  final Map<String, String> users = {
    "student@gmail.com": "student@123",
    "superadmin@gmail.com": "superadmin@123",
  };

  void login() {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (users.containsKey(email) && users[email] == password) {
      if (email == "student@gmail.com") {
        Navigator.pushReplacementNamed(context, '/student');
      } else if (email == "superadmin@gmail.com") {
        Navigator.pushReplacementNamed(context, '/superadmin');
      } else if (email == "admin@gmail.com") {
        Navigator.pushReplacementNamed(context, '/admin');
      }
    } else {
      final admin = widget.admins.firstWhere(
        (admin) => admin.email == email && admin.password == password,
        orElse: () => Admin(
          adminId: '',
          name: '',
          department: '',
          isFaculty: false,
          email: '',
          password: '',
        ),
      );

      if (admin.adminId.isNotEmpty) {
        if (admin.isFaculty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ShowReportsPage(
                isFaculty: true,
                department: admin.department,
              ),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/admin');
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Invalid credentials")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
              obscureText: _obscureText,
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: Text("Login")),
          ],
        ),
      ),
    );
  }
}

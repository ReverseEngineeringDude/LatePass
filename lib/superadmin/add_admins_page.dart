import 'package:flutter/material.dart';
import 'package:latepass/superadmin/admin_model.dart';

class AddAdminsPage extends StatefulWidget {
  final Function(Admin) onAddAdmin;

  AddAdminsPage({required this.onAddAdmin});

  @override
  _AddAdminsPageState createState() => _AddAdminsPageState();
}

class _AddAdminsPageState extends State<AddAdminsPage> {
  final _formKey = GlobalKey<FormState>();
  final _adminIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedDepartment;
  bool _isFaculty = false;
  bool _obscureText = true;

  // In a real app, this would come from a data source
  final List<String> _departments = [
    'Computer Engineering',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _adminIdController,
                decoration: InputDecoration(labelText: 'Admin ID'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an Admin ID';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: InputDecoration(labelText: 'Department'),
                items: _departments.map((String department) {
                  return DropdownMenuItem<String>(
                    value: department,
                    child: Text(department),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedDepartment = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a department' : null,
              ),
              SwitchListTile(
                title: Text('Is Faculty'),
                value: _isFaculty,
                onChanged: (bool value) {
                  setState(() {
                    _isFaculty = value;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final newAdmin = Admin(
                      adminId: _adminIdController.text,
                      name: _nameController.text,
                      department: _selectedDepartment!,
                      isFaculty: _isFaculty,
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    widget.onAddAdmin(newAdmin);
                    Navigator.pop(context);
                  }
                },
                child: Text('Add Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/superadmin/admin_model.dart';

class EditAdminPage extends StatefulWidget {
  final Admin admin;

  const EditAdminPage({super.key, required this.admin});

  @override
  _EditAdminPageState createState() => _EditAdminPageState();
}

class _EditAdminPageState extends State<EditAdminPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _selectedDepartment;
  late bool _isFaculty;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin.name);
    _emailController = TextEditingController(text: widget.admin.email);
    _selectedDepartment = widget.admin.department;
    _isFaculty = widget.admin.isFaculty;
  }

  final List<String> _departments = [
    'Computer Engineering',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final updatedAdmin = Admin(
          adminId: widget.admin.adminId,
          name: _nameController.text.trim(),
          department: _selectedDepartment!,
          isFaculty: _isFaculty,
          email: widget.admin.email, // Email is not editable
          password: widget.admin.password, // Password is not editable
        );

        await _firestore
            .collection('admins')
            .doc(widget.admin.adminId)
            .update(updatedAdmin.toJson());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update admin: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Admin')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Enter admin name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'admin@latepass.com',
                        icon: Icons.alternate_email_rounded,
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownField(),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text('Assign Faculty Status'),
                        subtitle: const Text(
                          'Grants classroom-specific access',
                        ),
                        value: _isFaculty,
                        onChanged: (bool value) {
                          setState(() => _isFaculty = value);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Action Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Update Admin',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade200 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required field';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Department",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.business_rounded,
              size: 20,
              color: Colors.grey.shade400,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _departments.map((String department) {
            return DropdownMenuItem<String>(
              value: department,
              child: Text(department, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (newValue) =>
              setState(() => _selectedDepartment = newValue),
          validator: (value) =>
              value == null ? 'Please select a department' : null,
        ),
      ],
    );
  }
}

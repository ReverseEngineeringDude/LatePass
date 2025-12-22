// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latepass/superadmin/admin_model.dart';

class ManageAdminsPage extends StatefulWidget {
  final Function(Admin) onAddAdmin;

  const ManageAdminsPage({super.key, required this.onAddAdmin});

  @override
  _ManageAdminsPageState createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedDepartment;
  bool _isFaculty = false;
  bool _obscureText = true;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color errorRed = Color(0xFFEF4444);

  final List<String> _departments = [
    'Computer Engineering',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  /// Creates a new admin account in Auth and Firestore
  Future<void> _createAdmin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Create user in Firebase Auth
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        final User? user = userCredential.user;
        if (user != null) {
          final newAdmin = Admin(
            adminId: user.uid,
            name: _nameController.text.trim(),
            department: _selectedDepartment!,
            isFaculty: _isFaculty,
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

          // Save to Firestore
          await _firestore
              .collection('admins')
              .doc(user.uid)
              .set(newAdmin.toJson());

          // Notify parent state
          widget.onAddAdmin(newAdmin);

          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin account created successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Authentication error'),
            backgroundColor: errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create admin record')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _selectedDepartment = null;
      _isFaculty = false;
    });
  }

  /// Updates an existing admin's metadata in Firestore
  Future<void> _updateAdmin(
    Admin admin,
    String name,
    String dept,
    bool faculty,
  ) async {
    try {
      await _firestore.collection('admins').doc(admin.adminId).update({
        'name': name,
        'department': dept,
        'isFaculty': faculty,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update failed'),
          backgroundColor: errorRed,
        ),
      );
    }
  }

  /// Deletes an admin's authorization document from Firestore
  Future<void> _deleteAdmin(Admin admin) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Admin Authority?'),
        content: Text(
          'This will remove all admin permissions for ${admin.name}. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: errorRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('admins').doc(admin.adminId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin removed from database'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion failed'),
            backgroundColor: errorRed,
          ),
        );
      }
    }
  }

  void _showEditDialog(Admin admin) {
    final nameEdit = TextEditingController(text: admin.name);
    String? deptEdit = admin.department;
    bool facultyEdit = admin.isFaculty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text('Edit Admin: ${admin.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                controller: nameEdit,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildDialogDropdown<String>(
                label: 'Department',
                value: deptEdit,
                items: _departments,
                icon: Icons.business_rounded,
                onChanged: (val) => setDialogState(() => deptEdit = val),
              ),
              SwitchListTile(
                title: const Text(
                  'Faculty Privileges',
                  style: TextStyle(fontSize: 14),
                ),
                value: facultyEdit,
                onChanged: (val) => setDialogState(() => facultyEdit = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateAdmin(
                  admin,
                  nameEdit.text.trim(),
                  deptEdit!,
                  facultyEdit,
                );
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Admin Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Registration Form
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Register New Administrator",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildRegistrationCard(),
                  const SizedBox(height: 32),
                  const Text(
                    "Active Administrators",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Admin List
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('admins').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('Error loading admins')),
                );
              }
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final admins = snapshot.data!.docs
                  .map((doc) => Admin.fromFirestore(doc))
                  .toList();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildAdminTile(admins[index]),
                  childCount: admins.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'John Doe',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'admin@latepass.com',
              icon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Initial Password',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            _buildDialogDropdown<String>(
              label: 'Department',
              value: _selectedDepartment,
              items: _departments,
              icon: Icons.business_rounded,
              onChanged: (val) => setState(() => _selectedDepartment = val),
            ),
            SwitchListTile(
              title: const Text(
                'Faculty Member',
                style: TextStyle(fontSize: 14),
              ),
              value: _isFaculty,
              onChanged: (val) => setState(() => _isFaculty = val),
              activeColor: primaryBlue,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Admin Account',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTile(Admin admin) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withOpacity(0.1),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: primaryBlue,
            size: 20,
          ),
        ),
        title: Text(
          admin.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${admin.department} • ${admin.isFaculty ? 'Faculty' : 'Staff'}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: primaryBlue,
                size: 20,
              ),
              onPressed: () => _showEditDialog(admin),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: errorRed,
                size: 20,
              ),
              onPressed: () => _deleteAdmin(admin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDialogDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required IconData icon,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(item.toString())),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

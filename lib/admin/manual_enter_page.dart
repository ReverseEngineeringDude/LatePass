import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_model.dart';
import 'package:latepass/admin/todays_attendance_page.dart';

class ManualEnterPage extends StatefulWidget {
  const ManualEnterPage({super.key});

  @override
  State<ManualEnterPage> createState() => _ManualEnterPageState();
}

class _ManualEnterPageState extends State<ManualEnterPage> {
  final TextEditingController _controller = TextEditingController();
  Student? _student;
  bool _isSearching = false;
  bool _isMarking = false;

  Future<void> _findStudent() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isSearching = true;
      _student = null;
    });

    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(id)
          .get();

      if (!mounted) return;

      if (studentDoc.exists) {
        setState(() {
          _student = Student.fromFirestore(studentDoc);
        });
      } else {
        setState(() {
          _student = Student(
            id: 'NOT_FOUND',
            name: 'Student Not Found',
            department: '',
            year: 0,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching for student')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
        FocusScope.of(context).unfocus();
      }
    }
  }

  Future<void> _addStudentToAttendance() async {
    if (_student == null || _student!.id == 'NOT_FOUND') return;

    setState(() => _isMarking = true);
    final theme = Theme.of(context);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check for duplicate entry
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: _student!.id)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      if (!mounted) return;

      if (attendanceQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance already marked for today'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isMarking = false);
        return;
      }

      final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin';

      await FirebaseFirestore.instance.collection('attendance').add({
        'studentId': _student!.id,
        'timestamp': FieldValue.serverTimestamp(),
        'markedBy': adminId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_student!.name} marked as present'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TodaysAttendancePage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to mark attendance'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Manual Entry'), centerTitle: true),
      body: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  if (_student == null && !_isSearching)
                    _buildStateHint(
                      theme,
                      Icons.qr_code_scanner_rounded,
                      "Enter a Student ID to begin",
                      "This will fetch details from the cloud database.",
                    ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: CircularProgressIndicator(),
                    ),
                  if (_student != null &&
                      _student!.id != 'NOT_FOUND' &&
                      !_isSearching)
                    _buildStudentResultCard(theme),
                  if (_student != null &&
                      _student!.id == 'NOT_FOUND' &&
                      !_isSearching)
                    _buildStateHint(
                      theme,
                      Icons.no_accounts_rounded,
                      "Student Not Found",
                      "The ID entered does not match any existing record.",
                      isError: true,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "QUICK MARKING",
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _findStudent(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Enter Student ID...',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(
                      0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: _isSearching ? null : _findStudent,
                icon: const Icon(Icons.search_rounded),
                style: IconButton.styleFrom(
                  minimumSize: const Size(54, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentResultCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    _student!.name.isNotEmpty
                        ? _student!.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _student!.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Student ID: ${_student!.id}",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildInfoRow(
                  theme,
                  Icons.business_rounded,
                  "Department",
                  _student!.department,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  theme,
                  Icons.school_rounded,
                  "Academic Year",
                  "Year ${_student!.year}",
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _isMarking ? null : _addStudentToAttendance,
                    icon: _isMarking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _isMarking ? 'Processing...' : 'Mark as Present',
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStateHint(
    ThemeData theme,
    IconData icon,
    String title,
    String subtitle, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    (isError
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary)
                        .withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color:
                    (isError
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary)
                        .withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

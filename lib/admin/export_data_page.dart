// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  _ExportDataPageState createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  bool _isExporting = false;

  // Theme Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundGrey = Color(0xFFF8FAFC);

  /// Hardcoded headers to ensure the export structure is always consistent
  final List<String> _exportHeaders = [
    'Timestamp',
    'Student ID',
    'Name',
    'Department',
    'Year',
    'Marked By',
  ];

  /// Strictly null-safe data preparation
  Future<List<List<String>>> _prepareDataAsList() async {
    try {
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .get();
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      // Build student lookup map safely
      final Map<String, Map<String, dynamic>> studentLookup = {};
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          studentLookup[doc.id] = data;
        }
      }

      final List<List<String>> results = [];

      for (var doc in attendanceSnapshot.docs) {
        // Safe access to document data
        final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // Extract fields with fallback values to ensure NO NULLS enter the list
        final String studentId = data['studentId']?.toString() ?? 'N/A';
        final Map<String, dynamic>? student = studentLookup[studentId];

        // Safe Timestamp handling
        String formattedDate = 'N/A';
        try {
          final dynamic rawTs = data['timestamp'];
          if (rawTs is Timestamp) {
            formattedDate = rawTs.toDate().toString().split('.')[0];
          }
        } catch (_) {}

        // Construct a row where every element is guaranteed to be a non-null String
        results.add([
          formattedDate,
          studentId,
          student?['name']?.toString() ?? 'Unknown',
          student?['department']?.toString() ?? 'Unknown',
          student?['year']?.toString() ?? 'N/A',
          data['markedBy']?.toString() ?? 'System',
        ]);
      }
      return results;
    } catch (e) {
      debugPrint("Error preparing data: $e");
      return [];
    }
  }

  Future<void> _handleExport(String type) async {
    setState(() => _isExporting = true);
    try {
      final List<List<String>> tableData = await _prepareDataAsList();

      if (tableData.isEmpty) {
        throw Exception("No data found to export.");
      }

      final directory = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "LatePass_Export_$timestamp";
      File? file;

      if (type == 'EXCEL') {
        final excel = Excel.createExcel();
        final sheetName = 'Attendance';
        final sheet = excel[sheetName];
        excel.delete('Sheet1'); // Cleanup default sheet

        // Append Header
        sheet.appendRow(_exportHeaders.map((e) => TextCellValue(e)).toList());

        // Append Rows
        for (final row in tableData) {
          sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
        }

        final fileBytes = excel.save();
        if (fileBytes == null)
          throw Exception("Failed to generate Excel file.");

        file = File('${directory.path}/$fileName.xlsx');
        await file.writeAsBytes(fileBytes);
      } else if (type == 'CSV') {
        file = File('${directory.path}/$fileName.csv');
        final List<List<String>> csvRows = [_exportHeaders, ...tableData];
        String csvData = const ListToCsvConverter().convert(csvRows);
        await file.writeAsString(csvData);
      } else if (type == 'TXT') {
        file = File('${directory.path}/$fileName.txt');
        
        // Use a CSV converter for a robust, well-formatted text table
        final List<List<String>> textRows = [_exportHeaders, ...tableData];
        // Using tabs for clear column separation in plain text
        String textData = const ListToCsvConverter(fieldDelimiter: '\t', eol: '\n').convert(textRows);
        
        final buffer = StringBuffer();
        buffer.writeln("LatePass Attendance Report");
        buffer.writeln("Generated: ${DateTime.now().toString().split('.')[0]}");
        buffer.writeln("========================================");
        buffer.write(textData);

        await file.writeAsString(buffer.toString());
      }

      if (file != null && await file.exists()) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'LatePass Export ($type)');
      } else {
        throw Exception("Could not create export file.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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
          'Export Center',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Data Management",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Export Attendance",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Share your attendance records in PDF, Excel, or CSV formats.",
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isExporting
                ? const Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  )
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildExportCard(
                        title: "Excel Spreadsheet (XLSX)",
                        subtitle: "Best for data analysis",
                        icon: Icons.grid_on_rounded,
                        color: Colors.green.shade700,
                        onTap: () => _handleExport('EXCEL'),
                      ),
                      const SizedBox(height: 16),
                      _buildExportCard(
                        title: "CSV Spreadsheet",
                        subtitle: "Compatible with all spreadsheet apps",
                        icon: Icons.table_chart_rounded,
                        color: Colors.green,
                        onTap: () => _handleExport('CSV'),
                      ),
                      const SizedBox(height: 16),
                      _buildExportCard(
                        title: "Text Document (TXT)",
                        subtitle: "Simple plain text for universal compatibility",
                        icon: Icons.description_rounded,
                        color: Colors.blueGrey,
                        onTap: () => _handleExport('TXT'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black45, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_for_offline_rounded,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }
}

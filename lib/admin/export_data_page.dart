import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
// Hiding Border from excel package to avoid conflict with Flutter's Border class
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  bool _isExporting = false;

  /// Hardcoded headers for consistent data structure
  final List<String> _exportHeaders = [
    'Timestamp',
    'Student ID',
    'Name',
    'Department',
    'Year',
    'Marked By',
  ];

  /// Strictly null-safe data preparation with optimized lookup
  Future<List<List<String>>> _prepareDataAsList() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('attendance').get(),
        FirebaseFirestore.instance.collection('students').get(),
      ]);

      final attendanceSnapshot = results[0] as QuerySnapshot;
      final studentsSnapshot = results[1] as QuerySnapshot;

      // Build student lookup map
      final Map<String, Map<String, dynamic>> studentLookup = {
        for (var doc in studentsSnapshot.docs)
          doc.id: doc.data() as Map<String, dynamic>,
      };

      final List<List<String>> tableRows = [];

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final String studentId = data['studentId']?.toString() ?? 'N/A';
        final student = studentLookup[studentId];

        String formattedDate = 'N/A';
        final dynamic rawTs = data['timestamp'];
        if (rawTs is Timestamp) {
          formattedDate = rawTs.toDate().toString().split('.')[0];
        }

        tableRows.add([
          formattedDate,
          studentId,
          student?['name']?.toString() ?? 'Unknown',
          student?['department']?.toString() ?? 'Unknown',
          student?['year']?.toString() ?? 'N/A',
          data['markedBy']?.toString() ?? 'System',
        ]);
      }
      return tableRows;
    } catch (e) {
      debugPrint("Export Error: $e");
      return [];
    }
  }

  Future<void> _handleExport(String type) async {
    setState(() => _isExporting = true);

    try {
      final List<List<String>> tableData = await _prepareDataAsList();

      if (tableData.isEmpty) {
        throw Exception("No attendance records found to export.");
      }

      final directory = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "LatePass_Export_$timestamp";
      File? file;

      if (type == 'EXCEL') {
        final excel = Excel.createExcel();
        const sheetName = 'Attendance';
        final sheet = excel[sheetName];
        excel.delete('Sheet1');

        sheet.appendRow(_exportHeaders.map((e) => TextCellValue(e)).toList());
        for (final row in tableData) {
          sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
        }

        final fileBytes = excel.save();
        if (fileBytes == null) {
          throw Exception("Failed to generate Excel file.");
        }

        file = File('${directory.path}/$fileName.xlsx');
        await file.writeAsBytes(fileBytes);
      } else if (type == 'CSV') {
        file = File('${directory.path}/$fileName.csv');
        final List<List<String>> csvRows = [_exportHeaders, ...tableData];
        String csvData = const ListToCsvConverter().convert(csvRows);
        await file.writeAsString(csvData);
      } else if (type == 'TXT') {
        file = File('${directory.path}/$fileName.txt');
        final List<List<String>> textRows = [_exportHeaders, ...tableData];
        String textData = const ListToCsvConverter(
          fieldDelimiter: '\t',
          eol: '\n',
        ).convert(textRows);

        final buffer = StringBuffer();
        buffer.writeln("LatePass Attendance Report");
        buffer.writeln("Generated: ${DateTime.now().toString().split('.')[0]}");
        buffer.writeln("=" * 40);
        buffer.write(textData);
        await file.writeAsString(buffer.toString());
      }

      if (file != null && await file.exists()) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'LatePass Attendance Export');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Export Center'), centerTitle: true),
      body: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: _isExporting
                ? _buildLoadingState(theme)
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildExportOption(
                        theme,
                        title: "Excel Spreadsheet",
                        subtitle: "XLSX format • Best for analysis",
                        icon: Icons.table_view_rounded,
                        color: Colors.green,
                        onTap: () => _handleExport('EXCEL'),
                      ),
                      _buildExportOption(
                        theme,
                        title: "CSV Document",
                        subtitle: "Comma Separated • Universal support",
                        icon: Icons.analytics_outlined,
                        color: Colors.teal,
                        onTap: () => _handleExport('CSV'),
                      ),
                      _buildExportOption(
                        theme,
                        title: "Text File",
                        subtitle: "TXT format • Simple plain text",
                        icon: Icons.article_outlined,
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
            "DATA MANAGEMENT",
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Export Records",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Download and share attendance logs in your preferred format.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.disabledColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Preparing your file...',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching records from the cloud',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

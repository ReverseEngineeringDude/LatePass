// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  bool _isExporting = false;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Default to the current day
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// Hardcoded headers for consistent data structure
  final List<String> _exportHeaders = [
    'Student ID',
    'Name',
    'Department',
    'Year',
    'Timestamp',
  ];

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Ensure the end date covers the full day
        _selectedDateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
      });
    }
  }

  Future<List<List<String>>> _prepareDataAsList() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('attendance').get(),
        FirebaseFirestore.instance.collection('students').get(),
      ]);

      final attendanceSnapshot = results[0] as QuerySnapshot;
      final studentsSnapshot = results[1] as QuerySnapshot;

      final Map<String, Map<String, dynamic>> studentLookup = {
        for (var doc in studentsSnapshot.docs)
          doc.id: doc.data() as Map<String, dynamic>,
      };

      final List<List<String>> tableRows = [];

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final dynamic rawTs = data['timestamp'];
        if (rawTs is! Timestamp) continue;

        final DateTime attendanceDate = rawTs.toDate();

        // Apply Date Range Filter in Memory (Rule 2)
        if (_selectedDateRange != null) {
          if (attendanceDate.isBefore(_selectedDateRange!.start) ||
              attendanceDate.isAfter(_selectedDateRange!.end)) {
            continue;
          }
        }

        final String studentId = data['studentId']?.toString() ?? 'N/A';
        final student = studentLookup[studentId];

        tableRows.add([
          studentId,
          student?['name']?.toString() ?? 'Unknown',
          student?['department']?.toString() ?? 'Unknown',
          student?['year']?.toString() ?? 'N/A',
          DateFormat('yyyy-MM-dd HH:mm').format(attendanceDate),
        ]);
      }

      // Sort by timestamp descending
      tableRows.sort((a, b) => b[0].compareTo(a[0]));

      return tableRows;
    } catch (e) {
      debugPrint("Export Data Prep Error: $e");
      return [];
    }
  }

  Future<void> _handleExport(String type) async {
    setState(() => _isExporting = true);

    try {
      final List<List<String>> tableData = await _prepareDataAsList();

      if (tableData.isEmpty) {
        throw Exception("No records found for the selected date range.");
      }

      final directory = await getTemporaryDirectory();
      final String dateLabel = DateFormat(
        'MMMdd',
      ).format(_selectedDateRange!.start);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "LatePass_Attendance_${dateLabel}_$timestamp";
      File? file;

      if (type == 'EXCEL') {
        final excel = Excel.createExcel();
        final sheet = excel['Attendance'];
        excel.delete('Sheet1');

        sheet.appendRow(_exportHeaders.map((e) => TextCellValue(e)).toList());
        for (final row in tableData) {
          sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
        }

        final fileBytes = excel.save();
        if (fileBytes == null) throw Exception("Excel generation failed.");

        file = File('${directory.path}/$fileName.xlsx');
        await file.writeAsBytes(fileBytes);
      } else if (type == 'CSV') {
        file = File('${directory.path}/$fileName.csv');
        final List<List<String>> csvRows = [_exportHeaders, ...tableData];
        String csvData = const ListToCsvConverter().convert(csvRows);
        await file.writeAsString(csvData);
      } else if (type == 'TXT') {
        file = File('${directory.path}/$fileName.txt');
        final buffer = StringBuffer();
        buffer.writeln("LATEPASS ATTENDANCE REPORT");
        buffer.writeln(
          "Range: ${DateFormat('yMMMd').format(_selectedDateRange!.start)} - ${DateFormat('yMMMd').format(_selectedDateRange!.end)}",
        );
        buffer.writeln(
          "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
        );
        buffer.writeln("=" * 60);

        final List<List<String>> textRows = [_exportHeaders, ...tableData];
        String formattedData = const ListToCsvConverter(
          fieldDelimiter: '\t',
          eol: '\n',
        ).convert(textRows);
        buffer.write(formattedData);

        await file.writeAsString(buffer.toString());
      }

      if (file != null && await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Attendance Report (${DateFormat('yMMMd').format(_selectedDateRange!.start)})',
        );
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Export Center',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(theme, isDark),
          Expanded(
            child: _isExporting
                ? _buildLoadingState(theme, isDark)
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      _buildExportOption(
                        theme,
                        isDark,
                        title: "Excel Spreadsheet",
                        subtitle: "XLSX format • Best for deep analysis",
                        icon: Icons.table_view_rounded,
                        color: Colors.greenAccent,
                        onTap: () => _handleExport('EXCEL'),
                      ),
                      _buildExportOption(
                        theme,
                        isDark,
                        title: "CSV Document",
                        subtitle: "Universal format • Light and fast",
                        icon: Icons.analytics_outlined,
                        color: Colors.tealAccent,
                        onTap: () => _handleExport('CSV'),
                      ),
                      _buildExportOption(
                        theme,
                        isDark,
                        title: "Plain Text",
                        subtitle: "TXT format • Simple readable log",
                        icon: Icons.article_outlined,
                        color: Colors.blueAccent,
                        onTap: () => _handleExport('TXT'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "FILTER & EXPORT",
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _buildDateRangeSelector(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(ThemeData theme, bool isDark) {
    final start = DateFormat('MMM dd').format(_selectedDateRange!.start);
    final end = DateFormat('MMM dd').format(_selectedDateRange!.end);

    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.date_range_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selected Range",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white38 : theme.disabledColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "$start - $end",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Change",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(
    ThemeData theme,
    bool isDark, {
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
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.1),
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark
                    ? Colors.white10
                    : theme.disabledColor.withOpacity(0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 32),
          Text(
            'Compiling Records...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching data from the secure registry',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white38 : theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

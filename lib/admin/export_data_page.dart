import 'package:flutter/material.dart';

class ExportDataPage extends StatelessWidget {
  void _exportAsJson() {
    // Placeholder for JSON export logic
    print('Exporting as JSON...');
  }

  void _exportAsCsv() {
    // Placeholder for CSV export logic
    print('Exporting as CSV...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Export Data'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _exportAsJson,
              child: Text('Export as JSON'),
            ),
            ElevatedButton(
              onPressed: _exportAsCsv,
              child: Text('Export as CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeIdScreen extends StatefulWidget {
  final List<String> scannedCodes;
  final String scannerType;
  final VoidCallback onStartOver;

  const EmployeeIdScreen({
    super.key,
    required this.scannedCodes,
    required this.scannerType,
    required this.onStartOver,
  });

  @override
  State<EmployeeIdScreen> createState() => _EmployeeIdScreenState();
}

class _EmployeeIdScreenState extends State<EmployeeIdScreen> {
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  Future<void> _resetAssignmentsWorkingFile() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final File workingFile = File('${docsDir.path}/team_assignments.xlsx');
      if (await workingFile.exists()) {
        await workingFile.delete();
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  void _submitEmployeeId() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final file = await _generateExcel(
        employeeId: _employeeIdController.text.trim(),
        codes: widget.scannedCodes,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      _showExportBottomSheet(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year - 20);
    final DateTime last = DateTime(now.year + 20);

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: first,
      lastDate: last,
    );

    if (selected != null) {
      // Format as YYYY-MM-DD without adding a new dependency
      final String yyyy = selected.year.toString().padLeft(4, '0');
      final String mm = selected.month.toString().padLeft(2, '0');
      final String dd = selected.day.toString().padLeft(2, '0');
      _startDateController.text = '$yyyy-$mm-$dd';
    }
  }

  Future<File> _generateExcel({required String employeeId, required List<String> codes}) async {
    final bool isStore = widget.scannerType == 'Check In to Store';
    final String sheetName = isStore ? 'CheckIn' : 'Assignments';
    
    // For store check-ins, always create new file with timestamp
    if (isStore) {
      return await _createNewExcelFile(employeeId, codes, isStore, sheetName);
    }
    
    // For employee assignments, use the team.xlsx template from assets
    return await _createFromTemplate(employeeId, codes, sheetName);
  }
  
  Future<File> _createFromTemplate(String employeeId, List<String> codes, String sheetName) async {
    // Maintain a persistent working copy in app documents so data accumulates
    final docsDir = await getApplicationDocumentsDirectory();
    final String workingFilename = 'team_assignments.xlsx';
    final File workingFile = File('${docsDir.path}/$workingFilename');

    Uint8List fileBytes;
    if (await workingFile.exists()) {
      // Reuse previous file to append new rows
      fileBytes = await workingFile.readAsBytes();
      print('Loaded existing working Excel: ${workingFile.path}');
    } else {
      // First run: seed working file from asset template
      final String templatePath = 'assets/team.xlsx';
      final ByteData templateData = await DefaultAssetBundle.of(context).load(templatePath);
      fileBytes = templateData.buffer.asUint8List();
      await workingFile.writeAsBytes(fileBytes, flush: true);
      print('Created working Excel from template at: ${workingFile.path}');
    }

    // Decode the Excel file
    xls.Excel excel = xls.Excel.decodeBytes(fileBytes);
    
    // Use the default sheet (Sheet1) from the template
    excel.setDefaultSheet('Sheet1');
    final xls.Sheet sheet = excel['Sheet1'];
    
    // Debug: Print the current sheet structure
    print('Sheet name: ${excel.getDefaultSheet()}');
    print('Total rows in template: ${sheet.rows.length}');
    for (int i = 0; i < sheet.rows.length && i < 5; i++) {
      print('Row $i: ${sheet.rows[i].map((cell) => cell?.toString() ?? 'null').toList()}');
    }
    
    // Determine the first empty data row by inspecting actual cell values
    // The template has: Row 1 = title, Row 2 = headers, data starts at Row 3
    // We'll scan from Row 3 onward until we find a row where the first 3 columns are empty
    int nextRowIndex = 2; // zero-based index for Row 3
    int probeRow = 2; // start probing at Row 3 (0-based)
    while (true) {
      final bool c0Empty = (sheet
                  .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: probeRow))
                  .value ==
              null) ||
          (sheet
                  .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: probeRow))
                  .value
                  ?.toString()
                  .trim()
                  .isEmpty ??
              true);
      final bool c1Empty = (sheet
                  .cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: probeRow))
                  .value ==
              null) ||
          (sheet
                  .cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: probeRow))
                  .value
                  ?.toString()
                  .trim()
                  .isEmpty ??
              true);
      final bool c2Empty = (sheet
                  .cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: probeRow))
                  .value ==
              null) ||
          (sheet
                  .cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: probeRow))
                  .value
                  ?.toString()
                  .trim()
                  .isEmpty ??
              true);

      if (c0Empty && c1Empty && c2Empty) {
        nextRowIndex = probeRow;
        break;
      }
      probeRow += 1;
      // Safety guard to avoid infinite loops on strangely formatted files
      if (probeRow > 10000) {
        nextRowIndex = 2; // fallback to Row 3
        break;
      }
    }
    
    final String dateStart = _startDateController.text.trim();
    
    // Debug: Print the data we're about to add
    print('Adding ${codes.length} codes for employee: $employeeId');
    print('Start date: $dateStart');
    print('Next row index: $nextRowIndex');
    print('Current sheet rows: ${sheet.rows.length}');
    
    // Write new data directly into cells to preserve existing row formatting
    for (int i = 0; i < codes.length; i++) {
      final code = codes[i].trim();
      if (code.isEmpty) continue;

      final int targetRow = nextRowIndex + i; // zero-based row
      final int autoNumber = 10001 + (targetRow - 2);

      print('Writing row at 1-based row ${targetRow + 1}: AutoNumber=$autoNumber, Employee=$employeeId, Code=$code, Date=$dateStart');

      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: targetRow),
        xls.TextCellValue(autoNumber.toString()),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: targetRow),
        xls.TextCellValue(employeeId),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: targetRow),
        xls.TextCellValue(code),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: targetRow),
        xls.TextCellValue(''),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: targetRow),
        xls.TextCellValue(dateStart),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: targetRow),
        xls.TextCellValue(''),
      );
    }
    
    print('Total rows in sheet after adding: ${sheet.rows.length}');

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Unable to encode Excel');
    }

    // Save back to the working file so future runs append to existing data
    await workingFile.writeAsBytes(bytes, flush: true);

    // Also create a temporary copy for sharing to avoid exposing app docs path
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final String tempFilename = 'team_assignments_$timestamp.xlsx';
    final File tempFile = File('${tempDir.path}/$tempFilename');
    await tempFile.writeAsBytes(bytes, flush: true);

    return tempFile;
  }
  
  Future<File> _createNewExcelFile(String employeeId, List<String> codes, bool isStore, String sheetName) async {
    final xls.Excel excel = xls.Excel.createExcel();
    
    if (excel.getDefaultSheet() != sheetName) {
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    }
    excel.setDefaultSheet(sheetName);
    final xls.Sheet sheet = excel[sheetName];

    if (isStore) {
      // Store check-in: keep existing 2-column format
      sheet.appendRow(<xls.CellValue?>[
        xls.TextCellValue('Store ID'),
        xls.TextCellValue('Asset ID'),
      ]);

      for (final raw in codes) {
        final code = raw.trim();
        if (code.isEmpty) continue;
        sheet.appendRow(<xls.CellValue?>[
          xls.TextCellValue(employeeId),
          xls.TextCellValue(code),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Unable to encode Excel');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final String filename = 'store_checkin_${employeeId}_$timestamp.xlsx';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _showExportBottomSheet(File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Export Excel',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5F5F),
                  ),
                  textAlign: TextAlign.center,
                ),
                // const SizedBox(height: 16),
                // Text(
                //   file.path,
                //   style: const TextStyle(fontSize: 12, color: Colors.grey),
                //   textAlign: TextAlign.center,
                // ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Share.shareXFiles([
                        XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                      ], text: 'Employee assignment export');
                    },
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                // const SizedBox(height: 12),
                // // Save to local storage (shared preferences)
                // SizedBox(
                //   height: 56,
                //   child: ElevatedButton.icon(
                //     onPressed: _isSaving ? null : () async {
                //       setState(() { _isSaving = true; });
                //       try {
                //         await _saveAssignmentToLocal();
                //         if (!mounted) return;
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           const SnackBar(
                //             content: Text('Saved to device (local storage)'),
                //             backgroundColor: Color(0xFF2C5F5F),
                //           ),
                //         );
                //       } finally {
                //         if (mounted) setState(() { _isSaving = false; });
                //       }
                //     },
                //     icon: _isSaving
                //       ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                //       : const Icon(Icons.save_alt),
                //     label: Text(_isSaving ? 'Saving...' : 'Save'),
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.green,
                //       foregroundColor: Colors.white,
                //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await _saveToDocuments(file);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved to: ${saved.path}'),
                          backgroundColor: const Color(0xFF2C5F5F),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Save to device'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2C5F5F),
                      side: const BorderSide(color: Color(0xFF2C5F5F)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final saved = await _saveToDocuments(file);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved to: ${saved.path}'),
                          backgroundColor: const Color(0xFF2C5F5F),
                        ),
                      );

                      // Reset working Excel so next entry starts fresh (first row)
                      await _resetAssignmentsWorkingFile();

                      // Clear date for next entry
                      if (mounted) {
                        setState(() {
                          _startDateController.text = '';
                        });
                      }

                      // Start new session
                      widget.onStartOver();
                      if (!mounted) return;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Save and Start New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<File> _saveToDocuments(File tempFile) async {
    // Prefer a user-visible picker (Downloads/My Files) on mobile platforms
    try {
      final bytes = await tempFile.readAsBytes();
      final params = SaveFileDialogParams(
        data: bytes,
        fileName: tempFile.uri.pathSegments.last,
        mimeTypesFilter: const [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
      );
      final savedPath = await FlutterFileDialog.saveFile(params: params);
      if (savedPath != null) {
        return File(savedPath);
      }
    } catch (_) {
      // Fall through to app documents directory if picker not available
    }

    final docs = await getApplicationDocumentsDirectory();
    final target = File('${docs.path}/${tempFile.uri.pathSegments.last}');
    return tempFile.copy(target.path);
  }

  // Persist assignment locally using shared_preferences
  Future<void> _saveAssignmentToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'assignment:${_employeeIdController.text.trim()}';
    // Store as a JSON string list
    await prefs.setStringList(key, widget.scannedCodes);

    // Maintain an index of saved employee IDs for listing later
    final existing = prefs.getStringList('assignment:index') ?? <String>[];
    if (!existing.contains(key)) {
      existing.add(key);
      await prefs.setStringList('assignment:index', existing);
    }
  }

  void _showAssignmentDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Assignment Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5F5F),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Employee ID
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Employee ID:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _employeeIdController.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C5F5F),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Scanned Items
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Items (${widget.scannedCodes.length}):',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.scannedCodes.map((code) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $code',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scannerType == 'Check In to Store' ? 'Check In to Store' : 'Assign to Employee'),
        backgroundColor: const Color(0xFF2C5F5F),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C5F5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.scannerType == 'Check In to Store' ? Icons.store : Icons.people,
                          color: const Color(0xFF2C5F5F),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.scannerType == 'Check In to Store' ? 'Check In to Store' : 'Assign to Employee',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C5F5F),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.scannerType == 'Check In to Store' ? '${widget.scannedCodes.length} items to check in' : '${widget.scannedCodes.length} items to assign',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Employee ID Input
              Text(
                widget.scannerType == 'Check In to Store' ? 'Store ID' : 'Employee ID',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C5F5F),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _employeeIdController,
                decoration: InputDecoration(
                  hintText: widget.scannerType == 'Check In to Store' ? 'Enter Store ID' : 'Enter Employee ID',
                  prefixIcon: Icon(widget.scannerType == 'Check In to Store' ? Icons.store : Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2C5F5F), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return widget.scannerType == 'Check In to Store' ? 'Please enter Store ID' : 'Please enter Employee ID';
                  }
                  if (value.length < 3) {
                    return widget.scannerType == 'Check In to Store' ? 'Store ID must be at least 3 characters' : 'Employee ID must be at least 3 characters';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitEmployeeId(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                onTap: _pickStartDate,
                decoration: InputDecoration(
                  hintText: 'Enter start date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2C5F5F), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 24),
              
              // Scanned Items List
              Text(
                widget.scannerType == 'Check In to Store' ? 'Items to Check In' : 'Items to Assign',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C5F5F),
                ),
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ListView.builder(
                    itemCount: widget.scannedCodes.length,
                    itemBuilder: (context, index) {
                      final code = widget.scannedCodes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2C5F5F).withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C5F5F),
                              ),
                            ),
                          ),
                          title: Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: Text(
                            widget.scannerType == 'Check In to Store' ? 'Store Item' : 'Scanned Item',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEmployeeId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5F5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.scannerType == 'Check In to Store' ? 'Check In to Store' : 'Assign to Employee',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Exit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Clear lists at source and return to start
                    widget.onStartOver();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text(
                    'Exit',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C5F5F),
                    side: const BorderSide(color: Color(0xFF2C5F5F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

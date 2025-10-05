import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class UpdateAssetScreen extends StatefulWidget {
  final List<String> scannedCodes;
  final VoidCallback onStartOver;

  const UpdateAssetScreen({
    super.key,
    required this.scannedCodes,
    required this.onStartOver,
  });

  @override
  State<UpdateAssetScreen> createState() => _UpdateAssetScreenState();
}

class _UpdateAssetScreenState extends State<UpdateAssetScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _existingTagNumberController = TextEditingController();
  final TextEditingController _equipmentStandardController = TextEditingController();
  final TextEditingController _siteCodeController = TextEditingController();
  final TextEditingController _buildingCodeController = TextEditingController();
  final TextEditingController _floorCodeController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _equipmentConditionController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  final TextEditingController _modelNumberController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();

  // Dropdown options for Equipment Condition
  final List<String> _conditionOptions = const ['New', 'Excellent', 'Good', 'Fair', 'Poor', 'Bad'];
  String? _selectedCondition;

  @override
  void initState() {
    super.initState();
    final preset = _equipmentConditionController.text.trim();
    _selectedCondition = preset.isNotEmpty ? preset : null;
  }

  @override
  void dispose() {
    _existingTagNumberController.dispose();
    _equipmentStandardController.dispose();
    _siteCodeController.dispose();
    _buildingCodeController.dispose();
    _floorCodeController.dispose();
    _roomCodeController.dispose();
    _equipmentConditionController.dispose();
    _manufacturerController.dispose();
    _modelNumberController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }

  void _submit() async {
    // No required fields; proceed to export
    try {
      final file = await _generateExcel(
        codes: widget.scannedCodes,
      );

      if (!mounted) return;
      _showExportBottomSheet(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<File> _generateExcel({required List<String> codes}) async {
    // Maintain a persistent working copy in app documents so data accumulates
    final docsDir = await getApplicationDocumentsDirectory();
    final String workingFilename = 'asset_information_working.xlsx';
    final File workingFile = File('${docsDir.path}/$workingFilename');

    Uint8List fileBytes;
    if (await workingFile.exists()) {
      fileBytes = await workingFile.readAsBytes();
    } else {
      // Seed from asset template
      const String templatePath = 'assets/asset_information.xlsx';
      final ByteData templateData = await DefaultAssetBundle.of(context).load(templatePath);
      fileBytes = templateData.buffer.asUint8List();
      await workingFile.writeAsBytes(fileBytes, flush: true);
    }

    // Decode Excel
    xls.Excel excel = xls.Excel.decodeBytes(fileBytes);

    // Use default sheet (assume Sheet1)
    final String defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.setDefaultSheet(defaultSheetName);
    final xls.Sheet sheet = excel[defaultSheetName];

    // Determine first empty data row by checking first column
    int nextRowIndex = 1; // assume headers at row 1 (0-based 0). Start appending at row 2 (index 1)
    int probeRow = 1;
    while (true) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: probeRow));
      final String value = (cell.value?.toString() ?? '').trim();
      if (value.isEmpty) {
        nextRowIndex = probeRow;
        break;
      }
      probeRow += 1;
      if (probeRow > 100000) {
        nextRowIndex = probeRow;
        break;
      }
    }

    // Collect field values (empty allowed)
    final String existingTag = _existingTagNumberController.text.trim();
    final String eqStd = _equipmentStandardController.text.trim();
    final String siteId = _siteCodeController.text.trim();
    final String blId = _buildingCodeController.text.trim();
    final String flId = _floorCodeController.text.trim();
    final String rmId = _roomCodeController.text.trim();
    final String condition = _equipmentConditionController.text.trim();
    final String mfr = _manufacturerController.text.trim();
    final String modelNo = _modelNumberController.text.trim();
    final String serialNo = _serialNumberController.text.trim();

    // Append rows: columns in order
    // 0: eq.eq_id (scanned code)
    // 1: udf_existingtagn
    // 2: eq_std
    // 3: site_id
    // 4: bl_id
    // 5: fl_id
    // 6: rm_id
    // 7: condition
    // 8: mfr
    // 9: modelno
    // 10: num_serial
    for (int i = 0; i < codes.length; i++) {
      final String code = codes[i].trim();
      if (code.isEmpty) continue;
      final int row = nextRowIndex + i;

      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xls.TextCellValue(code),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        xls.TextCellValue(existingTag),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
        xls.TextCellValue(eqStd),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
        xls.TextCellValue(siteId),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
        xls.TextCellValue(blId),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
        xls.TextCellValue(flId),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
        xls.TextCellValue(rmId),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row),
        xls.TextCellValue(condition),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row),
        xls.TextCellValue(mfr),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row),
        xls.TextCellValue(modelNo),
      );
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row),
        xls.TextCellValue(serialNo),
      );
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Unable to encode Excel');
    }

    // Save back to working file to accumulate entries
    await workingFile.writeAsBytes(bytes, flush: true);

    // Create a temporary copy for sharing
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final String tempFilename = 'asset_information_$timestamp.xlsx';
    final File tempFile = File('${tempDir.path}/$tempFilename');
    await tempFile.writeAsBytes(bytes, flush: true);

    return tempFile;
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
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Share.shareXFiles([
                        XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                      ], text: 'Asset information export');
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<File> _saveToDocuments(File tempFile) async {
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
      // Fallback handled below
    }

    final docs = await getApplicationDocumentsDirectory();
    final target = File('${docs.path}/${tempFile.uri.pathSegments.last}');
    return tempFile.copy(target.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Asset Information'),
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
                      children: const [
                        Icon(
                          Icons.inventory_2,
                          color: Color(0xFF2C5F5F),
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Update Asset Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C5F5F),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.scannedCodes.length} item(s) selected',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scanned Items List (compact)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.scannedCodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final code = widget.scannedCodes[index];
                    return Chip(
                      label: Text(
                        code,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(color: Colors.grey[300]!),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(_existingTagNumberController, 'Existing Tag Number', Icons.tag),
                      const SizedBox(height: 12),
                      _buildTextField(_equipmentStandardController, 'Equipment Standrad', Icons.rule),
                      const SizedBox(height: 12),
                      _buildTextField(_siteCodeController, 'Site Code', Icons.public),
                      const SizedBox(height: 12),
                      _buildTextField(_buildingCodeController, 'Building Code', Icons.apartment),
                      const SizedBox(height: 12),
                      _buildTextField(_floorCodeController, 'Floor Code', Icons.stairs),
                      const SizedBox(height: 12),
                      _buildTextField(_roomCodeController, 'Room Code', Icons.meeting_room),
                      const SizedBox(height: 12),
                      _buildConditionDropdown(),
                      const SizedBox(height: 12),
                      _buildTextField(_manufacturerController, 'Manufacturer', Icons.business),
                      const SizedBox(height: 12),
                      _buildTextField(_modelNumberController, 'Model Number', Icons.confirmation_number),
                      const SizedBox(height: 12),
                      _buildTextField(_serialNumberController, 'Serial Number', Icons.numbers),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5F5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
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

  Widget _buildConditionDropdown() {
    return DropdownButtonFormField<String>(
      value: (_selectedCondition != null && _selectedCondition!.isNotEmpty) ? _selectedCondition : null,
      items: _conditionOptions
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(e),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedCondition = value;
          _equipmentConditionController.text = value ?? '';
        });
      },
      decoration: InputDecoration(
        hintText: 'Equipment Condition',
        prefixIcon: const Icon(Icons.fact_check),
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
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int requiredMin = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
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
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $hint';
        }
        if (value.trim().length < requiredMin) {
          return '$hint must be at least $requiredMin character(s)';
        }
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }
}



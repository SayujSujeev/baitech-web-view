import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'employee_id_screen.dart';
import 'update_asset_screen.dart';

class SimpleScannerScreen extends StatefulWidget {
  final String scannerType;
  final List<String> scannedCodes;
  final Function(String) onCodeScanned;
  final VoidCallback onStartOver;

  const SimpleScannerScreen({
    super.key,
    required this.scannerType,
    required this.scannedCodes,
    required this.onCodeScanned,
    required this.onStartOver,
  });

  @override
  State<SimpleScannerScreen> createState() => _SimpleScannerScreenState();
}

class _SimpleScannerScreenState extends State<SimpleScannerScreen> {
  MobileScannerController? _controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    print('Barcode detected: ${barcodes.length} barcodes found');
    
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      print('Raw barcode value: $code');
      
      if (code != null) {
        setState(() {
          _isScanning = false;
        });
        _showScannedCodeDialog(code);
      }
    }
  }

  void _showScannedCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: const Color(0xFF2C5F5F),
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'Code Scanned',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5F5F),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scanned Code:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Type: ${widget.scannerType}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isScanning = true;
                });
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onCodeScanned(code);
                setState(() {
                  _isScanning = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C5F5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add to List',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEmployeeScreen() {
    final bool isUpdateAssetFlow = widget.scannerType == 'Update Asset Information';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isUpdateAssetFlow
            ? UpdateAssetScreen(
                scannedCodes: widget.scannedCodes,
                onStartOver: widget.onStartOver,
              )
            : EmployeeIdScreen(
                scannedCodes: widget.scannedCodes,
                scannerType: widget.scannerType,
                onStartOver: widget.onStartOver,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scannerType} Scanner'),
        backgroundColor: const Color(0xFF2C5F5F),
        foregroundColor: Colors.white,
        actions: [
          if (widget.scannedCodes.isNotEmpty)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.list),
                  if (widget.scannedCodes.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${widget.scannedCodes.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                _showScannedList();
              },
              tooltip: 'View Scanned Codes',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
          ),
          
          // Scanner overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: const Color(0xFF2C5F5F),
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
          
          // Instructions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Position the barcode within the frame to scan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Flashlight toggle
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.black.withOpacity(0.5),
              onPressed: () {
                _controller?.toggleTorch();
              },
              child: const Icon(
                Icons.flash_on,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScannedList() {
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
                Text(
                  'Scanned Codes (${widget.scannedCodes.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5F5F),
                  ),
                ),
                const SizedBox(height: 20),
                
                // List of scanned codes
                if (widget.scannedCodes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No codes scanned yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: widget.scannedCodes.length,
                      itemBuilder: (context, index) {
                        final code = widget.scannedCodes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2C5F5F).withOpacity(0.1),
                              child: const Icon(
                                Icons.qr_code,
                                color: Color(0xFF2C5F5F),
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
                              '${widget.scannerType} - ${index + 1}',
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.scannedCodes.removeAt(index);
                                });
                                Navigator.pop(context);
                                _showScannedList();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                
                // Next button for both flows when there are scanned codes
                if (widget.scannedCodes.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToEmployeeScreen();
                      },
                      icon: const Icon(Icons.arrow_forward, size: 24),
                      label: Text(
                        'Next (${widget.scannedCodes.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.scannerType == 'Check In to Store' ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
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
}

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(rect.left, rect.top, rect.left + borderRadius, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderOffset;
    final cutOutHeight = cutOutSize < height ? cutOutSize : height - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutWidth,
      height: cutOutHeight,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw border
    final path = Path()
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + borderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.top - borderOffset,
          cutOutRect.left + borderRadius, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.left + borderLength, cutOutRect.top - borderOffset);

    canvas.drawPath(path, borderPaint);

    // Top right
    final path2 = Path()
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.top + borderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.top - borderOffset,
          cutOutRect.right - borderRadius, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.right - borderLength, cutOutRect.top - borderOffset);

    canvas.drawPath(path2, borderPaint);

    // Bottom left
    final path3 = Path()
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.bottom - borderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.bottom + borderOffset,
          cutOutRect.left + borderRadius, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.left + borderLength, cutOutRect.bottom + borderOffset);

    canvas.drawPath(path3, borderPaint);

    // Bottom right
    final path4 = Path()
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.bottom - borderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.bottom + borderOffset,
          cutOutRect.right - borderRadius, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.right - borderLength, cutOutRect.bottom + borderOffset);

    canvas.drawPath(path4, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'utils/webview_zoom.dart';
import 'simple_scanner_screen.dart';
import 'employee_id_screen.dart';

/// A web view screen that displays the KFUPM Archibus login page
class WebViewScreen extends StatefulWidget {
  /// The URL to load in the web view
  final String url;
  
  /// Optional title for the app bar
  final String? title;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _timeoutTimer;
  double _zoomScale = 1.0; // viewport scale, mimics Ctrl +/-
  static const double _zoomStep = 0.1; // 10% steps
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;
  static const Duration _timeoutDuration = Duration(seconds: 5);
  
  // Barcode scanning lists
  List<String> _employeeScannedCodes = [];
  List<String> _storeScannedCodes = [];

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress if needed
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            // Start timeout timer
            _timeoutTimer?.cancel();
            _timeoutTimer = Timer(_timeoutDuration, () {
              if (mounted && _isLoading) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            });
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            _timeoutTimer?.cancel();
            
            // Don't reset error state if we already have an error
            if (_hasError) {
              debugPrint('Error already detected, not resetting state');
              return;
            }
            
            // Check if we're on an error page immediately
            if (url.startsWith('chrome-error://') || url.startsWith('data:text/html')) {
              debugPrint('Detected error page URL: $url');
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
              return;
            }
            
            setState(() {
              _isLoading = false;
              _hasError = false;
            });
            // Apply current zoom after page is fully loaded
            final js = WebViewZoom.buildZoomScript(_zoomScale);
            _controller.runJavaScript(js);
            
            // Check if the page contains error indicators
            _checkForErrorPage();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            debugPrint('Error code: ${error.errorCode}');
            debugPrint('Error type: ${error.errorType}');
            _timeoutTimer?.cancel();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
              debugPrint('Error state set to true');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation requests
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    
    // Add a fallback check after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        debugPrint('Fallback check: Still loading after 2 seconds');
        _controller.runJavaScriptReturningResult('window.location.href').then((url) {
          debugPrint('Current URL: $url');
          final urlString = url.toString();
          if (urlString.startsWith('chrome-error://') || urlString.startsWith('data:text/html')) {
            debugPrint('Fallback detected error page');
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
        }).catchError((error) {
          debugPrint('Error getting URL: $error');
        });
      }
    });
  }

  void _reload() {
    _timeoutTimer?.cancel();
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.reload();
  }

  void _checkForErrorPage() {
    // JavaScript to check for common error page indicators and set a flag
    const errorCheckScript = '''
      (function() {
        var bodyText = document.body.innerText.toLowerCase();
        var title = document.title.toLowerCase();
        var url = window.location.href;
        
        // Check if we're on a chrome error page
        if (url.startsWith('chrome-error://') || url.startsWith('data:text/html')) {
          window.flutterErrorDetected = true;
          return;
        }
        
        // Check for common error indicators
        var errorIndicators = [
          'web page not available',
          'this site can\'t be reached',
          'err_name_not_resolved',
          'err_connection_refused',
          'err_timed_out',
          'dns_probe_finished_nxdomain',
          'this webpage is not available',
          'server not found',
          'connection timed out',
          'net::err_name_not_resolved',
          'net::err_connection_refused',
          'net::err_timed_out'
        ];
        
        for (var i = 0; i < errorIndicators.length; i++) {
          if (bodyText.includes(errorIndicators[i]) || title.includes(errorIndicators[i])) {
            window.flutterErrorDetected = true;
            return;
          }
        }
        
        window.flutterErrorDetected = false;
      })();
    ''';
    
    _controller.runJavaScript(errorCheckScript);
    
    // Check the flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _controller.runJavaScriptReturningResult('window.flutterErrorDetected').then((result) {
        debugPrint('Error check result: $result');
        if (result == 'true' && mounted) {
          debugPrint('Setting error state to true from JavaScript check');
          setState(() {
            _hasError = true;
          });
        }
      }).catchError((error) {
        debugPrint('Error checking for error page: $error');
      });
    });
  }

  void _applyZoom(double newScale) {
    final clamped = newScale.clamp(_minZoom, _maxZoom);
    setState(() {
      _zoomScale = clamped;
    });
    final js = WebViewZoom.buildZoomScript(_zoomScale);
    _controller.runJavaScript(js);
  }

  void _zoomIn() {
    _applyZoom(_zoomScale + _zoomStep);
  }

  void _zoomOut() {
    _applyZoom(_zoomScale - _zoomStep);
  }

  void _goBack() {
    _controller.goBack();
  }

  void _goForward() {
    _controller.goForward();
  }

  Future<bool> _canGoBack() async {
    return await _controller.canGoBack();
  }

  Future<bool> _canGoForward() async {
    return await _controller.canGoForward();
  }

  void _showScannerBottomSheet() {
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
                  'Scanner Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5F5F),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Assign to Employees button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAssignToEmployees();
                    },
                    icon: Stack(
                      children: [
                        const Icon(Icons.people, size: 24),
                        if (_employeeScannedCodes.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
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
                                '${_employeeScannedCodes.length}',
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
                    label: Text(
                      'Assign to Employees${_employeeScannedCodes.isNotEmpty ? ' (${_employeeScannedCodes.length})' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Check In to Store button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleCheckInToStore();
                    },
                    icon: Stack(
                      children: [
                        const Icon(Icons.store, size: 24),
                        if (_storeScannedCodes.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
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
                                '${_storeScannedCodes.length}',
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
                    label: Text(
                      'Check In to Store${_storeScannedCodes.isNotEmpty ? ' (${_storeScannedCodes.length})' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // View All Scanned Codes button
                if (_employeeScannedCodes.isNotEmpty || _storeScannedCodes.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAllScannedCodes();
                      },
                      icon: const Icon(Icons.list_alt, size: 20),
                      label: Text(
                        'View All Scanned Codes (${_employeeScannedCodes.length + _storeScannedCodes.length})',
                        style: const TextStyle(
                          fontSize: 14,
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
                const SizedBox(height: 16),
                
                // Next button - for both Employee and Store codes
                if (_employeeScannedCodes.isNotEmpty || _storeScannedCodes.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleNextButton();
                      },
                      icon: const Icon(Icons.arrow_forward, size: 24),
                      label: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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

  void _handleAssignToEmployees() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleScannerScreen(
          scannerType: 'Assign to Employees',
          scannedCodes: _employeeScannedCodes,
          onCodeScanned: (String code) {
            setState(() {
              _employeeScannedCodes.add(code);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Code added to Employee list: $code'),
                backgroundColor: const Color(0xFF2C5F5F),
                action: SnackBarAction(
                  label: 'View List',
                  textColor: Colors.white,
                  onPressed: () {
                    _showEmployeeList();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleCheckInToStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleScannerScreen(
          scannerType: 'Check In to Store',
          scannedCodes: _storeScannedCodes,
          onCodeScanned: (String code) {
            setState(() {
              _storeScannedCodes.add(code);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Code added to Store list: $code'),
                backgroundColor: const Color(0xFF2C5F5F),
                action: SnackBarAction(
                  label: 'View List',
                  textColor: Colors.white,
                  onPressed: () {
                    _showStoreList();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEmployeeList() {
    _showScannedListBottomSheet('Employee Codes', _employeeScannedCodes);
  }

  void _showStoreList() {
    _showScannedListBottomSheet('Store Codes', _storeScannedCodes);
  }

  void _handleNextButton() {
    // Determine which type has scanned codes
    if (_employeeScannedCodes.isNotEmpty && _storeScannedCodes.isNotEmpty) {
      // Both have codes, show selection dialog
      _showNextActionDialog();
    } else if (_employeeScannedCodes.isNotEmpty) {
      // Only employee codes, go to employee screen
      _navigateToEmployeeScreen();
    } else if (_storeScannedCodes.isNotEmpty) {
      // Only store codes, show store action
      _showStoreAction();
    }
  }

  void _showNextActionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Action'),
          content: const Text('You have scanned codes for both Employee and Store. Which action would you like to proceed with?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToEmployeeScreen();
              },
              child: const Text('Employee Assignment'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showStoreAction();
              },
              child: const Text('Store Check-in'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEmployeeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeIdScreen(
          scannedCodes: _employeeScannedCodes,
          scannerType: 'Assign to Employees',
        ),
      ),
    );
  }

  void _showStoreAction() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Store Check-in'),
          content: Text('You have ${_storeScannedCodes.length} items to check in to the store.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement store check-in functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Store check-in functionality will be implemented'),
                    backgroundColor: Color(0xFF2C5F5F),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C5F5F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Check In'),
            ),
          ],
        );
      },
    );
  }

  void _showAllScannedCodes() {
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
                  'All Scanned Codes (${_employeeScannedCodes.length + _storeScannedCodes.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5F5F),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Combined list
                if (_employeeScannedCodes.isEmpty && _storeScannedCodes.isEmpty)
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
                    height: 400,
                    child: ListView.builder(
                      itemCount: _employeeScannedCodes.length + _storeScannedCodes.length,
                      itemBuilder: (context, index) {
                        String code;
                        String type;
                        List<String> sourceList;
                        
                        if (index < _employeeScannedCodes.length) {
                          code = _employeeScannedCodes[index];
                          type = 'Employee';
                          sourceList = _employeeScannedCodes;
                        } else {
                          code = _storeScannedCodes[index - _employeeScannedCodes.length];
                          type = 'Store';
                          sourceList = _storeScannedCodes;
                        }
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: type == 'Employee' 
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              child: Icon(
                                type == 'Employee' ? Icons.people : Icons.store,
                                color: type == 'Employee' ? Colors.blue : Colors.green,
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
                              '$type Code - ${sourceList.indexOf(code) + 1}',
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
                                  sourceList.remove(code);
                                });
                                Navigator.pop(context);
                                _showAllScannedCodes();
                              },
                            ),
                          ),
                        );
                      },
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

  void _showScannedListBottomSheet(String title, List<String> codes) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$title (${codes.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5F5F),
                      ),
                    ),
                    if (codes.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showClearListDialog(title, codes);
                        },
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // List of scanned codes
                if (codes.isEmpty)
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
                      itemCount: codes.length,
                      itemBuilder: (context, index) {
                        final code = codes[index];
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
                              '$title - ${index + 1}',
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
                                  codes.removeAt(index);
                                });
                                Navigator.pop(context);
                                _showScannedListBottomSheet(title, codes);
                              },
                            ),
                          ),
                        );
                      },
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

  void _showClearListDialog(String title, List<String> codes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All $title'),
          content: const Text('Are you sure you want to clear all scanned codes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  codes.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All $title cleared'),
                    backgroundColor: const Color(0xFF2C5F5F),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Build called - _hasError: $_hasError, _isLoading: $_isLoading');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'KFUPM BAITECH',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C5F5F),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Reload button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _reload,
            tooltip: 'Reload',
          ),
          // Back button
          FutureBuilder<bool>(
            future: _canGoBack(),
            builder: (context, snapshot) {
              final canGoBack = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: canGoBack ? _goBack : null,
                tooltip: 'Go Back',
              );
            },
          ),
          // Zoom out button
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomScale > _minZoom ? _zoomOut : null,
            tooltip: 'Zoom Out',
          ),
          // Zoom in button
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomScale < _maxZoom ? _zoomIn : null,
            tooltip: 'Zoom In',
          ),
          // Forward button
          FutureBuilder<bool>(
            future: _canGoForward(),
            builder: (context, snapshot) {
              final canGoForward = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: canGoForward ? _goForward : null,
                tooltip: 'Go Forward',
              );
            },
          ),
        ],
      ),
      body: _hasError ? _buildMaintenanceView() : Stack(
        children: [
          // Web view
          WebViewWidget(controller: _controller),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C5F5F)),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2C5F5F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            onPressed: _showScannerBottomSheet,
            backgroundColor: const Color(0xFF2C5F5F),
            foregroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.qr_code_scanner, size: 28),
          ),
          if (_employeeScannedCodes.isNotEmpty || _storeScannedCodes.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                child: Text(
                  '${_employeeScannedCodes.length + _storeScannedCodes.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      // Bottom navigation bar with URL info
      // bottomNavigationBar: _currentUrl != null
      //     ? Container(
      //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      //         decoration: BoxDecoration(
      //           color: Colors.grey[100],
      //           border: Border(
      //             top: BorderSide(color: Colors.grey[300]!),
      //           ),
      //         ),
      //         child: Row(
      //           children: [
      //             const Icon(
      //               Icons.lock,
      //               size: 16,
      //               color: Color(0xFF2C5F5F),
      //             ),
      //             const SizedBox(width: 8),
      //             Expanded(
      //               child: Text(
      //                 _currentUrl!,
      //                 style: const TextStyle(
      //                   fontSize: 12,
      //                   color: Color(0xFF2C5F5F),
      //                 ),
      //                 overflow: TextOverflow.ellipsis,
      //               ),
      //             ),
      //           ],
      //         ),
      //       )
      //     : null,
    );
  }

  Widget _buildMaintenanceView() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Maintenance icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C5F5F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build,
                  size: 64,
                  color: Color(0xFF2C5F5F),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'App Under Maintenance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5F5F),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Description
              const Text(
                'We are currently performing maintenance on our services. Please try again later.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Retry button
              ElevatedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C5F5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

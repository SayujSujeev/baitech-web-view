import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'utils/webview_zoom.dart';

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
  double _zoomScale = 1.0; // viewport scale, mimics Ctrl +/-
  static const double _zoomStep = 0.1; // 10% steps
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
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
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Apply current zoom after page is fully loaded
            final js = WebViewZoom.buildZoomScript(_zoomScale);
            _controller.runJavaScript(js);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation requests
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    _controller.reload();
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

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
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
}

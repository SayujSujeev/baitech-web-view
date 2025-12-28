import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web-specific implementation of WebViewScreen using iframe
class WebViewScreenWeb extends StatefulWidget {
  final String url;
  final String? title;

  const WebViewScreenWeb({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<WebViewScreenWeb> createState() => _WebViewScreenWebState();
}

class _WebViewScreenWebState extends State<WebViewScreenWeb> {
  final String _iframeId = 'webview-iframe-${DateTime.now().millisecondsSinceEpoch}';
  late html.IFrameElement _iframeElement;

  @override
  void initState() {
    super.initState();
    _initializeIframe();
  }

  void _initializeIframe() {
    _iframeElement = html.IFrameElement()
      ..src = widget.url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    // Register the iframe with Flutter's platform view system
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) => _iframeElement,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KFUPM BAITECH',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C5F5F),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _iframeElement.src = widget.url;
            },
            tooltip: 'Reload',
          ),
        ],
      ),
      body: HtmlElementView(viewType: _iframeId),
    );
  }
}


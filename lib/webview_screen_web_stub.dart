// Stub file for mobile platforms - WebViewScreenWeb is only available on web
import 'package:flutter/material.dart';

class WebViewScreenWeb extends StatelessWidget {
  final String url;
  final String? title;

  const WebViewScreenWeb({
    super.key,
    required this.url,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // This should never be called on mobile
    return const Scaffold(
      body: Center(
        child: Text('WebViewScreenWeb is only available on web platform'),
      ),
    );
  }
}


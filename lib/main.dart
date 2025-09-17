import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'splash_screen.dart';
import 'webview_screen.dart';

void main() {
  // Initialize platform-specific implementations
  WebViewPlatform.instance = AndroidWebViewPlatform();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KFUPM BAITECH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C5F5F)),
        useMaterial3: true,
      ),
      home: const SplashScreen(
        nextScreen: WebViewScreen(
          url: 'https://fms.kfupm.edu.sa/archibus/login.axvw',
          title: 'KFUPM Archibus',
        ),
      ),
    );
  }
}


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import webview_flutter early to ensure web platform auto-initializes
import 'package:webview_flutter/webview_flutter.dart';
import 'splash_screen.dart';
import 'webview_screen.dart';

void main() {
  // Initialize platform-specific implementations
  if (!kIsWeb) {
    // On mobile platforms, manually set Android implementation
    if (WebViewPlatform.instance == null) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    }
  } else {
    // On web, webview_flutter should auto-initialize WebViewPlatform.instance
    // when the package is imported. If it's still null here, it will be initialized
    // when WebViewController is first created.
    // The import of webview_flutter above should trigger auto-registration.
  }
  
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
          // url: 'https://shras.office.asc-ro.com/archibus/login.axvw',
          // url: 'https://google.com',
          title: 'KFUPM Archibus',
        ),
      ),
    );
  }
}


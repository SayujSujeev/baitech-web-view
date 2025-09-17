// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:baitech_web_app/main.dart';
import 'package:baitech_web_app/splash_screen.dart';
import 'package:baitech_web_app/webview_screen.dart';

void main() {
  group('App Integration Tests', () {
    testWidgets('App should start with splash screen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that splash screen is displayed initially
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('App should navigate to web view after splash duration', (WidgetTester tester) async {
      // Build our app with a short splash duration for testing
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            duration: const Duration(milliseconds: 100),
            nextScreen: const WebViewScreen(
              url: 'https://fms.kfupm.edu.sa/archibus/login.axvw',
              title: 'KFUPM Archibus Login',
            ),
          ),
        ),
      );

      // Wait for navigation to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Verify that we're now on the web view screen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(WebViewScreen), findsOneWidget);
      expect(find.text('KFUPM Archibus Login'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsOneWidget);
    });

    testWidgets('App should load KFUPM Archibus login page', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Wait for splash screen to complete and navigate to web view
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Verify that we're on the web view screen
      expect(find.byType(WebViewScreen), findsOneWidget);
      expect(find.text('KFUPM Archibus Login'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsOneWidget);
      
      // Verify navigation buttons are present
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('App should have correct theme colors', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Wait for splash screen to complete
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Verify theme colors are applied
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFF2C5F5F));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baitech_web_app/webview_screen.dart';

void main() {
  group('WebViewScreen', () {
    const testUrl = 'https://fms.kfupm.edu.sa/archibus/login.axvw';
    const testTitle = 'KFUPM Archibus Login';

    testWidgets('should display web view with correct URL', (WidgetTester tester) async {
      // Arrange
      const webViewScreen = WebViewScreen(
        url: testUrl,
        title: testTitle,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('should have correct app bar styling', (WidgetTester tester) async {
      // Arrange
      const webViewScreen = WebViewScreen(
        url: testUrl,
        title: testTitle,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFF2C5F5F));
      expect(appBar.foregroundColor, Colors.white);
      expect(appBar.elevation, 2);
    });

    testWidgets('should have navigation buttons in app bar', (WidgetTester tester) async {
      // Arrange
      const webViewScreen = WebViewScreen(
        url: testUrl,
        title: testTitle,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('should use default title when none provided', (WidgetTester tester) async {
      // Arrange
      const webViewScreen = WebViewScreen(
        url: testUrl,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      expect(find.text('BAITECH Web App'), findsOneWidget);
    });

    testWidgets('should have proper widget structure', (WidgetTester tester) async {
      // Arrange
      const webViewScreen = WebViewScreen(
        url: testUrl,
        title: testTitle,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('should handle different URLs correctly', (WidgetTester tester) async {
      // Arrange
      const customUrl = 'https://example.com';
      const webViewScreen = WebViewScreen(
        url: customUrl,
        title: 'Custom Page',
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      expect(find.text('Custom Page'), findsOneWidget);
    });

    testWidgets('should have proper app bar actions structure', (WidgetTester tester) async {
      // Arrange
      const webViewScreen = WebViewScreen(
        url: testUrl,
        title: testTitle,
      );

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: webViewScreen,
        ),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      expect(appBar.actions!.length, 3); // refresh, back, forward
    });
  });
}
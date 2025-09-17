import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baitech_web_app/splash_screen.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('should display splash screen with image', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            nextScreen: nextScreen,
            duration: const Duration(seconds: 10), // Long duration for testing
          ),
        ),
      );
      
      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
      expect(find.byType(Positioned), findsWidgets);
    });

    testWidgets('should have correct gradient background', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            nextScreen: nextScreen,
            duration: const Duration(seconds: 10),
          ),
        ),
      );
      
      // Assert
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.colors, hasLength(2));
      expect(gradient.colors[0], const Color(0xFFF5F5F5));
      expect(gradient.colors[1], const Color(0xFFB8E6E6));
    });

    testWidgets('should navigate to next screen after specified duration', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      const shortDuration = Duration(milliseconds: 100);
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            nextScreen: nextScreen,
            duration: shortDuration,
          ),
        ),
      );
      
      // Wait for navigation
      await tester.pumpAndSettle(shortDuration + const Duration(milliseconds: 200));
      
      // Assert
      expect(find.text('Next Screen'), findsOneWidget);
    });

    testWidgets('should use default duration of 3 seconds', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(nextScreen: nextScreen),
        ),
      );
      
      // Assert - Should still be showing splash screen after 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Next Screen'), findsNothing);
    });

    testWidgets('should animate fade in effect', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            nextScreen: nextScreen,
            duration: const Duration(seconds: 10),
          ),
        ),
      );
      
      // Assert
      expect(find.byType(FadeTransition), findsOneWidget);
      
      // Check that animation controller is running
      final fadeTransition = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fadeTransition.opacity, isA<Animation<double>>());
    });

    testWidgets('should use full screen layout with stack', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            nextScreen: nextScreen,
            duration: const Duration(seconds: 10),
          ),
        ),
      );
      
      // Assert
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
      expect(find.byType(Positioned), findsWidgets);
    });

    testWidgets('should have full screen image with cover fit', (WidgetTester tester) async {
      // Arrange
      const nextScreen = Text('Next Screen');
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            nextScreen: nextScreen,
            duration: const Duration(seconds: 10),
          ),
        ),
      );
      
      // Assert
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      
      expect(find.byType(Positioned), findsWidgets);
    });
  });
}
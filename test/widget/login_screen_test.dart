import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Screen/login_screen.dart';

/// Wrap [child] in a minimal MaterialApp so Navigator and Theme work.
Widget _app(Widget child) => MaterialApp(
      home: child,
      routes: {'/signup': (_) => const Scaffold(body: Text('Signup'))},
    );

void main() {
  group('LoginView – UI structure', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('renders Login button', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      expect(
        find.widgetWithText(ElevatedButton, 'Login'),
        findsOneWidget,
      );
    });

    testWidgets('renders app title and icon', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      expect(find.text('Motive Me'), findsOneWidget);
      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('renders sign-up link text', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
    });

    testWidgets('email field has email keyboard type', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      final emailField = tester.widget<TextField>(
        find.ancestor(
          of: find.text('Email'),
          matching: find.byType(TextField),
        ),
      );
      expect(emailField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('password field obscures text', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      final passwordField = fields.last; // password is the second field
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('error message is not shown on initial render', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      // No Container with error styling should be visible
      // We check indirectly: no FirebaseAuthException text shown
      expect(find.textContaining('failed', findRichText: true), findsNothing);
    });
  });

  group('LoginView – interaction', () {
    testWidgets('Sign up link navigates to /signup route', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      expect(find.text('Signup'), findsOneWidget);
    });

    testWidgets('Login button is enabled when not loading', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Login'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('email and password fields accept text input', (tester) async {
      await tester.pumpWidget(_app(const LoginView()));

      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password'), 'secret123');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
      // Password is obscured so text isn't directly findable by value
    });
  });
}

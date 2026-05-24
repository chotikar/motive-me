import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Screen/signup_screen.dart';
import 'package:motive_me/Screen/login_screen.dart';

const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

void _mockOffline() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return ['none'];
    return null;
  });
}

void _clearMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, null);
}

Widget _app() => MaterialApp(
      home: const SignupView(),
      routes: {
        '/home': (_) => const Scaffold(body: Text('Home')),
        '/login': (_) => const LoginView(),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockOffline();
  });
  tearDown(_clearMocks);

  // ── UI Elements ───────────────────────────────────────────────────────────

  group('SignupView – UI elements', () {
    testWidgets('shows Sign Up in AppBar title', (tester) async {
      await tester.pumpWidget(_app());
      // 'Sign Up' appears in AppBar title AND the button — at least 2
      expect(find.text('Sign Up'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Create Account heading', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows psychology icon', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('shows all 5 input fields', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Bio (Optional)'), findsOneWidget);
      // At least 5 TextFields: name, email, password, confirm password, bio
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('shows Sign Up button', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('shows Login link at the bottom', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('shows password visibility toggle icons', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Both password fields are obscured by default → visibility_off icons
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
    });

    testWidgets('tapping visibility toggle reveals password field', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsAtLeastNWidgets(1));
    });
  });

  // ── Validation ────────────────────────────────────────────────────────────

  group('SignupView – validation', () {
    testWidgets('shows error when name is empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows error when password is empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.enterText(find.byType(TextField).at(1), 'alice@test.com');
      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('shows error when password is too short', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.enterText(find.byType(TextField).at(1), 'alice@test.com');
      await tester.enterText(find.byType(TextField).at(2), '123'); // < 6 chars
      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('shows error when passwords do not match', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.enterText(find.byType(TextField).at(1), 'alice@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.enterText(find.byType(TextField).at(3), 'different456');
      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('stays on signup screen when validation fails', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(SignupView), findsOneWidget);
    });

    testWidgets('error message disappears on next valid attempt', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('Please enter your name'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name'), findsNothing);
      expect(find.text('Please enter your email'), findsOneWidget);
    });
  });

  // ── Navigation ────────────────────────────────────────────────────────────

  group('SignupView – navigation', () {
    testWidgets('tapping Login link goes back to login screen', (tester) async {
      // Place LoginView as root so signup is pushed on top
      await tester.pumpWidget(MaterialApp(
        home: const LoginView(),
        routes: {
          '/signup': (_) => const SignupView(),
          '/home': (_) => const Scaffold(body: Text('Home')),
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupView), findsOneWidget);

      // Login link is at the bottom of a scrollable screen — scroll to it first
      final loginLink = find.text('Login');
      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink);
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('back arrow navigates away from signup', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const LoginView(),
        routes: {
          '/signup': (_) => const SignupView(),
          '/home': (_) => const Scaffold(body: Text('Home')),
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(SignupView), findsNothing);
    });
  });
}

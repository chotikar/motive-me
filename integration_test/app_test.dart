/// Integration Tests — run on a real device or emulator with Firebase.
///
/// Prerequisites:
///   1. A connected device or running emulator.
///   2. Firebase project configured (google-services.json / GoogleService-Info.plist).
///
/// Run with:
///   flutter test integration_test/app_test.dart -d <device-id>
///
/// ---------------------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motive_me/main.dart' as app;

// ---------------------------------------------------------------------------
// Test account (real Firebase project)
// ---------------------------------------------------------------------------
const _testEmail    = '68130702314@ad.sit.kmutt.ac.th';
const _testPassword = '68130702314';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _resetSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  } catch (_) {
    SharedPreferences.setMockInitialValues({});
  }
}

Future<void> _seedSharedPreferences(Map<String, Object> values) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final entry in values.entries) {
      if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
      } else if (entry.value is int) {
        await prefs.setInt(entry.key, entry.value as int);
      } else if (entry.value is bool) {
        await prefs.setBool(entry.key, entry.value as bool);
      } else if (entry.value is double) {
        await prefs.setDouble(entry.key, entry.value as double);
      }
    }
  } catch (_) {
    SharedPreferences.setMockInitialValues(values);
  }
}

/// Reset prefs → launch app → land on Login screen.
///
/// `await app.main()` is required because main() is async (awaits
/// Firebase.initializeApp before calling runApp).  Without the await,
/// pump() runs before runApp() and the widget tree is empty.
Future<void> _launchToLoginScreen(WidgetTester tester) async {
  await _resetSharedPreferences();
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
  await app.main();                                    // ← must await
  await tester.pump();                                 // render splash
  await tester.pumpAndSettle(const Duration(seconds: 5)); // redirect → login
  expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
}

/// Login with the real test account → land on Home screen.
///
/// Uses pump(15 s) instead of pumpAndSettle after tapping Login.
/// pumpAndSettle hangs indefinitely on the home screen because the
/// Firebase Realtime-Database StreamSubscription keeps scheduling frames.
Future<void> _loginAndGoHome(WidgetTester tester) async {
  await _launchToLoginScreen(tester);
  final emailFinder = find.byType(TextField).at(0);
  await tester.tap(emailFinder);
  await tester.pump();
  await tester.enterText(emailFinder, _testEmail);
  await tester.pump();

  final passwordFinder = find.byType(TextField).at(1);
  await tester.tap(passwordFinder);
  await tester.pump();
  await tester.enterText(passwordFinder, _testPassword);
  await tester.pump();

  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 15)); // ← pump, NOT pumpAndSettle
  if (find.text('Welcome back!').evaluate().isEmpty) {
    for (final element in find.byType(Text).evaluate()) {
      final textWidget = element.widget as Text;
      print('DEBUG SCREEN TEXT: ${textWidget.data}');
    }
  }
  expect(find.text('Welcome back!'), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════════════════════════
  // Splash screen
  // ══════════════════════════════════════════════════════════════════════════
  group('Splash screen', () {
    testWidgets('shows app name and bolt icon on launch', (tester) async {
      await _resetSharedPreferences();
      await app.main();              // ← awaited
      await tester.pump();           // render splash before async redirect

      expect(find.text('Motive Me'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('redirects to login when no user is cached', (tester) async {
      await _resetSharedPreferences();
      await app.main();              // ← awaited
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Login screen — UI elements
  // ══════════════════════════════════════════════════════════════════════════
  group('Login screen – UI', () {
    testWidgets('shows email and password fields', (tester) async {
      await _launchToLoginScreen(tester);

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows Login button', (tester) async {
      await _launchToLoginScreen(tester);

      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('shows Sign up link', (tester) async {
      await _launchToLoginScreen(tester);

      expect(find.text('Sign up'), findsOneWidget);
    });

    testWidgets('tapping Sign up navigates to signup screen', (tester) async {
      await _launchToLoginScreen(tester);

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      // Signup screen label is "Full Name" (not just "Name")
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows error when submitting empty fields', (tester) async {
      await _launchToLoginScreen(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Please enter your email and password'),
        findsOneWidget,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Login screen — real Firebase authentication
  // ══════════════════════════════════════════════════════════════════════════
  group('Login screen – real Firebase authentication', () {
    testWidgets('logs in with valid credentials and navigates to home',
        (tester) async {
      await _loginAndGoHome(tester);
      // _loginAndGoHome already asserts 'Welcome back!'
    });

    testWidgets('shows error for wrong password', (tester) async {
      await _launchToLoginScreen(tester);

      final emailFinder = find.byType(TextField).at(0);
      await tester.tap(emailFinder);
      await tester.pump();
      await tester.enterText(emailFinder, _testEmail);
      await tester.pump();

      final passwordFinder = find.byType(TextField).at(1);
      await tester.tap(passwordFinder);
      await tester.pump();
      await tester.enterText(passwordFinder, 'wrong_password_123');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));

      // Error response → still on login screen
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Home screen — authenticated user (online)
  // ══════════════════════════════════════════════════════════════════════════
  group('Home screen – authenticated user', () {
    testWidgets('shows stat cards and welcome message after login',
        (tester) async {
      await _loginAndGoHome(tester);

      expect(find.text('Total Skills'), findsOneWidget);
      expect(find.text('Done This Month'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
    });

    testWidgets('Add Skill button is visible', (tester) async {
      await _loginAndGoHome(tester);

      expect(find.byTooltip('Add Skill'), findsOneWidget);
    });

    testWidgets('skill list shows cards or empty-state message', (tester) async {
      await _loginAndGoHome(tester);
      await tester.pump(const Duration(seconds: 3));

      final hasCards = find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
      final hasEmpty = find.text('No skills yet').evaluate().isNotEmpty;
      expect(hasCards || hasEmpty, isTrue);
    });

    testWidgets('Profile button navigates to profile screen', (tester) async {
      await _loginAndGoHome(tester);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Profile'), findsAtLeastNWidgets(1));
      expect(find.text(_testEmail), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Home screen — cached user name (real Firebase auth + overridden name)
  //
  // Uses real Firebase auth so streamUserActivities() works, but overrides
  // the display name via SharedPreferences to test local-name rendering.
  // fake UIDs (e.g. 'test_uid') cannot be used when online because the
  // Firebase stream throws 'User not authenticated' → home redirects to login.
  // ══════════════════════════════════════════════════════════════════════════
  group('Home screen – cached user name', () {
    setUpAll(() async {
      // Sign in once before all tests in this group.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _testEmail,
          password: _testPassword,
        );
      }
    });

    testWidgets('shows welcome message with name read from SharedPreferences',
        (tester) async {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Seed SharedPreferences with a custom display name.
      await _seedSharedPreferences({
        'user_uid': uid,           // ← real UID so stream does not throw
        'user_name': 'Test User',
        'user_email': _testEmail,
        'user_photo_url': '',
        'user_bio': '',
        'user_created_at': 1000,
        'user_updated_at': 2000,
        'cached_skill_entries': '[]',
      });

      await app.main();
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
    });
  });
}

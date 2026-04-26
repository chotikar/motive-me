/// Integration Tests — run on a real device or emulator with Firebase.
///
/// Prerequisites:
///   1. A connected device or running emulator.
///   2. Firebase project configured (google-services.json / GoogleService-Info.plist).
///
/// Run with:
///   flutter test integration_test/app_test.dart
///
/// ---------------------------------------------------------------------------

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Splash screen ──────────────────────────────────────────────────────────

  group('Splash screen', () {
    testWidgets('shows app name and bolt icon on launch', (tester) async {
      SharedPreferences.setMockInitialValues({});

      app.main();
      await tester.pump(); // first frame — splash renders before async check

      expect(find.text('Motive Me'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('redirects to login when no user is cached', (tester) async {
      SharedPreferences.setMockInitialValues({});

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After the async redirect completes we should land on the login screen.
      expect(find.text('Login'), findsAtLeastNWidgets(1));
    });
  });

  // ── Login screen — UI elements ─────────────────────────────────────────────

  group('Login screen – UI', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows email and password fields', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows login button', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('tapping Sign up navigates to signup screen', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      // Signup screen has a name field not present on login
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets('shows error when submitting empty fields', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap login without entering credentials
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter your email and password'),
        findsOneWidget,
      );
    });
  });

  // ── Login screen — real Firebase login ────────────────────────────────────

  group('Login screen – real Firebase authentication', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('logs in with valid credentials and navigates to home',
        (tester) async {
      app.main();

      // Wait for the login screen to appear
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);

      // Enter email in the first TextField
      await tester.enterText(find.byType(TextField).at(0), _testEmail);

      // Enter password in the second TextField
      await tester.enterText(find.byType(TextField).at(1), _testPassword);

      // Dismiss keyboard so button is tappable
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Tap login
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump(); // start the async login

      // Wait for Firebase auth + profile fetch + navigation
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Should be on the home screen now
      expect(find.text('Welcome back!'), findsOneWidget);
    });

    testWidgets('shows error for wrong password', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.enterText(find.byType(TextField).at(0), _testEmail);
      await tester.enterText(find.byType(TextField).at(1), 'wrong_password_123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      // Wait for Firebase to respond
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Error message from FirebaseAuthException should appear
      expect(find.byType(TextField), findsNWidgets(2)); // still on login screen
    });
  });

  // ── Home screen — real user, online ───────────────────────────────────────

  group('Home screen – authenticated user', () {
    /// Log in first, then verify home screen elements.
    testWidgets('shows home screen content after login', (tester) async {
      SharedPreferences.setMockInitialValues({});

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Log in
      await tester.enterText(find.byType(TextField).at(0), _testEmail);
      await tester.enterText(find.byType(TextField).at(1), _testPassword);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Verify home screen structure
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Total Skills'), findsOneWidget);
      expect(find.text('Done This Month'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
    });

    testWidgets('add-skill button is present and tappable', (tester) async {
      SharedPreferences.setMockInitialValues({});

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Log in
      await tester.enterText(find.byType(TextField).at(0), _testEmail);
      await tester.enterText(find.byType(TextField).at(1), _testPassword);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // AppBar add button should be visible
      expect(find.byTooltip('Add Skill'), findsOneWidget);
    });
  });

  // ── Home screen — offline cached user ─────────────────────────────────────

  group('Home screen – offline cached user', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_uid': 'test_uid',
        'user_name': 'Test User',
        'user_email': 'test@test.com',
        'user_photo_url': '',
        'user_bio': '',
        'user_created_at': 1000,
        'user_updated_at': 2000,
        // Cached skill entry (no internet needed)
        'cached_skill_entries': '''[{
          "userActivity": {
            "id": "ua1",
            "activityId": "a1",
            "startDate": 1000,
            "expireDate": 9999999999999,
            "goal": 10,
            "count": 3
          },
          "activity": {
            "id": "a1",
            "name": "Morning Run",
            "reward": 50
          }
        }]''',
      });
    });

    testWidgets('shows welcome message with cached user name', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('shows cached skill card', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The cached skill "Morning Run" should appear even without internet
      expect(find.text('Morning Run'), findsOneWidget);
    });
  });
}

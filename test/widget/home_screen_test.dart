import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Screen/home_screen.dart';
import 'package:motive_me/Screen/login_screen.dart';

const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

/// Register connectivity mock: returns ['none'] string — offline state.
/// connectivity_plus uses method name 'check' and List<String> results.
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

/// SharedPreferences values for a valid logged-in user.
Map<String, Object> _userPrefs({
  String uid = 'u1',
  String name = 'Alice',
  String email = 'alice@test.com',
}) =>
    {
      'user_uid': uid,
      'user_name': name,
      'user_email': email,
      'user_photo_url': '',
      'user_bio': '',
      'user_created_at': 1000,
      'user_updated_at': 2000,
    };

Widget _app() => MaterialApp(
      home: const HomeScreen(),
      routes: {
        '/login': (_) => const LoginView(),
        '/create-skill': (_) => const Scaffold(body: Text('Create Skill')),
        '/profile': (_) => const Scaffold(body: Text('Profile')),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearMocks);

  // ── No user: redirect to login ──────────────────────────────────────────

  group('HomeScreen – no user in local storage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('redirects to login screen', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Should have navigated away to the login route
      expect(find.byType(LoginView), findsOneWidget);
    });
  });

  // ── Offline mode ─────────────────────────────────────────────────────────

  group('HomeScreen – offline with valid user', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_userPrefs());
      _mockOffline();
    });

    testWidgets('shows loading indicator initially then resolves',
        (tester) async {
      await tester.pumpWidget(_app());
      // On first pump, still loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      // After settling, loading is done
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows offline banner', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off), findsWidgets);
      expect(
        find.textContaining("You're offline"),
        findsOneWidget,
      );
    });

    testWidgets('shows welcome message with user name', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows stat cards', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Total Skills'), findsOneWidget);
      expect(find.text('Done This Month'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
    });

    testWidgets('shows empty-skills state when no cached skills', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('No skills yet'), findsOneWidget);
    });

    testWidgets('shows achievements section', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Achievements'), findsOneWidget);
    });
  });

  // ── AppBar actions ────────────────────────────────────────────────────────

  group('HomeScreen – AppBar', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_userPrefs());
      _mockOffline();
    });

    testWidgets('shows app title', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Motive Meeee'), findsOneWidget);
    });

    testWidgets('add-skill button navigates to /create-skill', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Use tooltip to target the AppBar button specifically
      await tester.tap(find.byTooltip('Add Skill'));
      await tester.pumpAndSettle();

      expect(find.text('Create Skill'), findsOneWidget);
    });

    testWidgets('profile button navigates to /profile', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Profile icon button is the person icon
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
    });
  });

  // ── Cached skills displayed offline ──────────────────────────────────────

  group('HomeScreen – shows cached skills while offline', () {
    setUp(() {
      // Seed SharedPreferences with a cached skill entry
      SharedPreferences.setMockInitialValues({
        ..._userPrefs(),
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
      _mockOffline();
    });

    testWidgets('renders the cached skill card', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Morning Run'), findsOneWidget);
    });

    testWidgets('check-in button shows "No Internet" label', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('No Internet'), findsOneWidget);
    });

    testWidgets('check-in button is disabled when offline', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // ElevatedButton.icon creates a private _ElevatedButtonWithIcon subclass,
      // so byType(ElevatedButton) misses it. Use a predicate that checks 'is'.
      final disabledButton = find.byWidgetPredicate(
        (w) => w is ElevatedButton && w.onPressed == null,
      );
      // There is exactly one disabled ElevatedButton: the offline check-in button.
      expect(disabledButton, findsOneWidget);
    });

    testWidgets('wifi_off icon appears on check-in button', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Icon is inside the ElevatedButton.icon
      expect(find.byIcon(Icons.wifi_off), findsWidgets);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart'
    show setupFirebaseCoreMocks;
import 'package:motive_me/Screen/profile_screen.dart';
import 'package:motive_me/Screen/login_screen.dart';

// ── Platform channels ────────────────────────────────────────────────────────

const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

// Pigeon channel for FirebaseAuth.instance.signOut() — no suffix by default.
const _signOutChannel =
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.signOut';

// ── Channel mock helpers ─────────────────────────────────────────────────────

void _mockOffline() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return ['none'];
    return null;
  });
}

// Pigeon void-return success = [null] encoded with StandardMessageCodec.
void _mockFirebaseAuthSignOut() {
  final codec = const StandardMessageCodec();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    _signOutChannel,
    (_) async => codec.encodeMessage([null]),
  );
}

void _clearMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(_signOutChannel, null);
}

// ── Fixture helpers ──────────────────────────────────────────────────────────

Map<String, Object> _userPrefs({
  String uid = 'u1',
  String name = 'Alice',
  String email = 'alice@test.com',
  String bio = 'Flutter developer',
}) =>
    {
      'user_uid': uid,
      'user_name': name,
      'user_email': email,
      'user_photo_url': '',
      'user_bio': bio,
      'user_created_at': 1000,
      'user_updated_at': 2000,
    };

Widget _app() => MaterialApp(
      home: const ProfileScreen(),
      routes: {
        '/login': (_) => const LoginView(),
        '/home': (_) => const Scaffold(body: Text('Home')),
      },
    );

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearMocks);

  // ── Group 1: No user in storage ───────────────────────────────────────────

  group('ProfileScreen – no user in local storage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      _mockOffline();
    });

    testWidgets('redirects to LoginView when no user is cached', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });
  });

  // ── Group 2: Loading state (before async settles) ─────────────────────────

  group('ProfileScreen – loading state', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_userPrefs());
      _mockOffline();
    });

    testWidgets('shows AppBar with "Profile" title on first frame',
        (tester) async {
      await tester.pumpWidget(_app());
      // One frame only — async _loadUserProfile() has not yet resolved
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator while loading', (tester) async {
      await tester.pumpWidget(_app());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders a Scaffold without crashing', (tester) async {
      await tester.pumpWidget(_app());
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ── Group 3: User cached but Firebase unavailable ─────────────────────────

  group('ProfileScreen – user cached but Firebase unavailable', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_userPrefs());
      _mockOffline();
      // No Firebase Core mock → FirebaseDatabase.instance throws →
      // caught in _loadUserProfile → routeToLogin()
    });

    testWidgets(
        'redirects to login when FirebaseAchievementsService constructor throws',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
    });
  });

  // ── Group 4: Full profile UI ──────────────────────────────────────────────
  //
  // Strategy:
  //   • setupFirebaseCoreMocks() installs the official Pigeon-level Firebase
  //     mock so FirebaseDatabase.instance and FirebaseAuth.instance construct
  //     without hitting the real platform.
  //   • Connectivity is mocked offline, so getAchievementCount() hits its
  //     catch(_){return 0;} branch — the screen loads with achievementCount=0.
  //   • _mockFirebaseAuth() lets FirebaseAuth.instance.signOut() succeed.

  group('ProfileScreen – full profile UI', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    });

    setUp(() {
      SharedPreferences.setMockInitialValues(_userPrefs());
      _mockOffline();
      _mockFirebaseAuthSignOut();
    });

    // ── Rendering ──────────────────────────────────────────────────────────

    testWidgets('shows AppBar with "Profile" title after load', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('no longer shows CircularProgressIndicator after load',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays user name in profile header', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('displays user email in profile header', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('alice@test.com'), findsOneWidget);
    });

    testWidgets('shows person icon when photo URL is empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows Achievements label', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Achievements'), findsOneWidget);
    });

    testWidgets('shows achievement count of 0 when offline', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows emoji_events icon in achievements section',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('shows Bio section when bio is non-empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Bio text appears in both the bio section card AND the info tile below.
      expect(find.text('Flutter developer'), findsWidgets);
    });

    testWidgets('shows Details section header', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('shows Last Updated tile in Details section', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Last Updated'), findsOneWidget);
    });

    testWidgets('shows Edit Profile button with edit icon', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('shows logout icon button in AppBar', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    // ── Empty bio variant ──────────────────────────────────────────────────

    testWidgets('shows "No bio available" in details tile when bio is empty',
        (tester) async {
      SharedPreferences.setMockInitialValues(_userPrefs(bio: ''));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('No bio available'), findsOneWidget);
    });

    testWidgets('hides bio text content when bio is empty', (tester) async {
      SharedPreferences.setMockInitialValues(_userPrefs(bio: ''));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Flutter developer'), findsNothing);
    });

    // ── Logout dialog ──────────────────────────────────────────────────────

    testWidgets('tapping logout icon shows confirmation AlertDialog',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('dialog shows confirmation message', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
    });

    testWidgets('dialog has Cancel and Logout action buttons', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Logout'), findsOneWidget);
    });

    testWidgets('tapping Cancel dismisses dialog and stays on profile',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Alice'), findsOneWidget); // still on profile
    });

    testWidgets('tapping Logout in dialog triggers logout flow', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Logout'));
      await tester.pumpAndSettle();

      // Dialog must be dismissed regardless of outcome
      expect(find.byType(AlertDialog), findsNothing);
      // Either navigated to login (success) or snackbar shown (signOut error)
      final wentToLogin = find.byType(LoginView).evaluate().isNotEmpty;
      final showedError =
          find.text('Error logging out').evaluate().isNotEmpty;
      expect(wentToLogin || showedError, isTrue);
    });
  });
}

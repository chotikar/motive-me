import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Screen/edit_profile_screen.dart';
import 'package:motive_me/Models/user_model.dart';

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

UserModel _makeUser({
  String name = 'Alice',
  String email = 'alice@test.com',
  String? bio = 'Flutter developer',
  String? photoUrl,
}) =>
    UserModel(
      uid: 'u1',
      name: name,
      email: email,
      photoUrl: photoUrl,
      bio: bio,
      createdAt: 1000,
      updatedAt: 2000,
    );

Widget _app([UserModel? user]) => MaterialApp(
      home: EditProfileScreen(user: user ?? _makeUser()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockOffline();
  });
  tearDown(_clearMocks);

  // ── UI Elements ───────────────────────────────────────────────────────────

  group('EditProfileScreen – UI elements', () {
    testWidgets('shows Edit Profile in AppBar', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('shows Name label', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets('shows Bio (Optional) label', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Bio (Optional)'), findsOneWidget);
    });

    testWidgets('shows 2 TextFields (name and bio)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('shows Save Changes button', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ElevatedButton, 'Save Changes'),
        findsOneWidget,
      );
    });

    testWidgets('shows Cancel button', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, 'Cancel'),
        findsOneWidget,
      );
    });

    testWidgets('shows camera_alt icon for photo picker', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('shows tap hint text below avatar', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Tap camera icon to change photo'), findsOneWidget);
    });

    testWidgets('shows person icon when no photo URL', (tester) async {
      await tester.pumpWidget(_app(_makeUser(photoUrl: null)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });

  // ── Pre-filled values ─────────────────────────────────────────────────────

  group('EditProfileScreen – pre-filled values', () {
    testWidgets('name field is pre-filled with user name', (tester) async {
      await tester.pumpWidget(_app(_makeUser(name: 'Alice')));
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      expect(
        tester.widget<TextField>(nameField).controller?.text,
        'Alice',
      );
    });

    testWidgets('bio field is pre-filled with user bio', (tester) async {
      await tester.pumpWidget(_app(_makeUser(bio: 'Flutter developer')));
      await tester.pumpAndSettle();

      final bioField = find.byType(TextField).last;
      expect(
        tester.widget<TextField>(bioField).controller?.text,
        'Flutter developer',
      );
    });

    testWidgets('bio field is empty when user has no bio', (tester) async {
      await tester.pumpWidget(_app(_makeUser(bio: null)));
      await tester.pumpAndSettle();

      final bioField = find.byType(TextField).last;
      expect(
        tester.widget<TextField>(bioField).controller?.text,
        '',
      );
    });
  });

  // ── Validation ────────────────────────────────────────────────────────────

  group('EditProfileScreen – validation', () {
    testWidgets('shows error when name is cleared and Save is tapped',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Clear the name field
      await tester.enterText(find.byType(TextField).first, '');
      final btn = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Name cannot be empty'), findsOneWidget);
    });

    testWidgets('stays on edit screen when validation fails', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '');
      final btn = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('shows network error when offline and valid name is entered',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Name is already pre-filled — just tap Save
      final btn = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Failed to update user profile'),
        findsOneWidget,
      );
    });
  });

  // ── Image picker bottom sheet ─────────────────────────────────────────────

  group('EditProfileScreen – image picker sheet', () {
    testWidgets('tapping camera icon shows bottom sheet', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Take a Photo'), findsOneWidget);
    });

    testWidgets('bottom sheet has gallery icon', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets('bottom sheet has camera icon', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });
  });

  // ── Hint texts ────────────────────────────────────────────────────────────

  group('EditProfileScreen – hint texts', () {
    testWidgets('name field has correct hint text', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.decoration?.hintText, 'Enter your name');
    });

    testWidgets('bio field has correct hint text', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final bioField = tester.widget<TextField>(find.byType(TextField).last);
      expect(bioField.decoration?.hintText, 'Tell us about yourself');
    });
  });

  // ── Initial state ─────────────────────────────────────────────────────────

  group('EditProfileScreen – initial state', () {
    testWidgets('no error message shown on first load', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Name cannot be empty'), findsNothing);
      expect(find.textContaining('Failed to'), findsNothing);
    });

    testWidgets('Save Changes button is enabled on first load', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Changes'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Cancel button is enabled on first load', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      expect(btn.onPressed, isNotNull);
    });
  });

  // ── Editing fields ────────────────────────────────────────────────────────

  group('EditProfileScreen – editing fields', () {
    testWidgets('typing in name field updates its value', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Bob');
      await tester.pump();

      final controller =
          tester.widget<TextField>(find.byType(TextField).first).controller;
      expect(controller?.text, 'Bob');
    });

    testWidgets('typing in bio field updates its value', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'New bio text');
      await tester.pump();

      final controller =
          tester.widget<TextField>(find.byType(TextField).last).controller;
      expect(controller?.text, 'New bio text');
    });

    testWidgets('bio field supports multi-line input', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final bioField = tester.widget<TextField>(find.byType(TextField).last);
      expect(bioField.maxLines, greaterThan(1));
    });
  });

  // ── Validation edge cases ─────────────────────────────────────────────────

  group('EditProfileScreen – validation edge cases', () {
    testWidgets('name with only spaces is treated as empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '   ');
      final btn = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Name cannot be empty'), findsOneWidget);
    });

    testWidgets('error clears when name is fixed and Save tapped again',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Trigger empty-name error
      await tester.enterText(find.byType(TextField).first, '');
      final btn = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('Name cannot be empty'), findsOneWidget);

      // Fix the name and tap again — error changes to network error (offline)
      await tester.enterText(find.byType(TextField).first, 'Bob');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Name cannot be empty'), findsNothing);
    });
  });

  // ── Avatar display ────────────────────────────────────────────────────────

  group('EditProfileScreen – avatar display', () {
    testWidgets('shows person icon when photoUrl is empty string', (tester) async {
      await tester.pumpWidget(_app(_makeUser(photoUrl: '')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('uses Image.network widget when photoUrl is an http URL',
        (tester) async {
      await tester.pumpWidget(
        _app(_makeUser(photoUrl: 'https://example.com/photo.jpg')),
      );
      // pump one frame — Image.network widget is created before network resolves
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });
  });

  // ── Bottom sheet dismissal ────────────────────────────────────────────────

  group('EditProfileScreen – bottom sheet dismissal', () {
    testWidgets('tapping outside the sheet dismisses it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();
      expect(find.text('Choose from Gallery'), findsOneWidget);

      // Tap the modal barrier above the sheet
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      expect(find.text('Choose from Gallery'), findsNothing);
    });

    testWidgets('after dismissing sheet, edit screen is still visible',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
    });
  });

  // ── Navigation ────────────────────────────────────────────────────────────

  group('EditProfileScreen – navigation', () {
    testWidgets('Cancel button pops the screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: _makeUser()),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);

      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel');
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsNothing);
    });

    testWidgets('back arrow navigates away', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: _makeUser()),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Screen/create_skill_screen.dart';

const _connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');

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

Widget _app() => const MaterialApp(home: CreateSkillScreen());

Future<void> _fillFields(WidgetTester tester, {required String name, required String reward, required String goal}) async {
  await tester.enterText(find.byType(TextFormField).at(0), name);
  await tester.enterText(find.byType(TextFormField).at(1), reward);
  await tester.enterText(find.byType(TextFormField).at(2), goal);
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, 'Add Skill');
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockOffline();
  });
  tearDown(_clearMocks);

  group('CreateSkillScreen Widget BVA & EP Tests', () {

    // ─── 1. Goal Validation BVA & EP (Range: 1 to 10,000) ────────────────────
    testWidgets('Goal BVA - Below Lower Boundary "0" shows error', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '10', goal: '0');
      await _tapSubmit(tester);

      expect(find.text('Must be at least 1'), findsOneWidget);
    });

    testWidgets('Goal BVA - Lower Boundary "1" is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '10', goal: '1');
      await _tapSubmit(tester);

      expect(find.text('Must be at least 1'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Goal BVA - Upper Boundary "10000" is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '10', goal: '10000');
      await _tapSubmit(tester);

      expect(find.text('Max is 10,000'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Goal BVA - Above Upper Boundary "10001" shows error', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '10', goal: '10001');
      await _tapSubmit(tester);

      expect(find.text('Max is 10,000'), findsOneWidget);
    });

    testWidgets('Goal EP [Valid Partition: In-Range] - Input "500" is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '10', goal: '500');
      await _tapSubmit(tester);

      expect(find.text('Must be at least 1'), findsNothing);
      expect(find.text('Max is 10,000'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Goal EP [Invalid Partition 2: Too High] - Input "15000" shows error', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '10', goal: '15000');
      await _tapSubmit(tester);

      expect(find.text('Max is 10,000'), findsOneWidget);
    });

    // ─── 2. Reward Validation BVA & EP (Min: 0) ──────────────────────────────
    testWidgets('Reward BVA - Lower Boundary "0" is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '0', goal: '10');
      await _tapSubmit(tester);

      expect(find.text('Must be 0 or more'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Reward EP [Valid Partition: Positive] - Input "100" is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Run', reward: '100', goal: '10');
      await _tapSubmit(tester);

      expect(find.text('Must be 0 or more'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    // ─── 3. Skill Name Validation BVA & EP (Length: 1 to 80 chars, Charset: custom) ───
    testWidgets('Skill Name BVA - Below Lower Boundary (Empty) shows error', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: '', reward: '10', goal: '10');
      await _tapSubmit(tester);

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('Skill Name BVA - Lower Boundary "1" char is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'A', reward: '10', goal: '10');
      await _tapSubmit(tester);

      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Skill Name BVA - On Upper Boundary "80" chars is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final name80 = 'A' * 80;
      await _fillFields(tester, name: name80, reward: '10', goal: '10');
      await _tapSubmit(tester);

      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Skill Name EP [Valid Partition: In-Range] - Input "Push-ups 101" is valid', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _fillFields(tester, name: 'Push-ups 101', reward: '10', goal: '10');
      await _tapSubmit(tester);

      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Only letters, numbers, space, _ and - allowed'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });

    testWidgets('Skill Name EP [Invalid Partition: Invalid Character] - Disallowed characters are filtered out by input formatter', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Typing "Push-ups!" will have the "!" removed automatically by the input formatter
      await tester.enterText(find.byType(TextFormField).at(0), 'Push-ups!');
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(0),
          matching: find.byType(EditableText),
        ),
      );
      // '!' is filtered out
      expect(editableText.controller.text, 'Push-ups');
    });
  });
}

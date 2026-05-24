import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart' show setupFirebaseCoreMocks;
import 'package:motive_me/firebase_options.dart';
import 'package:motive_me/Screen/create_skill_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App End-to-End BVA & EP Integration Tests', () {
    setUp(() async {
      try {
        setupFirebaseCoreMocks();
      } catch (_) {}
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (_) {
          await Firebase.initializeApp();
        }
      }
    });

    testWidgets('E2E BVA: Goal input above maximum boundary (10,001) displays error', (tester) async {
      runApp(const MaterialApp(home: CreateSkillScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add Skill'), findsAtLeastNWidgets(1));

      await tester.enterText(find.byType(TextFormField).at(0), 'Yoga');
      await tester.enterText(find.byType(TextFormField).at(1), '20');
      await tester.enterText(find.byType(TextFormField).at(2), '10001');
      await tester.pump();

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Skill');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Max is 10,000'), findsOneWidget);
    });

    testWidgets('E2E EP: Goal input in too high partition (15,000) displays error', (tester) async {
      runApp(const MaterialApp(home: CreateSkillScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add Skill'), findsAtLeastNWidgets(1));

      await tester.enterText(find.byType(TextFormField).at(0), 'Yoga');
      await tester.enterText(find.byType(TextFormField).at(1), '20');
      await tester.enterText(find.byType(TextFormField).at(2), '15000');
      await tester.pump();

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Skill');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Max is 10,000'), findsOneWidget);
    });

    testWidgets('E2E BVA: Goal input below minimum boundary (0) displays error', (tester) async {
      runApp(const MaterialApp(home: CreateSkillScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add Skill'), findsAtLeastNWidgets(1));

      await tester.enterText(find.byType(TextFormField).at(0), 'Yoga');
      await tester.enterText(find.byType(TextFormField).at(1), '20');
      await tester.enterText(find.byType(TextFormField).at(2), '0');
      await tester.pump();

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Skill');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Must be at least 1'), findsOneWidget);
    });

    testWidgets('E2E EP: Goal input in valid partition (500) passes validation', (tester) async {
      runApp(const MaterialApp(home: CreateSkillScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add Skill'), findsAtLeastNWidgets(1));

      await tester.enterText(find.byType(TextFormField).at(0), 'Yoga');
      await tester.enterText(find.byType(TextFormField).at(1), '20');
      await tester.enterText(find.byType(TextFormField).at(2), '500');
      await tester.pump();

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Skill');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Goal is valid, so no Goal validation error is shown (only the start date validation appears)
      expect(find.text('Must be at least 1'), findsNothing);
      expect(find.text('Max is 10,000'), findsNothing);
      expect(find.text('Please select a start date'), findsOneWidget);
    });
  });
}

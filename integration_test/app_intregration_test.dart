import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import 'package:motive_me/main.dart' as app;

const _testEmail = '68130702314@ad.sit.kmutt.ac.th';
const _testPassword = '68130702314';

Future<void> _resetSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  } catch (_) {
    SharedPreferences.setMockInitialValues({});
  }
}

@Timeout(Duration(minutes: 5))

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E E2E Integration Test: Login, Add Skill, Verify, Edit Profile, Logout', (tester) async {
    // -------------------------------------------------------------------------
    // Setup / Reset state
    // -------------------------------------------------------------------------
    await _resetSharedPreferences();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // -------------------------------------------------------------------------
    // 1. Login with email & password
    // -------------------------------------------------------------------------
    await app.main();
    await tester.pump(); // render splash
    await tester.pumpAndSettle(const Duration(seconds: 5)); // wait for splash redirect to complete

    // Find fields using robust Keys
    final emailField = find.byKey(const Key('emailField'));
    expect(emailField, findsOneWidget);
    await tester.tap(emailField);
    await tester.pump();
    await tester.enterText(emailField, _testEmail);
    await tester.pump();

    final passwordField = find.byKey(const Key('passwordField'));
    expect(passwordField, findsOneWidget);
    await tester.tap(passwordField);
    await tester.pump();
    await tester.enterText(passwordField, _testPassword);
    await tester.pump();

    // Print text controller values for diagnosis
    final emailWidget = tester.widget<TextField>(emailField);
    print('DIAG EMAIL TEXT: "${emailWidget.controller?.text}"');
    final passwordWidget = tester.widget<TextField>(passwordField);
    print('DIAG PASSWORD TEXT: "${passwordWidget.controller?.text}"');

    if (kIsWeb) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }

    // Dismiss active focus/keyboard and wait for native dismiss animation to complete
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await Future.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Scroll Login button into view and tap it
    final loginButton = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();

    print('DIAG: Tapping Login button...');
    await tester.tap(loginButton);
    await tester.pump();
    print('DIAG: Login button tapped, waiting for Firebase response...');
    await tester.pump(const Duration(seconds: 25)); // wait for online Firebase auth to settle

    // Pump transition frames to let the scheduled navigation route complete
    print('DIAG: Pumping navigation transition frames...');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    if (find.text('Welcome back!').evaluate().isEmpty) {
      for (final element in find.byType(Text).evaluate()) {
        final textWidget = element.widget as Text;
        print('DEBUG SCREEN TEXT: ${textWidget.data}');
      }
    }
    expect(find.text('Welcome back!'), findsOneWidget);

    // -------------------------------------------------------------------------
    // 2. Add skill: 'test', 100 points, 10 days
    // -------------------------------------------------------------------------
    final addSkillFAB = find.byTooltip('Add Skill');
    await tester.tap(addSkillFAB);
    await tester.pump(const Duration(seconds: 3));

    // Verify on Add Skill screen
    expect(find.text('Add Skill'), findsAtLeastNWidgets(1));

    // Fill inputs using Keys
    final skillNameField = find.byKey(const Key('skillNameField'));
    expect(skillNameField, findsOneWidget);
    await tester.tap(skillNameField);
    await tester.pump();
    await tester.enterText(skillNameField, 'test');
    await tester.pump();

    final rewardField = find.byKey(const Key('skillRewardField'));
    expect(rewardField, findsOneWidget);
    await tester.tap(rewardField);
    await tester.pump();
    await tester.enterText(rewardField, '100');
    await tester.pump();

    final goalField = find.byKey(const Key('skillGoalField'));
    expect(goalField, findsOneWidget);
    await tester.tap(goalField);
    await tester.pump();
    await tester.enterText(goalField, '10');
    await tester.pump();

    if (kIsWeb) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }

    // Dismiss active focus/keyboard before tapping Date buttons
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await Future.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Set Dates (10 days duration)
    // Tap Start Date
    await tester.tap(find.text('Start Date'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(seconds: 2));

    // Tap End Date
    await tester.tap(find.text('End Date'));
    await tester.pump(const Duration(seconds: 2));

    // Switch to text input mode in Date Picker to specify exact future date (+10 days)
    final editIcon = find.byIcon(Icons.edit);
    if (editIcon.evaluate().isNotEmpty) {
      await tester.tap(editIcon);
      await tester.pump(const Duration(seconds: 2));

      final date10DaysLater = DateTime.now().add(const Duration(days: 10));
      final formattedDate = "${date10DaysLater.month.toString().padLeft(2, '0')}/${date10DaysLater.day.toString().padLeft(2, '0')}/${date10DaysLater.year}";
      
      final dateInput = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
      await tester.tap(dateInput);
      await tester.pump();
      await tester.enterText(dateInput, formattedDate);
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(seconds: 2));

    // Dismiss any active date input focus
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await Future.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final addSkillButton = find.byKey(const Key('addSkillButton'));
    await tester.ensureVisible(addSkillButton);
    await tester.pumpAndSettle();
    
    print('DIAG: Tapping Add Skill button...');
    await tester.tap(addSkillButton);
    await tester.pump();
    print('DIAG: Add Skill button tapped, waiting for Firebase response...');
    await tester.pump(const Duration(seconds: 20)); // wait for Firebase save and pop

    // Pump transition frames to let the pop navigation route complete
    print('DIAG: Pumping pop navigation transition frames...');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // -------------------------------------------------------------------------
    // 3. Check skill was shown at the main page
    // -------------------------------------------------------------------------
    expect(find.text('test'), findsAtLeastNWidgets(1));

    // -------------------------------------------------------------------------
    // 4. Read profile is "68130702314@ad.sit.kmutt.ac.th"
    // -------------------------------------------------------------------------
    final profileButton = find.byTooltip('Profile');
    expect(profileButton, findsOneWidget);
    await tester.tap(profileButton);
    await tester.pump(const Duration(seconds: 15)); // wait for profile info load

    expect(find.text(_testEmail), findsAtLeastNWidgets(1));

    // -------------------------------------------------------------------------
    // 5. Edit profile name: "Edite[current date]"
    // -------------------------------------------------------------------------
    final editProfileButton = find.widgetWithText(ElevatedButton, 'Edit Profile');
    expect(editProfileButton, findsOneWidget);
    await tester.ensureVisible(editProfileButton);
    await tester.tap(editProfileButton);
    await tester.pump(const Duration(seconds: 3));

    final currentDateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final newName = "Edite$currentDateStr";

    final nameField = find.byKey(const Key('editProfileNameField'));
    expect(nameField, findsOneWidget);
    await tester.tap(nameField);
    await tester.pump();
    await tester.enterText(nameField, newName);
    await tester.pump();

    if (kIsWeb) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }

    // Dismiss focus/keyboard before tapping Save changes
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await Future.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // -------------------------------------------------------------------------
    // 6. Save
    // -------------------------------------------------------------------------
    final saveChangesButton = find.byKey(const Key('editProfileSaveButton'));
    await tester.ensureVisible(saveChangesButton);
    await tester.pumpAndSettle();
    
    print('DIAG: Tapping Save Changes button...');
    await tester.tap(saveChangesButton);
    await tester.pump();
    print('DIAG: Save Changes button tapped, waiting for Firebase response...');
    await tester.pump(const Duration(seconds: 15)); // wait for update profile to sync

    // Pump transition frames to let the profile update route pop/settle
    print('DIAG: Pumping profile transition frames...');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // -------------------------------------------------------------------------
    // 7. Check new name that edit
    // -------------------------------------------------------------------------
    expect(find.text(newName), findsAtLeastNWidgets(1));

    // -------------------------------------------------------------------------
    // 8. Log out
    // -------------------------------------------------------------------------
    final logoutButton = find.byTooltip('Logout');
    expect(logoutButton, findsOneWidget);
    await tester.tap(logoutButton);
    await tester.pump(const Duration(seconds: 3));

    // -------------------------------------------------------------------------
    // 9. Confirm logout
    // -------------------------------------------------------------------------
    final confirmLogoutButton = find.widgetWithText(TextButton, 'Logout');
    expect(confirmLogoutButton, findsOneWidget);
    await tester.tap(confirmLogoutButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));

    // Pump transition frames to let the logout redirect route complete
    print('DIAG: Pumping logout navigation transition frames...');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // -------------------------------------------------------------------------
    // 10. Show login screen
    // -------------------------------------------------------------------------
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

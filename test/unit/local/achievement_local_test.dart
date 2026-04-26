import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Local/achievement_local.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AchievementLocal.getUnlockedAchievementIds()', () {
    test('returns empty set when nothing is saved', () async {
      final ids = await AchievementLocal().getUnlockedAchievementIds();
      expect(ids, isEmpty);
    });

    test('returns saved ids after saveUnlockedAchievementId', () async {
      final local = AchievementLocal();
      await local.saveUnlockedAchievementId('monthly_first_2026_04');

      final ids = await local.getUnlockedAchievementIds();
      expect(ids, contains('monthly_first_2026_04'));
    });

    test('accumulates multiple ids without duplicates', () async {
      final local = AchievementLocal();
      await local.saveUnlockedAchievementId('id_a');
      await local.saveUnlockedAchievementId('id_b');
      await local.saveUnlockedAchievementId('id_a'); // duplicate

      final ids = await local.getUnlockedAchievementIds();
      expect(ids.length, 2);
      expect(ids, containsAll(['id_a', 'id_b']));
    });
  });

  group('AchievementLocal.saveUnlockedAchievementId()', () {
    test('persists across separate instances (same prefs)', () async {
      await AchievementLocal().saveUnlockedAchievementId('monthly_ten_2026_04');

      // New instance reads the same SharedPreferences
      final ids = await AchievementLocal().getUnlockedAchievementIds();
      expect(ids, contains('monthly_ten_2026_04'));
    });
  });

  group('AchievementLocal.clearUnlockedAchievements()', () {
    test('removes all saved ids', () async {
      final local = AchievementLocal();
      await local.saveUnlockedAchievementId('id_a');
      await local.saveUnlockedAchievementId('id_b');

      await local.clearUnlockedAchievements();

      final ids = await local.getUnlockedAchievementIds();
      expect(ids, isEmpty);
    });

    test('clear on empty storage does not throw', () async {
      await expectLater(
        AchievementLocal().clearUnlockedAchievements(),
        completes,
      );
    });
  });
}

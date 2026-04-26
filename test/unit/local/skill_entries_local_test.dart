import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Local/skill_entries_local.dart';
import 'package:motive_me/Models/activity_model.dart';
import 'package:motive_me/Models/user_activity_model.dart';

void main() {
  final now = DateTime.now();

  ({UserActivity userActivity, Activity activity}) makeEntry({
    String id = 'ua1',
    String actId = 'a1',
    String name = 'Running',
    int reward = 50,
    int count = 3,
    int goal = 10,
    List<int> checkInDates = const [],
  }) {
    return (
      userActivity: UserActivity(
        id: id,
        activityId: actId,
        startDate: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        expireDate: now.add(const Duration(days: 30)).millisecondsSinceEpoch,
        goal: goal,
        count: count,
        checkInDates: checkInDates,
      ),
      activity: Activity(id: actId, name: name, reward: reward),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SkillEntriesLocal.load()', () {
    test('returns empty list when nothing is saved', () async {
      final entries = await SkillEntriesLocal().load();
      expect(entries, isEmpty);
    });
  });

  group('SkillEntriesLocal.save() and load()', () {
    test('persists a single entry and restores it', () async {
      final local = SkillEntriesLocal();
      final entry = makeEntry();
      await local.save([entry]);

      final loaded = await local.load();
      expect(loaded.length, 1);
      expect(loaded.first.userActivity.id, 'ua1');
      expect(loaded.first.activity.name, 'Running');
      expect(loaded.first.activity.reward, 50);
      expect(loaded.first.userActivity.count, 3);
      expect(loaded.first.userActivity.goal, 10);
    });

    test('persists multiple entries', () async {
      final local = SkillEntriesLocal();
      final entries = [
        makeEntry(id: 'ua1', actId: 'a1', name: 'Running'),
        makeEntry(id: 'ua2', actId: 'a2', name: 'Yoga', reward: 30, count: 5),
      ];
      await local.save(entries);

      final loaded = await local.load();
      expect(loaded.length, 2);
      expect(loaded.map((e) => e.activity.name), containsAll(['Running', 'Yoga']));
    });

    test('persists checkInDates correctly', () async {
      final local = SkillEntriesLocal();
      final checkIns = [1000, 2000, 3000];
      await local.save([makeEntry(checkInDates: checkIns)]);

      final loaded = await local.load();
      expect(loaded.first.userActivity.checkInDates, checkIns);
    });

    test('overwrites previous data on subsequent saves', () async {
      final local = SkillEntriesLocal();
      await local.save([makeEntry(name: 'Old')]);
      await local.save([makeEntry(id: 'ua2', actId: 'a2', name: 'New')]);

      final loaded = await local.load();
      expect(loaded.length, 1);
      expect(loaded.first.activity.name, 'New');
    });

    test('saving empty list results in empty load', () async {
      final local = SkillEntriesLocal();
      await local.save([makeEntry()]); // save something first
      await local.save([]); // then overwrite with empty

      final loaded = await local.load();
      expect(loaded, isEmpty);
    });
  });

  group('SkillEntriesLocal.clear()', () {
    test('removes all saved entries', () async {
      final local = SkillEntriesLocal();
      await local.save([makeEntry(), makeEntry(id: 'ua2', actId: 'a2')]);
      await local.clear();

      final loaded = await local.load();
      expect(loaded, isEmpty);
    });

    test('clear on empty storage does not throw', () async {
      await expectLater(SkillEntriesLocal().clear(), completes);
    });
  });
}

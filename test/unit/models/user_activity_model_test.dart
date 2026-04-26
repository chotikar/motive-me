import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Models/user_activity_model.dart';

void main() {
  final now = DateTime.now();

  /// Factory helper so every test only specifies what it cares about.
  UserActivity make({
    int? count,
    int? goal,
    int? expireDate,
    int? startDate,
    List<int>? checkInDates,
  }) {
    return UserActivity(
      id: 'ua1',
      activityId: 'act1',
      startDate:
          startDate ?? now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      expireDate:
          expireDate ?? now.add(const Duration(days: 30)).millisecondsSinceEpoch,
      goal: goal ?? 10,
      count: count ?? 0,
      checkInDates: checkInDates ?? [],
    );
  }

  // ── isExpired ─────────────────────────────────────────────
  group('isExpired', () {
    test('false when expiry is in the future', () {
      expect(make().isExpired, isFalse);
    });

    test('true when expiry is in the past', () {
      final past =
          now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
      expect(make(expireDate: past).isExpired, isTrue);
    });
  });

  // ── isCompleted ───────────────────────────────────────────
  group('isCompleted', () {
    test('false when count < goal', () {
      expect(make(count: 3, goal: 10).isCompleted, isFalse);
    });

    test('true when count == goal', () {
      expect(make(count: 10, goal: 10).isCompleted, isTrue);
    });

    test('true when count > goal', () {
      expect(make(count: 11, goal: 10).isCompleted, isTrue);
    });

    test('true when count == goal == 0', () {
      expect(make(count: 0, goal: 0).isCompleted, isTrue);
    });
  });

  // ── progress ──────────────────────────────────────────────
  group('progress', () {
    test('returns count/goal ratio', () {
      expect(make(count: 5, goal: 10).progress, 0.5);
      expect(make(count: 0, goal: 10).progress, 0.0);
      expect(make(count: 10, goal: 10).progress, 1.0);
    });

    test('returns 0.0 when goal is 0', () {
      expect(make(count: 0, goal: 0).progress, 0.0);
    });
  });

  // ── hasCheckedInToday ─────────────────────────────────────
  group('hasCheckedInToday', () {
    test('true when a timestamp from today exists', () {
      final todayTs =
          DateTime(now.year, now.month, now.day, 10).millisecondsSinceEpoch;
      expect(make(checkInDates: [todayTs]).hasCheckedInToday, isTrue);
    });

    test('false when only yesterday timestamps exist', () {
      final yesterday =
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      expect(make(checkInDates: [yesterday]).hasCheckedInToday, isFalse);
    });

    test('false when checkInDates is empty', () {
      expect(make(checkInDates: []).hasCheckedInToday, isFalse);
    });

    test('true when list has multiple, including today', () {
      final yesterday =
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final todayTs =
          DateTime(now.year, now.month, now.day, 8).millisecondsSinceEpoch;
      expect(
          make(checkInDates: [yesterday, todayTs]).hasCheckedInToday, isTrue);
    });
  });

  // ── canCheckIn ────────────────────────────────────────────
  group('canCheckIn', () {
    test('true when active, not completed, not checked in today', () {
      expect(make().canCheckIn, isTrue);
    });

    test('false when expired', () {
      final past =
          now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
      expect(make(expireDate: past).canCheckIn, isFalse);
    });

    test('false when completed', () {
      expect(make(count: 10, goal: 10).canCheckIn, isFalse);
    });

    test('false when already checked in today', () {
      final todayTs =
          DateTime(now.year, now.month, now.day, 9).millisecondsSinceEpoch;
      expect(make(checkInDates: [todayTs]).canCheckIn, isFalse);
    });
  });

  // ── toMap ─────────────────────────────────────────────────
  group('toMap()', () {
    test('includes all fields', () {
      final ua = make(count: 3, checkInDates: [1000, 2000]);
      final map = ua.toMap();

      expect(map['id'], 'ua1');
      expect(map['activityId'], 'act1');
      expect(map['count'], 3);
      expect(map['goal'], 10);
      expect(map['checkInDates'], [1000, 2000]);
    });

    test('omits checkInDates key when list is empty', () {
      final map = make().toMap();
      expect(map.containsKey('checkInDates'), isFalse);
    });
  });

  // ── fromMap ───────────────────────────────────────────────
  group('fromMap()', () {
    test('parses List checkInDates', () {
      final ua = UserActivity.fromMap('ua1', {
        'activityId': 'act1',
        'startDate': 100,
        'expireDate': 9999999999,
        'goal': 5,
        'count': 2,
        'checkInDates': [1000, 2000],
      });
      expect(ua.checkInDates, [1000, 2000]);
    });

    test('parses Map-style checkInDates (Firebase integer-key maps)', () {
      final ua = UserActivity.fromMap('ua1', {
        'activityId': 'act1',
        'startDate': 100,
        'expireDate': 9999999999,
        'goal': 5,
        'count': 1,
        'checkInDates': {'0': 1000, '1': 2000},
      });
      expect(ua.checkInDates, containsAll([1000, 2000]));
    });

    test('handles missing checkInDates', () {
      final ua = UserActivity.fromMap('ua1', {
        'activityId': 'act1',
        'startDate': 100,
        'expireDate': 9999999999,
        'goal': 5,
        'count': 0,
      });
      expect(ua.checkInDates, isEmpty);
    });

    test('uses defaults for missing numeric fields', () {
      final ua = UserActivity.fromMap('ua1', {'activityId': 'a'});
      expect(ua.goal, 1);
      expect(ua.count, 0);
      expect(ua.startDate, 0);
      expect(ua.expireDate, 0);
    });

    test('round-trip toMap → fromMap preserves all data', () {
      final original = make(count: 4, checkInDates: [1000, 2000, 3000]);
      final restored =
          UserActivity.fromMap(original.id, original.toMap());

      expect(restored.id, original.id);
      expect(restored.activityId, original.activityId);
      expect(restored.count, original.count);
      expect(restored.goal, original.goal);
      expect(restored.checkInDates, original.checkInDates);
    });
  });

  // ── copyWith ──────────────────────────────────────────────
  group('copyWith()', () {
    test('updates count and checkInDates', () {
      final ua = make(count: 2);
      final updated = ua.copyWith(count: 3, checkInDates: [9999]);

      expect(updated.count, 3);
      expect(updated.checkInDates, [9999]);
      expect(updated.id, ua.id);
      expect(updated.goal, ua.goal);
    });

    test('keeps original values when no args given', () {
      final ua = make(count: 5, checkInDates: [1, 2]);
      final copy = ua.copyWith();

      expect(copy.count, 5);
      expect(copy.checkInDates, [1, 2]);
    });
  });
}

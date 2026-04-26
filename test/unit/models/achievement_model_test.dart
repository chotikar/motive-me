import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Models/achievement_model.dart';

void main() {
  Achievement make({
    String id = 'ach1',
    String uid = 'u1',
    String title = 'Month Starter',
    String description = 'Completed 1 habit',
    String icon = '🌱',
    String category = 'monthly',
    int unlockedAt = 1000,
    bool isUnlocked = true,
  }) {
    return Achievement(
      id: id,
      uid: uid,
      title: title,
      description: description,
      icon: icon,
      category: category,
      unlockedAt: unlockedAt,
      isUnlocked: isUnlocked,
    );
  }

  group('Achievement.toMap()', () {
    test('includes all fields except id', () {
      final map = make().toMap();

      expect(map['uid'], 'u1');
      expect(map['title'], 'Month Starter');
      expect(map['description'], 'Completed 1 habit');
      expect(map['icon'], '🌱');
      expect(map['category'], 'monthly');
      expect(map['unlockedAt'], 1000);
      expect(map['isUnlocked'], true);
      expect(map.containsKey('id'), isFalse);
    });

    test('isUnlocked false is preserved', () {
      final map = make(isUnlocked: false).toMap();
      expect(map['isUnlocked'], false);
    });
  });

  group('Achievement.fromMap()', () {
    test('parses all fields correctly', () {
      final a = Achievement.fromMap('ach1', {
        'uid': 'u1',
        'title': 'Champion',
        'description': 'Done 5 habits',
        'icon': '🏆',
        'category': 'monthly',
        'unlockedAt': 5000,
        'isUnlocked': true,
      });

      expect(a.id, 'ach1');
      expect(a.uid, 'u1');
      expect(a.title, 'Champion');
      expect(a.description, 'Done 5 habits');
      expect(a.icon, '🏆');
      expect(a.category, 'monthly');
      expect(a.unlockedAt, 5000);
      expect(a.isUnlocked, true);
    });

    test('uses default values for missing fields', () {
      final a = Achievement.fromMap('x', {});

      expect(a.uid, '');
      expect(a.title, '');
      expect(a.description, '');
      expect(a.icon, '🏆');
      expect(a.category, 'milestone');
      expect(a.unlockedAt, 0);
      expect(a.isUnlocked, true);
    });

    test('round-trip toMap → fromMap preserves all data', () {
      final original = make(
        id: 'ach2',
        title: 'Unstoppable',
        unlockedAt: 99999,
        isUnlocked: true,
      );
      final restored = Achievement.fromMap(original.id, original.toMap());

      expect(restored.id, original.id);
      expect(restored.uid, original.uid);
      expect(restored.title, original.title);
      expect(restored.icon, original.icon);
      expect(restored.unlockedAt, original.unlockedAt);
      expect(restored.isUnlocked, original.isUnlocked);
    });
  });
}

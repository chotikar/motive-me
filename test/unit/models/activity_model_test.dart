import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Models/activity_model.dart';

void main() {
  group('Activity.toMap()', () {
    test('includes id, name and reward', () {
      final act = Activity(id: 'a1', name: 'Running', reward: 50);
      final map = act.toMap();

      expect(map['id'], 'a1');
      expect(map['name'], 'Running');
      expect(map['reward'], 50);
      expect(map.length, 3);
    });

    test('toMap → fromMap round-trips correctly', () {
      final act = Activity(id: 'a2', name: 'Yoga', reward: 30);
      final restored = Activity.fromMap('a2', act.toMap());

      expect(restored.id, act.id);
      expect(restored.name, act.name);
      expect(restored.reward, act.reward);
    });
  });

  group('Activity.fromMap()', () {
    test('parses all fields correctly', () {
      final act = Activity.fromMap('a1', {'name': 'Cycling', 'reward': 40});
      expect(act.id, 'a1');
      expect(act.name, 'Cycling');
      expect(act.reward, 40);
    });

    test('uses defaults for missing fields', () {
      final act = Activity.fromMap('a1', {});
      expect(act.name, '');
      expect(act.reward, 0);
    });

    test('reward casts num to int', () {
      final act = Activity.fromMap('a1', {'name': 'Walk', 'reward': 10.0});
      expect(act.reward, 10);
      expect(act.reward, isA<int>());
    });
  });

  group('Activity.copyWith()', () {
    test('updates name only', () {
      final act = Activity(id: 'a1', name: 'Old', reward: 10);
      final copy = act.copyWith(name: 'New');

      expect(copy.name, 'New');
      expect(copy.reward, 10);
      expect(copy.id, 'a1');
    });

    test('updates reward only', () {
      final act = Activity(id: 'a1', name: 'Walk', reward: 10);
      final copy = act.copyWith(reward: 99);

      expect(copy.reward, 99);
      expect(copy.name, 'Walk');
      expect(copy.id, 'a1');
    });

    test('returns identical values when no args given', () {
      final act = Activity(id: 'a1', name: 'Walk', reward: 10);
      final copy = act.copyWith();

      expect(copy.name, act.name);
      expect(copy.reward, act.reward);
    });
  });
}

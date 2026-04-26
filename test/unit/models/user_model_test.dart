import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Models/user_model.dart';

void main() {
  group('UserModel.toMap()', () {
    test('returns all fields except uid', () {
      final user = UserModel(
        uid: 'uid1',
        name: 'Alice',
        email: 'alice@test.com',
        photoUrl: 'http://photo.url',
        bio: 'Hello',
        createdAt: 1000,
        updatedAt: 2000,
      );
      final map = user.toMap();

      expect(map['name'], 'Alice');
      expect(map['email'], 'alice@test.com');
      expect(map['photoUrl'], 'http://photo.url');
      expect(map['bio'], 'Hello');
      expect(map['createdAt'], 1000);
      expect(map['updatedAt'], 2000);
      expect(map.containsKey('uid'), isFalse);
    });

    test('includes null photoUrl and bio', () {
      final user = UserModel(
        uid: 'u',
        name: 'N',
        email: 'e@e.com',
        createdAt: 0,
        updatedAt: 0,
      );
      final map = user.toMap();
      expect(map['photoUrl'], isNull);
      expect(map['bio'], isNull);
    });
  });

  group('UserModel.fromMap()', () {
    test('parses all fields correctly', () {
      final map = {
        'name': 'Bob',
        'email': 'bob@test.com',
        'photoUrl': 'http://photo',
        'bio': 'Bio text',
        'createdAt': 100,
        'updatedAt': 200,
      };
      final user = UserModel.fromMap('uid2', map);

      expect(user.uid, 'uid2');
      expect(user.name, 'Bob');
      expect(user.email, 'bob@test.com');
      expect(user.photoUrl, 'http://photo');
      expect(user.bio, 'Bio text');
      expect(user.createdAt, 100);
      expect(user.updatedAt, 200);
    });

    test('uses defaults for missing fields', () {
      final user = UserModel.fromMap('uid3', {});

      expect(user.name, '');
      expect(user.email, '');
      expect(user.photoUrl, isNull);
      expect(user.bio, isNull);
      expect(user.createdAt, 0);
      expect(user.updatedAt, 0);
    });

    test('handles null photoUrl and bio', () {
      final user = UserModel.fromMap('u', {
        'name': 'N',
        'email': 'e@e.com',
        'photoUrl': null,
        'bio': null,
        'createdAt': 0,
        'updatedAt': 0,
      });
      expect(user.photoUrl, isNull);
      expect(user.bio, isNull);
    });
  });

  group('UserModel.newUser()', () {
    test('sets createdAt and updatedAt to current time', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final user = UserModel.newUser(uid: 'u', name: 'Name', email: 'e@e.com');
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(user.createdAt, greaterThanOrEqualTo(before));
      expect(user.createdAt, lessThanOrEqualTo(after));
      expect(user.createdAt, equals(user.updatedAt));
    });

    test('sets uid, name, email correctly', () {
      final user = UserModel.newUser(
          uid: 'uid99', name: 'Carol', email: 'carol@test.com');
      expect(user.uid, 'uid99');
      expect(user.name, 'Carol');
      expect(user.email, 'carol@test.com');
    });

    test('photoUrl and bio are null', () {
      final user = UserModel.newUser(uid: 'u', name: 'N', email: 'e@e.com');
      expect(user.photoUrl, isNull);
      expect(user.bio, isNull);
    });
  });

  group('UserModel.copyWith()', () {
    late UserModel original;

    setUp(() {
      original = UserModel(
        uid: 'u1',
        name: 'Alice',
        email: 'alice@test.com',
        photoUrl: 'http://old-photo',
        bio: 'Old bio',
        createdAt: 100,
        updatedAt: 200,
      );
    });

    test('updates name only', () {
      final copy = original.copyWith(name: 'Bob');
      expect(copy.name, 'Bob');
      expect(copy.email, 'alice@test.com');
      expect(copy.photoUrl, 'http://old-photo');
      expect(copy.bio, 'Old bio');
      expect(copy.uid, 'u1');
    });

    test('updates photoUrl only', () {
      final copy = original.copyWith(photoUrl: 'http://new-photo');
      expect(copy.photoUrl, 'http://new-photo');
      expect(copy.name, 'Alice');
    });

    test('updates bio only', () {
      final copy = original.copyWith(bio: 'New bio');
      expect(copy.bio, 'New bio');
      expect(copy.name, 'Alice');
    });

    test('updates updatedAt timestamp', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final copy = original.copyWith(name: 'Updated');
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(copy.updatedAt, greaterThanOrEqualTo(before));
      expect(copy.updatedAt, lessThanOrEqualTo(after));
    });

    test('keeps original createdAt', () {
      final copy = original.copyWith(name: 'X');
      expect(copy.createdAt, 100);
    });
  });

  group('UserModel.toString()', () {
    test('includes uid, name, email', () {
      final user = UserModel(
          uid: 'u1', name: 'Alice', email: 'a@a.com', createdAt: 0, updatedAt: 0);
      final str = user.toString();
      expect(str, contains('u1'));
      expect(str, contains('Alice'));
      expect(str, contains('a@a.com'));
    });
  });
}

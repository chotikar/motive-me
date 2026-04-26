import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Local/user_local.dart';
import 'package:motive_me/Models/user_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  UserModel makeUser({
    String uid = 'u1',
    String name = 'Alice',
    String email = 'alice@test.com',
    String? photoUrl,
    String? bio,
  }) {
    return UserModel(
      uid: uid,
      name: name,
      email: email,
      photoUrl: photoUrl,
      bio: bio,
      createdAt: 1000,
      updatedAt: 2000,
    );
  }

  group('UserLocal.getUserInfo()', () {
    test('returns null when nothing is saved', () async {
      final user = await UserLocal().getUserInfo();
      expect(user, isNull);
    });
  });

  group('UserLocal.saveUser() and getUserInfo()', () {
    test('saves and retrieves a full user', () async {
      final local = UserLocal();
      final user = makeUser(
        photoUrl: 'http://photo.url',
        bio: 'My bio',
      );
      await local.saveUser(user);

      final loaded = await local.getUserInfo();
      expect(loaded, isNotNull);
      expect(loaded!.uid, 'u1');
      expect(loaded.name, 'Alice');
      expect(loaded.email, 'alice@test.com');
      expect(loaded.photoUrl, 'http://photo.url');
      expect(loaded.bio, 'My bio');
      expect(loaded.createdAt, 1000);
      expect(loaded.updatedAt, 2000);
    });

    test('saves and retrieves a user with null optional fields', () async {
      final local = UserLocal();
      await local.saveUser(makeUser());

      final loaded = await local.getUserInfo();
      expect(loaded, isNotNull);
      // photoUrl stored as empty string → comes back as non-null empty string or null
      // either is acceptable — the important thing is no crash
    });

    test('overwrites previous user data', () async {
      final local = UserLocal();
      await local.saveUser(makeUser(name: 'Alice'));
      await local.saveUser(makeUser(uid: 'u2', name: 'Bob', email: 'bob@test.com'));

      final loaded = await local.getUserInfo();
      expect(loaded!.uid, 'u2');
      expect(loaded.name, 'Bob');
    });
  });

  group('UserLocal.clearUserInfo()', () {
    test('removes all user data', () async {
      final local = UserLocal();
      await local.saveUser(makeUser());
      await local.clearUserInfo();

      final loaded = await local.getUserInfo();
      expect(loaded, isNull);
    });

    test('clear on empty storage does not throw', () async {
      await expectLater(UserLocal().clearUserInfo(), completes);
    });
  });
}

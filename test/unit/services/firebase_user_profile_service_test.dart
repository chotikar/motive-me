import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:motive_me/Local/user_local.dart';
import 'package:motive_me/Models/user_model.dart';
import 'package:motive_me/Services/firebase_user_profile_service.dart';

// ── Fake Firebase helpers ─────────────────────────────────────────────────

class FakeDataSnapshot extends Fake implements DataSnapshot {
  final bool _exists;
  final Object? _value;

  FakeDataSnapshot({required bool exists, Object? value})
      : _exists = exists,
        _value = value;

  @override
  bool get exists => _exists;

  @override
  Object? get value => _value;
}

class FakeDatabaseRef extends Fake implements DatabaseReference {
  FakeDataSnapshot? _snapshot;
  Exception? _throwOnGet;
  Exception? _throwOnUpdate;
  Exception? _throwOnSet;

  Map<String, Object?>? capturedUpdate;
  Object? capturedSet;

  void setSnapshot(FakeDataSnapshot s) => _snapshot = s;
  void setThrowOnGet(Exception e) => _throwOnGet = e;
  void setThrowOnUpdate(Exception e) => _throwOnUpdate = e;
  void setThrowOnSet(Exception e) => _throwOnSet = e;

  @override
  Future<DataSnapshot> get() async {
    if (_throwOnGet != null) throw _throwOnGet!;
    return _snapshot!;
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    if (_throwOnUpdate != null) throw _throwOnUpdate!;
    capturedUpdate = Map<String, Object?>.from(value);
  }

  @override
  Future<void> set(Object? value, {Object? priority}) async {
    if (_throwOnSet != null) throw _throwOnSet!;
    capturedSet = value;
  }
}

/// Routes path → FakeDatabaseRef.  Root ref (no arg) is stored under key ''.
class FakeDb extends Fake implements FirebaseDatabase {
  final Map<String, FakeDatabaseRef> _pathRefs = {};
  final List<String?> calledPaths = [];

  FakeDatabaseRef refFor(String path) =>
      _pathRefs.putIfAbsent(path, FakeDatabaseRef.new);

  @override
  DatabaseReference ref([String? path]) {
    calledPaths.add(path);
    return _pathRefs[path ?? ''] ?? FakeDatabaseRef();
  }
}

class FakeAuth extends Fake implements FirebaseAuth {
  User? user;

  @override
  User? get currentUser => user;
}

class FakeUser extends Fake implements User {
  final String _uid;
  FakeUser(this._uid);

  @override
  String get uid => _uid;
}

// ── Fake UserLocal ────────────────────────────────────────────────────────

class FakeUserLocal extends Fake implements UserLocal {
  UserModel? userToReturn;
  UserModel? savedUser;
  Exception? throwOnSave;
  Exception? throwOnGetUserInfo;

  @override
  Future<void> saveUser(UserModel userModel) async {
    if (throwOnSave != null) throw throwOnSave!;
    savedUser = userModel;
  }

  @override
  Future<UserModel?> getUserInfo() async {
    if (throwOnGetUserInfo != null) throw throwOnGetUserInfo!;
    return userToReturn;
  }
}

// ── Connectivity channel helpers ──────────────────────────────────────────

const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

void _mockOnline() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return ['wifi'];
    return null;
  });
}

void _mockOffline() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return ['none'];
    return null;
  });
}

void _clearChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, null);
}

// ── Test data factories ───────────────────────────────────────────────────

UserModel _makeUser({
  String uid = 'uid1',
  String name = 'Alice',
  String email = 'alice@test.com',
  String? photoUrl = 'https://photo.url/alice.jpg',
  String? bio = 'Flutter developer',
  int createdAt = 1000,
  int updatedAt = 2000,
}) =>
    UserModel(
      uid: uid,
      name: name,
      email: email,
      photoUrl: photoUrl,
      bio: bio,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

Map<String, Object?> _dbProfileData({
  String name = 'Alice',
  String email = 'alice@test.com',
  String? photoUrl = 'https://photo.url/alice.jpg',
  String? bio = 'Flutter developer',
  int createdAt = 1000,
  int updatedAt = 2000,
}) =>
    {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearChannelMock);

  // ── mapToUserModel() – pure helper, no I/O ───────────────────────────────

  group('FirebaseUserProfileService.mapToUserModel()', () {
    // mapToUserModel is pure — constructor needs injected fakes so it doesn't
    // touch FirebaseDatabase.instance / FirebaseAuth.instance.
    late FirebaseUserProfileService svc;

    setUp(() {
      svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth(),
        userLocal: FakeUserLocal(),
      );
    });

    test('maps all fields from a complete map', () {
      final result = svc.mapToUserModel('u1', {
        'name': 'Alice',
        'email': 'alice@test.com',
        'photoUrl': 'https://photo.url',
        'bio': 'Developer',
        'createdAt': 1000,
        'updatedAt': 2000,
      });

      expect(result.uid, 'u1');
      expect(result.name, 'Alice');
      expect(result.email, 'alice@test.com');
      expect(result.photoUrl, 'https://photo.url');
      expect(result.bio, 'Developer');
      expect(result.createdAt, 1000);
      expect(result.updatedAt, 2000);
    });

    test('handles null photoUrl and bio', () {
      final result = svc.mapToUserModel('u2', {
        'name': 'Bob',
        'email': 'bob@test.com',
        'photoUrl': null,
        'bio': null,
        'createdAt': 0,
        'updatedAt': 0,
      });

      expect(result.uid, 'u2');
      expect(result.photoUrl, isNull);
      expect(result.bio, isNull);
    });

    test('returns a UserModel instance', () {
      final result = svc.mapToUserModel('u1', {
        'name': 'Alice',
        'email': 'alice@test.com',
      });
      expect(result, isA<UserModel>());
    });

    test('uses default empty string for missing name and email', () {
      final result = svc.mapToUserModel('u3', {});
      expect(result.name, '');
      expect(result.email, '');
    });
  });

  // ── Offline guard ─────────────────────────────────────────────────────────

  group('FirebaseUserProfileService – offline guard', () {
    setUp(_mockOffline);

    test('createUserProfile() throws wrapped message when offline', () async {
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth(),
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.createUserProfile(_makeUser()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create user profile'),
        )),
      );
    });

    test('getUserProfile() throws wrapped message when offline', () async {
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth(),
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.getUserProfile(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get user profile'),
        )),
      );
    });

    test('updateUserProfile() throws wrapped message when offline', () async {
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth(),
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user profile'),
        )),
      );
    });
  });

  // ── Unauthenticated (online, user == null) ────────────────────────────────

  group('FirebaseUserProfileService – unauthenticated', () {
    setUp(_mockOnline);

    test('createUserProfile() throws wrapped message when user is null',
        () async {
      // _uid throws 'User not authenticated' → caught → wrapped
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.createUserProfile(_makeUser()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create user profile'),
        )),
      );
    });

    test('getUserProfile() throws wrapped message when user is null', () async {
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.getUserProfile(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get user profile'),
        )),
      );
    });

    test(
        'updateUserProfile() throws wrapped message when user is null '
        'after getUserInfo() succeeds', () async {
      // getUserInfo() returns a user → copyWith succeeds →
      // then _db.ref('users/$_uid') calls _uid → throws → caught → wrapped
      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
        userLocal: userLocal,
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user profile'),
        )),
      );
    });
  });

  // ── createUserProfile() ───────────────────────────────────────────────────

  group('FirebaseUserProfileService – createUserProfile()', () {
    setUp(_mockOnline);

    test('calls set on the correct uid-scoped users path', () async {
      final db = FakeDb();
      db.refFor('users/uid1');

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await svc.createUserProfile(_makeUser());

      expect(db.calledPaths, contains('users/uid1'));
    });

    test('set payload contains name, email, photoUrl, bio', () async {
      final db = FakeDb();
      db.refFor('users/uid1');

      final user = _makeUser(
        name: 'Alice',
        email: 'alice@test.com',
        photoUrl: 'https://photo.url',
        bio: 'Dev',
      );
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await svc.createUserProfile(user);

      final payload = db.refFor('users/uid1').capturedSet as Map;
      expect(payload['name'], 'Alice');
      expect(payload['email'], 'alice@test.com');
      expect(payload['photoUrl'], 'https://photo.url');
      expect(payload['bio'], 'Dev');
    });

    test('set payload contains createdAt key (server timestamp)', () async {
      final db = FakeDb();
      db.refFor('users/uid1');

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await svc.createUserProfile(_makeUser());

      final payload = db.refFor('users/uid1').capturedSet as Map;
      expect(payload, contains('createdAt'));
    });

    test('saves user to local storage via UserLocal.saveUser()', () async {
      final db = FakeDb();
      db.refFor('users/uid1');
      final userLocal = FakeUserLocal();

      final user = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await svc.createUserProfile(user);

      expect(userLocal.savedUser, isNotNull);
      expect(userLocal.savedUser!.uid, user.uid);
      expect(userLocal.savedUser!.name, user.name);
    });

    test('completes without error for valid inputs', () async {
      final db = FakeDb();
      db.refFor('users/uid1');

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await expectLater(svc.createUserProfile(_makeUser()), completes);
    });

    test('throws wrapped message when Firebase set() fails', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setThrowOnSet(Exception('Permission denied'));

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.createUserProfile(_makeUser()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create user profile'),
        )),
      );
    });

    test('throws wrapped message when UserLocal.saveUser() fails', () async {
      final db = FakeDb();
      db.refFor('users/uid1');
      final userLocal = FakeUserLocal()
        ..throwOnSave = Exception('Storage full');

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await expectLater(
        svc.createUserProfile(_makeUser()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create user profile'),
        )),
      );
    });
  });

  // ── getUserProfile() ──────────────────────────────────────────────────────

  group('FirebaseUserProfileService – getUserProfile()', () {
    setUp(_mockOnline);

    test('returns Map<String, dynamic> when snapshot exists', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: _dbProfileData(name: 'Alice'),
      ));

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      final result = await svc.getUserProfile();

      expect(result, isNotNull);
      expect(result!['name'], 'Alice');
    });

    test('returns null when snapshot does not exist', () async {
      final db = FakeDb();
      db.refFor('users/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      final result = await svc.getUserProfile();

      expect(result, isNull);
    });

    test('queries the uid-scoped users path', () async {
      final db = FakeDb();
      db.refFor('users/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await svc.getUserProfile();

      expect(db.calledPaths, contains('users/uid1'));
    });

    test('returned map contains all persisted fields', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: _dbProfileData(
          name: 'Alice',
          email: 'alice@test.com',
          photoUrl: 'https://photo.url',
          bio: 'Dev',
        ),
      ));

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      final result = await svc.getUserProfile();

      expect(result!['email'], 'alice@test.com');
      expect(result['photoUrl'], 'https://photo.url');
      expect(result['bio'], 'Dev');
    });

    test('throws wrapped message when Firebase get() fails', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setThrowOnGet(Exception('Network error'));

      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: FakeUserLocal(),
      );
      await expectLater(
        svc.getUserProfile(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get user profile'),
        )),
      );
    });
  });

  // ── updateUserProfile() ───────────────────────────────────────────────────

  group('FirebaseUserProfileService – updateUserProfile() – user not found',
      () {
    setUp(_mockOnline);

    test('throws wrapped message when UserLocal.getUserInfo() returns null',
        () async {
      // getUserInfo() → null → throws 'User not found' → caught → wrapped
      final userLocal = FakeUserLocal()..userToReturn = null;
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user profile'),
        )),
      );
    });

    test('throws wrapped message when UserLocal.getUserInfo() throws', () async {
      final userLocal = FakeUserLocal()
        ..throwOnGetUserInfo = Exception('Local DB error');
      final svc = FirebaseUserProfileService(
        db: FakeDb(),
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user profile'),
        )),
      );
    });
  });

  group(
      'FirebaseUserProfileService – updateUserProfile() – snapshot exists after update',
      () {
    setUp(_mockOnline);

    test('returns UserModel fetched from Firebase after update', () async {
      final db = FakeDb();
      // Same ref handles both update() and get() calls for 'users/uid1'
      db.refFor('users/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: _dbProfileData(name: 'Bob', bio: 'Updated'),
      ));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );

      final result = await svc.updateUserProfile(name: 'Bob', bio: 'Updated');

      expect(result, isA<UserModel>());
      expect(result.name, 'Bob');
      expect(result.bio, 'Updated');
    });

    test('Firebase update() payload contains name, photoUrl, bio, updatedAt',
        () async {
      final db = FakeDb();
      db.refFor('users/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: _dbProfileData(name: 'Bob', photoUrl: 'new.jpg', bio: 'New bio'),
      ));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await svc.updateUserProfile(name: 'Bob', photo: 'new.jpg', bio: 'New bio');

      final payload = db.refFor('users/uid1').capturedUpdate;
      expect(payload, isNotNull);
      expect(payload!['name'], 'Bob');
      expect(payload['photoUrl'], 'new.jpg');
      expect(payload['bio'], 'New bio');
      expect(payload, contains('updatedAt'));
    });

    test('saves the Firebase-fetched user to local storage', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: _dbProfileData(name: 'Bob'),
      ));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await svc.updateUserProfile(name: 'Bob');

      expect(userLocal.savedUser, isNotNull);
      expect(userLocal.savedUser!.name, 'Bob');
    });

    test('queries uid-scoped users path for update and re-fetch', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: _dbProfileData(),
      ));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await svc.updateUserProfile(name: 'Bob');

      // path called twice: once for update(), once for get()
      expect(db.calledPaths.where((p) => p == 'users/uid1').length, 2);
    });

    test('throws wrapped message when Firebase update() fails', () async {
      final db = FakeDb();
      db.refFor('users/uid1').setThrowOnUpdate(Exception('Write denied'));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user profile'),
        )),
      );
    });

    test('throws wrapped message when Firebase get() fails after update',
        () async {
      final db = FakeDb();
      db.refFor('users/uid1').setThrowOnGet(Exception('Read timeout'));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update user profile'),
        )),
      );
    });
  });

  group(
      'FirebaseUserProfileService – updateUserProfile() – snapshot NOT exists after update',
      () {
    setUp(_mockOnline);

    test('returns locally-computed updatedUser when snapshot is absent',
        () async {
      // snapshot.exists = false → the service skips saveUser and returns
      // the in-memory copyWith result
      final db = FakeDb();
      db.refFor('users/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final userLocal = FakeUserLocal()
        ..userToReturn = _makeUser(name: 'Alice', bio: 'Old bio');
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );

      final result = await svc.updateUserProfile(name: 'Alice', bio: 'New bio');

      expect(result.name, 'Alice');
      expect(result.bio, 'New bio');
    });

    test('does NOT call UserLocal.saveUser() when snapshot is absent',
        () async {
      final db = FakeDb();
      db.refFor('users/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await svc.updateUserProfile(name: 'Alice');

      // saveUser was never called — no Firebase snapshot to sync
      expect(userLocal.savedUser, isNull);
    });

    test('completes without error when snapshot is absent', () async {
      final db = FakeDb();
      db.refFor('users/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final userLocal = FakeUserLocal()..userToReturn = _makeUser();
      final svc = FirebaseUserProfileService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
        userLocal: userLocal,
      );
      await expectLater(
        svc.updateUserProfile(name: 'Bob'),
        completes,
      );
    });
  });
}

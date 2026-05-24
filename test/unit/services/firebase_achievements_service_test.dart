import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:motive_me/Models/achievement_model.dart';
import 'package:motive_me/Services/firebase_achievements_service.dart';

// ── Fake Firebase helpers (no build_runner) ───────────────────────────────

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

class FakeDb extends Fake implements FirebaseDatabase {
  final Map<String, FakeDatabaseRef> _pathRefs = {};
  final List<String?> calledPaths = [];

  /// Pre-registers (or retrieves) a ref for [path].
  FakeDatabaseRef refFor(String path) =>
      _pathRefs.putIfAbsent(path, FakeDatabaseRef.new);

  @override
  DatabaseReference ref([String? path]) {
    calledPaths.add(path);
    return _pathRefs[path] ?? FakeDatabaseRef();
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

Achievement _makeAchievement({
  String id = 'ach1',
  String uid = 'uid1',
  String title = 'First Step',
  String description = 'Complete your first habit',
  String icon = '🌱',
  String category = 'milestone',
  int unlockedAt = 1000,
  bool isUnlocked = true,
}) =>
    Achievement(
      id: id,
      uid: uid,
      title: title,
      description: description,
      icon: icon,
      category: category,
      unlockedAt: unlockedAt,
      isUnlocked: isUnlocked,
    );

Map<String, Object?> _achData({
  String uid = 'uid1',
  String title = 'First Step',
  String description = 'Complete your first habit',
  String icon = '🌱',
  String category = 'milestone',
  int unlockedAt = 1000,
  bool isUnlocked = true,
}) =>
    {
      'uid': uid,
      'title': title,
      'description': description,
      'icon': icon,
      'category': category,
      'unlockedAt': unlockedAt,
      'isUnlocked': isUnlocked,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearChannelMock);

  // ── Offline guard ─────────────────────────────────────────────────────────

  group('FirebaseAchievementsService – offline guard', () {
    setUp(_mockOffline);

    test('unlockAchievement() throws wrapped message when offline', () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.unlockAchievement('ach1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to unlock achievement'),
        )),
      );
    });

    test('saveAchievement() throws wrapped message when offline', () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.saveAchievement(_makeAchievement()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to save achievement'),
        )),
      );
    });

    test('getUserAchievements() throws wrapped message when offline', () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.getUserAchievements(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get achievements'),
        )),
      );
    });

    test('getAchievementCount() returns 0 silently when offline', () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      expect(await svc.getAchievementCount(), 0);
    });
  });

  // ── Unauthenticated (online, user == null) ────────────────────────────────

  group('FirebaseAchievementsService – unauthenticated', () {
    setUp(_mockOnline);

    test('saveAchievement() throws wrapped message when user is null', () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      await expectLater(
        svc.saveAchievement(_makeAchievement()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to save achievement'),
        )),
      );
    });

    test('getUserAchievements() throws wrapped message when user is null',
        () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      await expectLater(
        svc.getUserAchievements(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get achievements'),
        )),
      );
    });

    test('getAchievementCount() returns 0 silently when user is null',
        () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      expect(await svc.getAchievementCount(), 0);
    });
  });

  // ── unlockAchievement() ───────────────────────────────────────────────────

  group('FirebaseAchievementsService – unlockAchievement()', () {
    setUp(_mockOnline);

    test('calls update on the correct achievements path', () async {
      final db = FakeDb();
      db.refFor('achievements/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.unlockAchievement('ach1');

      expect(db.calledPaths, contains('achievements/ach1'));
    });

    test('update payload contains isUnlocked: true', () async {
      final db = FakeDb();
      db.refFor('achievements/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.unlockAchievement('ach1');

      expect(
        db.refFor('achievements/ach1').capturedUpdate,
        containsPair('isUnlocked', true),
      );
    });

    test('update payload contains unlockedAt key (server timestamp)', () async {
      final db = FakeDb();
      db.refFor('achievements/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.unlockAchievement('ach1');

      expect(
        db.refFor('achievements/ach1').capturedUpdate,
        contains('unlockedAt'),
      );
    });

    test('completes without error for a valid achievementId', () async {
      final svc = FirebaseAchievementsService(
        db: FakeDb()..refFor('achievements/ach99'),
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(svc.unlockAchievement('ach99'), completes);
    });

    test('does not require user authentication (no _uid access)', () async {
      // unlockAchievement() uses achievementId directly, not _uid
      final db = FakeDb();
      db.refFor('achievements/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = null, // no user — still succeeds
      );
      await expectLater(svc.unlockAchievement('ach1'), completes);
    });

    test('throws wrapped message when Firebase update() fails', () async {
      final db = FakeDb();
      db.refFor('achievements/ach1')
          .setThrowOnUpdate(Exception('Permission denied'));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.unlockAchievement('ach1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to unlock achievement'),
        )),
      );
    });
  });

  // ── saveAchievement() ─────────────────────────────────────────────────────

  group('FirebaseAchievementsService – saveAchievement()', () {
    setUp(_mockOnline);

    test('calls set on the correct uid-scoped path', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.saveAchievement(_makeAchievement(id: 'ach1'));

      expect(db.calledPaths, contains('userAchievements/uid1/ach1'));
    });

    test('set payload matches achievement.toMap() — all fields present',
        () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1/ach1');

      final achievement = _makeAchievement(
        id: 'ach1',
        uid: 'uid1',
        title: 'First Step',
        description: 'Complete your first habit',
        icon: '🌱',
        category: 'milestone',
        unlockedAt: 5000,
        isUnlocked: true,
      );

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.saveAchievement(achievement);

      final payload =
          db.refFor('userAchievements/uid1/ach1').capturedSet as Map;
      expect(payload['uid'], 'uid1');
      expect(payload['title'], 'First Step');
      expect(payload['description'], 'Complete your first habit');
      expect(payload['icon'], '🌱');
      expect(payload['category'], 'milestone');
      expect(payload['unlockedAt'], 5000);
      expect(payload['isUnlocked'], true);
    });

    test('uses uid from current user to build path', () async {
      final db = FakeDb();
      db.refFor('userAchievements/user42/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('user42'),
      );
      await svc.saveAchievement(_makeAchievement(id: 'ach1'));

      expect(db.calledPaths, contains('userAchievements/user42/ach1'));
    });

    test('completes without error for a valid achievement', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1/ach1');

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.saveAchievement(_makeAchievement(id: 'ach1')),
        completes,
      );
    });

    test('throws wrapped message when Firebase set() fails', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1/ach1')
          .setThrowOnSet(Exception('DB write error'));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.saveAchievement(_makeAchievement(id: 'ach1')),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to save achievement'),
        )),
      );
    });
  });

  // ── getUserAchievements() ─────────────────────────────────────────────────

  group('FirebaseAchievementsService – getUserAchievements()', () {
    setUp(_mockOnline);

    test('returns empty list when snapshot does not exist', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      expect(await svc.getUserAchievements(), isEmpty);
    });

    test('returns parsed list of Achievement objects', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {
          'ach1': _achData(title: 'First Step', unlockedAt: 1000),
          'ach2': _achData(title: 'Month Starter', unlockedAt: 2000),
        },
      ));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserAchievements();

      expect(result, hasLength(2));
      expect(result.map((a) => a.title),
          containsAll(['First Step', 'Month Starter']));
    });

    test('each returned item is an Achievement instance', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {'ach1': _achData()},
      ));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserAchievements();

      expect(result.first, isA<Achievement>());
    });

    test('returned achievements have correct ids from map keys', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {
          'achABC': _achData(title: 'A'),
          'achXYZ': _achData(title: 'B'),
        },
      ));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserAchievements();

      expect(result.map((a) => a.id), containsAll(['achABC', 'achXYZ']));
    });

    test('sorts achievements newest first by unlockedAt', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {
          'ach1': _achData(title: 'Oldest', unlockedAt: 1000),
          'ach2': _achData(title: 'Newest', unlockedAt: 9000),
          'ach3': _achData(title: 'Middle', unlockedAt: 5000),
        },
      ));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserAchievements();

      expect(result[0].unlockedAt, 9000);
      expect(result[1].unlockedAt, 5000);
      expect(result[2].unlockedAt, 1000);
    });

    test('queries the uid-scoped userAchievements path', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.getUserAchievements();

      expect(db.calledPaths, contains('userAchievements/uid1'));
    });

    test('throws wrapped message when Firebase get() fails', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1')
          .setThrowOnGet(Exception('Network error'));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.getUserAchievements(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get achievements'),
        )),
      );
    });

    test('throws wrapped message when snapshot value is not a Map', () async {
      // snapshot.value as Map throws TypeError — caught and re-wrapped
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(
        FakeDataSnapshot(exists: true, value: 'not-a-map'),
      );

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.getUserAchievements(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get achievements'),
        )),
      );
    });
  });

  // ── getAchievementCount() ─────────────────────────────────────────────────

  group('FirebaseAchievementsService – getAchievementCount()', () {
    setUp(_mockOnline);

    test('returns 0 when snapshot does not exist', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      expect(await svc.getAchievementCount(), 0);
    });

    test('returns 1 when snapshot has exactly one entry', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {'ach1': {}},
      ));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      expect(await svc.getAchievementCount(), 1);
    });

    test('returns 3 when snapshot has 3 entries', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {'ach1': {}, 'ach2': {}, 'ach3': {}},
      ));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      expect(await svc.getAchievementCount(), 3);
    });

    test('queries the uid-scoped userAchievements path', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.getAchievementCount();

      expect(db.calledPaths, contains('userAchievements/uid1'));
    });

    test('returns 0 silently when Firebase get() throws', () async {
      final db = FakeDb();
      db.refFor('userAchievements/uid1')
          .setThrowOnGet(Exception('DB unreachable'));

      final svc = FirebaseAchievementsService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      // catch (_) { return 0; } — no exception propagated
      expect(await svc.getAchievementCount(), 0);
    });
  });
}

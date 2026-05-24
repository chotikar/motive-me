import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:motive_me/Models/activity_model.dart';
import 'package:motive_me/Models/user_activity_model.dart';
import 'package:motive_me/Services/firebase_activity_service.dart';

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

class FakeDatabaseEvent extends Fake implements DatabaseEvent {
  final DataSnapshot _snapshot;
  FakeDatabaseEvent(this._snapshot);

  @override
  DataSnapshot get snapshot => _snapshot;
}

class FakeDatabaseRef extends Fake implements DatabaseReference {
  FakeDataSnapshot? _snapshot;
  Exception? _throwOnGet;
  Map<String, Object?>? capturedUpdate;
  Object? capturedSet;
  bool removeCalled = false;
  String? _keyValue;
  Stream<DatabaseEvent>? _onValueStream;
  FakeDatabaseRef? pushedRef;

  void setSnapshot(FakeDataSnapshot s) => _snapshot = s;
  void setThrowOnGet(Exception e) => _throwOnGet = e;
  void setOnValueStream(Stream<DatabaseEvent> s) => _onValueStream = s;

  @override
  Future<DataSnapshot> get() async {
    if (_throwOnGet != null) throw _throwOnGet!;
    return _snapshot!;
  }

  @override
  Future<void> update(Map<String, Object?> value) async {
    capturedUpdate = Map<String, Object?>.from(value);
  }

  @override
  Future<void> set(Object? value, {Object? priority}) async {
    capturedSet = value;
  }

  @override
  Future<void> remove() async => removeCalled = true;

  @override
  DatabaseReference push() {
    pushedRef = FakeDatabaseRef().._keyValue = 'new-id';
    return pushedRef!;
  }

  @override
  String? get key => _keyValue;

  @override
  Stream<DatabaseEvent> get onValue =>
      _onValueStream ?? const Stream.empty();
}

class FakeDb extends Fake implements FirebaseDatabase {
  final Map<String, FakeDatabaseRef> _pathRefs = {};
  final List<String?> calledPaths = [];

  /// Pre-registers (or retrieves) a ref for [path].
  /// Call this in test setup so the service's ref() calls find the same instance.
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

void _mockConnectivity(List<String> results) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return results;
    return null;
  });
}

void _clearMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, null);
}

// ── Test data factory ─────────────────────────────────────────────────────

UserActivity _makeUA({
  int? startDate,
  int? expireDate,
  int? count,
  int? goal,
  List<int>? checkInDates,
}) {
  final now = DateTime.now();
  return UserActivity(
    id: 'ua1',
    activityId: 'a1',
    startDate: startDate ??
        now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    expireDate: expireDate ??
        now.add(const Duration(days: 30)).millisecondsSinceEpoch,
    goal: goal ?? 10,
    count: count ?? 0,
    checkInDates: checkInDates ?? [],
  );
}

Map<String, Object?> _uaData({int count = 0}) => {
      'activityId': 'actId1',
      'startDate': DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
      'expireDate':
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      'goal': 10,
      'count': count,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearMocks);

  // ── Offline – all methods that call checkOrThrow() throw ─────────────────

  group('FirebaseActivityService – offline guard', () {
    setUp(() => _mockConnectivity(['none']));

    test('createActivity() throws when offline', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.createActivity(Activity(id: '', name: 'Run', reward: 10)),
        throwsA(isA<Exception>()),
      );
    });

    test('getAllActivities() throws with wrapped message when offline',
        () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.getAllActivities(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to fetch activities'),
        )),
      );
    });

    test('updateActivity() throws with wrapped message when offline', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.updateActivity(Activity(id: 'a1', name: 'Run', reward: 10)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to update activity'),
        )),
      );
    });

    test('deleteActivity() throws with wrapped message when offline', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.deleteActivity(activityId: 'a1', userActivityId: 'ua1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to delete activity'),
        )),
      );
    });

    test('checkIn() throws when offline', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.checkIn('ua1', _makeUA()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No internet connection'),
        )),
      );
    });
  });

  // ── checkIn business-rule guards (online, throws before Firebase access) ──

  group('FirebaseActivityService – checkIn guard logic', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('throws when activity has not started yet', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      final future =
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;

      await expectLater(
        svc.checkIn('ua1', _makeUA(startDate: future)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Activity has not started yet'),
        )),
      );
    });

    test('throws when activity is expired', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      final past = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch;

      await expectLater(
        svc.checkIn('ua1', _makeUA(expireDate: past)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('skill has expired'),
        )),
      );
    });

    test('throws when activity is already completed', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());

      await expectLater(
        svc.checkIn('ua1', _makeUA(count: 10, goal: 10)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('already completed'),
        )),
      );
    });

    test('throws when already checked in today', () async {
      final svc = FirebaseActivityService(db: FakeDb(), auth: FakeAuth());
      final now = DateTime.now();
      final todayTs =
          DateTime(now.year, now.month, now.day, 8).millisecondsSinceEpoch;

      await expectLater(
        svc.checkIn('ua1', _makeUA(checkInDates: [todayTs])),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Already checked in today'),
        )),
      );
    });
  });

  // ── Unauthenticated (online, user == null) ────────────────────────────────

  group('FirebaseActivityService – unauthenticated', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('getUserActivities() throws synchronously when user is null', () {
      final svc = FirebaseActivityService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      // _uid is evaluated eagerly in the return statement — throws synchronously
      expect(
        () => svc.getUserActivities(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User not authenticated'),
        )),
      );
    });

    test('streamUserActivities() throws synchronously when user is null', () {
      final svc = FirebaseActivityService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      expect(
        () => svc.streamUserActivities(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User not authenticated'),
        )),
      );
    });

    test('deleteActivity() throws wrapped message when user is null', () async {
      final svc = FirebaseActivityService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      // _uid inside try-catch → wrapped as 'Failed to delete activity'
      await expectLater(
        svc.deleteActivity(activityId: 'actId1', userActivityId: 'ua1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to delete activity'),
        )),
      );
    });

    test('checkIn() throws User not authenticated when user is null after guards pass',
        () async {
      final svc = FirebaseActivityService(
        db: FakeDb(),
        auth: FakeAuth()..user = null,
      );
      // All guards pass with the default _makeUA(); _uid is reached and throws
      await expectLater(
        svc.checkIn('ua1', _makeUA()),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User not authenticated'),
        )),
      );
    });
  });

  // ── createActivity() ──────────────────────────────────────────────────────

  group('FirebaseActivityService – createActivity()', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('returns the pushed key as the new activity id', () async {
      final db = FakeDb();
      db.refFor('activities'); // pre-register so push() is captured

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final id = await svc.createActivity(
        Activity(id: '', name: 'Run', reward: 10),
      );

      expect(id, 'new-id');
    });

    test('calls push on the activities path', () async {
      final db = FakeDb();
      db.refFor('activities');

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      await svc.createActivity(Activity(id: '', name: 'Run', reward: 10));

      expect(db.calledPaths, contains('activities'));
    });

    test('sets activity payload including name, reward and generated id',
        () async {
      final db = FakeDb();
      final activitiesRef = db.refFor('activities');

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final id = await svc.createActivity(
        Activity(id: '', name: 'Morning Run', reward: 50),
      );

      final payload = activitiesRef.pushedRef!.capturedSet as Map;
      expect(payload['name'], 'Morning Run');
      expect(payload['reward'], 50);
      expect(payload['id'], id);
    });
  });

  // ── getUserActivities() ───────────────────────────────────────────────────

  group('FirebaseActivityService – getUserActivities()', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('returns empty list when snapshot value is null', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(exists: true, value: null),
        )),
      );

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserActivities().first;

      expect(result, isEmpty);
    });

    test('returns list of activities matching user activity ids', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(exists: true, value: {'actId1': true}),
        )),
      );
      db.refFor('activities/actId1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {'name': 'Run', 'reward': 10},
      ));

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserActivities().first;

      expect(result, hasLength(1));
      expect(result.first.name, 'Run');
      expect(result.first.reward, 10);
    });

    test('skips activity ids whose snapshot does not exist', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(
              exists: true, value: {'actId1': true, 'actId2': true}),
        )),
      );
      // actId1 exists, actId2 does not
      db.refFor('activities/actId1').setSnapshot(
        FakeDataSnapshot(exists: true, value: {'name': 'Run', 'reward': 10}),
      );
      db.refFor('activities/actId2').setSnapshot(
        FakeDataSnapshot(exists: false),
      );

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.getUserActivities().first;

      expect(result, hasLength(1));
      expect(result.first.name, 'Run');
    });

    test('emits stream error with wrapped message when snapshot data is invalid',
        () async {
      final db = FakeDb();
      // Passing a non-Map value triggers a TypeError inside asyncMap → caught
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(exists: true, value: 'not-a-map'),
        )),
      );

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );

      await expectLater(
        svc.getUserActivities(),
        emitsError(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get user activities'),
        )),
      );
    });
  });

  // ── getActivityById() ─────────────────────────────────────────────────────

  group('FirebaseActivityService – getActivityById()', () {
    // No NetworkService call in this method — no connectivity setUp needed

    test('returns Activity when snapshot exists', () async {
      final db = FakeDb();
      db.refFor('activities/actId1').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {'name': 'Run', 'reward': 10},
      ));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final result = await svc.getActivityById('actId1');

      expect(result, isNotNull);
      expect(result!.id, 'actId1');
      expect(result.name, 'Run');
      expect(result.reward, 10);
    });

    test('returns null when snapshot does not exist', () async {
      final db = FakeDb();
      db.refFor('activities/actId1')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final result = await svc.getActivityById('actId1');

      expect(result, isNull);
    });

    test('throws wrapped message when Firebase get() throws', () async {
      final db = FakeDb();
      db.refFor('activities/actId1')
          .setThrowOnGet(Exception('Firebase error'));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      await expectLater(
        svc.getActivityById('actId1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get activity'),
        )),
      );
    });
  });

  // ── getAllActivities() ────────────────────────────────────────────────────

  group('FirebaseActivityService – getAllActivities()', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('returns empty list when activities snapshot does not exist', () async {
      final db = FakeDb();
      db.refFor('activities')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final result = await svc.getAllActivities();

      expect(result, isEmpty);
    });

    test('returns parsed list of all activities', () async {
      final db = FakeDb();
      db.refFor('activities').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {
          'actId1': {'name': 'Run', 'reward': 10},
          'actId2': {'name': 'Swim', 'reward': 20},
        },
      ));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final result = await svc.getAllActivities();

      expect(result, hasLength(2));
      expect(result.map((a) => a.name), containsAll(['Run', 'Swim']));
    });

    test('each returned item is an Activity instance', () async {
      final db = FakeDb();
      db.refFor('activities').setSnapshot(FakeDataSnapshot(
        exists: true,
        value: {'actId1': {'name': 'Run', 'reward': 10}},
      ));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      final result = await svc.getAllActivities();

      expect(result.first, isA<Activity>());
    });

    test('queries the activities path', () async {
      final db = FakeDb();
      db.refFor('activities')
          .setSnapshot(FakeDataSnapshot(exists: false));

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      await svc.getAllActivities();

      expect(db.calledPaths, contains('activities'));
    });
  });

  // ── updateActivity() ──────────────────────────────────────────────────────

  group('FirebaseActivityService – updateActivity()', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('calls update on the correct activities path', () async {
      final db = FakeDb();
      db.refFor('activities/actId1');

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      await svc.updateActivity(Activity(id: 'actId1', name: 'Run', reward: 10));

      expect(db.calledPaths, contains('activities/actId1'));
    });

    test('update payload contains name and reward', () async {
      final db = FakeDb();
      db.refFor('activities/actId1');

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      await svc.updateActivity(
        Activity(id: 'actId1', name: 'Morning Run', reward: 50),
      );

      final payload = db.refFor('activities/actId1').capturedUpdate;
      expect(payload, isNotNull);
      expect(payload!['name'], 'Morning Run');
      expect(payload['reward'], 50);
    });

    test('completes without throwing for valid activity', () async {
      final db = FakeDb();
      db.refFor('activities/actId1');

      final svc = FirebaseActivityService(db: db, auth: FakeAuth());
      await expectLater(
        svc.updateActivity(Activity(id: 'actId1', name: 'Run', reward: 10)),
        completes,
      );
    });
  });

  // ── deleteActivity() ──────────────────────────────────────────────────────

  group('FirebaseActivityService – deleteActivity() success path', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('removes the userActivity ref', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1/ua1');
      db.refFor('activities/actId1');

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.deleteActivity(activityId: 'actId1', userActivityId: 'ua1');

      expect(db.refFor('userActivities/uid1/ua1').removeCalled, isTrue);
    });

    test('removes the activity ref', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1/ua1');
      db.refFor('activities/actId1');

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.deleteActivity(activityId: 'actId1', userActivityId: 'ua1');

      expect(db.refFor('activities/actId1').removeCalled, isTrue);
    });

    test('queries the correct uid-scoped userActivity path', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1/ua1');
      db.refFor('activities/actId1');

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.deleteActivity(activityId: 'actId1', userActivityId: 'ua1');

      expect(db.calledPaths, contains('userActivities/uid1/ua1'));
      expect(db.calledPaths, contains('activities/actId1'));
    });
  });

  // ── checkIn() success path ────────────────────────────────────────────────

  group('FirebaseActivityService – checkIn() success path', () {
    setUp(() => _mockConnectivity(['wifi']));

    test('calls update with incremented count', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1/ua1');

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.checkIn('ua1', _makeUA(count: 2, checkInDates: []));

      final payload = db.refFor('userActivities/uid1/ua1').capturedUpdate;
      expect(payload, isNotNull);
      expect(payload!['count'], 3);
    });

    test('appends timestamp at index equal to checkInDates.length', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1/ua1');

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      // checkInDates has 2 entries → nextIndex = '2'
      final existingTs = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      await svc.checkIn(
        'ua1',
        _makeUA(count: 2, checkInDates: [existingTs, existingTs]),
      );

      final payload = db.refFor('userActivities/uid1/ua1').capturedUpdate;
      expect(payload!.keys, contains('checkInDates/2'));
    });

    test('queries the uid-scoped userActivity path', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1/ua1');

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await svc.checkIn('ua1', _makeUA());

      expect(db.calledPaths, contains('userActivities/uid1/ua1'));
    });
  });

  // ── streamUserActivities() ────────────────────────────────────────────────

  group('FirebaseActivityService – streamUserActivities()', () {
    // No NetworkService call — no connectivity setUp needed

    test('returns empty list when snapshot value is null', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(exists: true, value: null),
        )),
      );

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.streamUserActivities().first;

      expect(result, isEmpty);
    });

    test('returns list of UserActivity objects when snapshot has data',
        () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(exists: true, value: {'ua1': _uaData(count: 3)}),
        )),
      );

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.streamUserActivities().first;

      expect(result, hasLength(1));
      expect(result.first, isA<UserActivity>());
      expect(result.first.id, 'ua1');
      expect(result.first.count, 3);
    });

    test('returns multiple UserActivity objects when snapshot has multiple entries',
        () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setOnValueStream(
        Stream.value(FakeDatabaseEvent(
          FakeDataSnapshot(
            exists: true,
            value: {
              'ua1': _uaData(count: 1),
              'ua2': _uaData(count: 5),
            },
          ),
        )),
      );

      final svc = FirebaseActivityService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      final result = await svc.streamUserActivities().first;

      expect(result, hasLength(2));
      expect(result.map((u) => u.id), containsAll(['ua1', 'ua2']));
    });
  });
}

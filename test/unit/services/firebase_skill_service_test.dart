import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:motive_me/Services/firebase_skill_service.dart';

// ── Fake Firebase helpers (no build_runner) ───────────────────────────────

class FakeDatabaseRef extends Fake implements DatabaseReference {
  // ── configuration knobs ───────────────────────────────────────────────
  String _pushKeyValue = 'new-id';
  Exception? _throwOnPush;
  Exception? _throwOnUpdate;
  Exception? _throwOnSet;

  /// The ref returned by the most recent push() call.
  FakeDatabaseRef? pushedRef;

  /// The map captured by update().
  Map<String, Object?>? capturedUpdate;

  /// The value captured by set().
  Object? capturedSet;

  String? _keyValue;

  // ── setup helpers ─────────────────────────────────────────────────────
  void setPushKey(String key) => _pushKeyValue = key;
  void setThrowOnPush(Exception e) => _throwOnPush = e;
  void setThrowOnUpdate(Exception e) => _throwOnUpdate = e;
  void setThrowOnSet(Exception e) => _throwOnSet = e;

  // ── DatabaseReference API ─────────────────────────────────────────────
  @override
  DatabaseReference push() {
    if (_throwOnPush != null) throw _throwOnPush!;
    pushedRef = FakeDatabaseRef().._keyValue = _pushKeyValue;
    return pushedRef!;
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

  @override
  String? get key => _keyValue;
}

/// Smart FakeDatabase that routes paths to individually-configured refs.
///
/// Rules:
/// - [refFor] pre-registers a path so tests can configure and later inspect it.
/// - [rootRef] pre-registers the root path (called as `_db.ref()` with no arg).
/// - Any unregistered path falls back to a fresh [FakeDatabaseRef].
class FakeDb extends Fake implements FirebaseDatabase {
  final Map<String, FakeDatabaseRef> _pathRefs = {};
  final List<String?> calledPaths = [];

  /// Pre-registers (or retrieves) the ref for [path].
  FakeDatabaseRef refFor(String path) =>
      _pathRefs.putIfAbsent(path, FakeDatabaseRef.new);

  /// Pre-registers (or retrieves) the ref used when [ref()] is called with no arg.
  FakeDatabaseRef get rootRef => _pathRefs.putIfAbsent('', FakeDatabaseRef.new);

  @override
  DatabaseReference ref([String? path]) {
    calledPaths.add(path);
    // null → root ref (key ''); otherwise exact path
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

// ── Shared test timestamps ────────────────────────────────────────────────

final _now = DateTime.now().millisecondsSinceEpoch;
final _future =
    DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearChannelMock);

  // ── Offline guard ─────────────────────────────────────────────────────────

  group('FirebaseSkillService – offline guard', () {
    setUp(_mockOffline);

    test('createSkill() throws wrapped message when offline', () async {
      final svc = FirebaseSkillService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.createSkill(
          name: 'Morning Run',
          reward: 50,
          goal: 20,
          startDate: _now,
          expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create skill'),
        )),
      );
    });

    test('addSkillFromSuggestion() throws wrapped message when offline',
        () async {
      final svc = FirebaseSkillService(db: FakeDb(), auth: FakeAuth());
      await expectLater(
        svc.addSkillFromSuggestion(
          activityId: 'act1',
          goal: 10,
          startDate: _now,
          expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to add skill from suggestion'),
        )),
      );
    });
  });

  // ── Unauthenticated (online, user == null) ────────────────────────────────

  group('FirebaseSkillService – unauthenticated', () {
    setUp(_mockOnline);

    test('createSkill() throws wrapped message when user is null', () async {
      // _uid is called at _db.ref('userActivities/$_uid').push()
      // after the activity ref is created — caught and re-wrapped
      final db = FakeDb();
      db.refFor('activities').setPushKey('act-id');

      final svc =
          FirebaseSkillService(db: db, auth: FakeAuth()..user = null);
      await expectLater(
        svc.createSkill(
          name: 'Run',
          reward: 50,
          goal: 20,
          startDate: _now,
          expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create skill'),
        )),
      );
    });

    test('addSkillFromSuggestion() throws wrapped message when user is null',
        () async {
      // _uid is called at _db.ref('userActivities/$_uid').push()
      final svc =
          FirebaseSkillService(db: FakeDb(), auth: FakeAuth()..user = null);
      await expectLater(
        svc.addSkillFromSuggestion(
          activityId: 'act1',
          goal: 10,
          startDate: _now,
          expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to add skill from suggestion'),
        )),
      );
    });
  });

  // ── createSkill() – success & Firebase paths ──────────────────────────────

  group('FirebaseSkillService – createSkill()', () {
    setUp(_mockOnline);

    /// Builds a pre-configured FakeDb ready for createSkill().
    ///
    ///  - 'activities'         push key → [actPushKey]
    ///  - 'userActivities/uid1' push key → [uaPushKey]
    ///  - root ref             captures atomic update
    FakeDb _makeDb({
      String actPushKey = 'act-id',
      String uaPushKey = 'ua-id',
    }) {
      final db = FakeDb();
      db.refFor('activities').setPushKey(actPushKey);
      db.refFor('userActivities/uid1').setPushKey(uaPushKey);
      db.rootRef; // pre-register root so capturedUpdate is accessible
      return db;
    }

    FirebaseSkillService _makeSvc(FakeDb db) => FirebaseSkillService(
          db: db,
          auth: FakeAuth()..user = FakeUser('uid1'),
        );

    test('pushes to the activities path', () async {
      final db = _makeDb();
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      expect(db.calledPaths, contains('activities'));
    });

    test('pushes to the uid-scoped userActivities path', () async {
      final db = _makeDb();
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      expect(db.calledPaths, contains('userActivities/uid1'));
    });

    test('calls atomic update on root ref', () async {
      final db = _makeDb();
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      expect(db.rootRef.capturedUpdate, isNotNull);
    });

    test('atomic update contains activities/<activityId> key', () async {
      final db = _makeDb(actPushKey: 'act-abc');
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      expect(db.rootRef.capturedUpdate!.keys, contains('activities/act-abc'));
    });

    test('atomic update contains userActivities/<uid>/<userActivityId> key',
        () async {
      final db = _makeDb(actPushKey: 'act-abc', uaPushKey: 'ua-xyz');
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      expect(
        db.rootRef.capturedUpdate!.keys,
        contains('userActivities/uid1/ua-xyz'),
      );
    });

    test('activity payload contains name and reward', () async {
      final db = _makeDb(actPushKey: 'act-abc');
      await _makeSvc(db).createSkill(
        name: 'Morning Run',
        reward: 75,
        goal: 20,
        startDate: _now,
        expireDate: _future,
      );
      final actPayload =
          db.rootRef.capturedUpdate!['activities/act-abc'] as Map;
      expect(actPayload['name'], 'Morning Run');
      expect(actPayload['reward'], 75);
    });

    test('activity payload id matches pushed key', () async {
      final db = _makeDb(actPushKey: 'act-abc');
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      final actPayload =
          db.rootRef.capturedUpdate!['activities/act-abc'] as Map;
      expect(actPayload['id'], 'act-abc');
    });

    test('userActivity payload contains correct fields', () async {
      final db = _makeDb(actPushKey: 'act-abc', uaPushKey: 'ua-xyz');
      await _makeSvc(db).createSkill(
        name: 'Run',
        reward: 50,
        goal: 20,
        startDate: _now,
        expireDate: _future,
      );
      final uaPayload =
          db.rootRef.capturedUpdate!['userActivities/uid1/ua-xyz'] as Map;
      expect(uaPayload['activityId'], 'act-abc');
      expect(uaPayload['goal'], 20);
      expect(uaPayload['startDate'], _now);
      expect(uaPayload['expireDate'], _future);
      expect(uaPayload['count'], 0);
    });

    test('userActivity payload id matches pushed key', () async {
      final db = _makeDb(uaPushKey: 'ua-xyz');
      await _makeSvc(db).createSkill(
        name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
      );
      final uaPayload =
          db.rootRef.capturedUpdate!['userActivities/uid1/ua-xyz'] as Map;
      expect(uaPayload['id'], 'ua-xyz');
    });

    test('completes without error given valid inputs', () async {
      final db = _makeDb();
      await expectLater(
        _makeSvc(db).createSkill(
          name: 'Run',
          reward: 50,
          goal: 20,
          startDate: _now,
          expireDate: _future,
        ),
        completes,
      );
    });

    test('throws wrapped message when activities push() fails', () async {
      final db = FakeDb();
      db.refFor('activities')
          .setThrowOnPush(Exception('Permission denied'));

      final svc = FirebaseSkillService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.createSkill(
          name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create skill'),
        )),
      );
    });

    test('throws wrapped message when root update() fails', () async {
      final db = FakeDb();
      db.refFor('activities').setPushKey('act-id');
      db.refFor('userActivities/uid1').setPushKey('ua-id');
      db.rootRef.setThrowOnUpdate(Exception('Write conflict'));

      final svc = FirebaseSkillService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.createSkill(
          name: 'Run', reward: 50, goal: 20, startDate: _now, expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to create skill'),
        )),
      );
    });
  });

  // ── addSkillFromSuggestion() – success & Firebase paths ───────────────────

  group('FirebaseSkillService – addSkillFromSuggestion()', () {
    setUp(_mockOnline);

    /// Builds a pre-configured FakeDb ready for addSkillFromSuggestion().
    FakeDb _makeDb({String uaPushKey = 'ua-id'}) {
      final db = FakeDb();
      db.refFor('userActivities/uid1').setPushKey(uaPushKey);
      return db;
    }

    FirebaseSkillService _makeSvc(FakeDb db) => FirebaseSkillService(
          db: db,
          auth: FakeAuth()..user = FakeUser('uid1'),
        );

    test('pushes to the uid-scoped userActivities path', () async {
      final db = _makeDb();
      await _makeSvc(db).addSkillFromSuggestion(
        activityId: 'act1', goal: 10, startDate: _now, expireDate: _future,
      );
      expect(db.calledPaths, contains('userActivities/uid1'));
    });

    test('calls set() on the pushed ref — not directly on a named path',
        () async {
      final db = _makeDb(uaPushKey: 'ua-abc');
      await _makeSvc(db).addSkillFromSuggestion(
        activityId: 'act1', goal: 10, startDate: _now, expireDate: _future,
      );
      // set() is called on pushedRef, not on a named db path
      expect(
        db.refFor('userActivities/uid1').pushedRef!.capturedSet,
        isNotNull,
      );
    });

    test('set payload contains activityId', () async {
      final db = _makeDb();
      await _makeSvc(db).addSkillFromSuggestion(
        activityId: 'existing-act',
        goal: 10,
        startDate: _now,
        expireDate: _future,
      );
      final payload =
          db.refFor('userActivities/uid1').pushedRef!.capturedSet as Map;
      expect(payload['activityId'], 'existing-act');
    });

    test('set payload contains all required UserActivity fields', () async {
      final db = _makeDb(uaPushKey: 'ua-abc');
      await _makeSvc(db).addSkillFromSuggestion(
        activityId: 'existing-act',
        goal: 15,
        startDate: _now,
        expireDate: _future,
      );
      final payload =
          db.refFor('userActivities/uid1').pushedRef!.capturedSet as Map;
      expect(payload['id'], 'ua-abc');
      expect(payload['activityId'], 'existing-act');
      expect(payload['goal'], 15);
      expect(payload['startDate'], _now);
      expect(payload['expireDate'], _future);
      expect(payload['count'], 0); // always starts at 0
    });

    test('count is always initialised to 0', () async {
      final db = _makeDb();
      await _makeSvc(db).addSkillFromSuggestion(
        activityId: 'act1', goal: 5, startDate: _now, expireDate: _future,
      );
      final payload =
          db.refFor('userActivities/uid1').pushedRef!.capturedSet as Map;
      expect(payload['count'], 0);
    });

    test('completes without error given valid inputs', () async {
      final db = _makeDb();
      await expectLater(
        _makeSvc(db).addSkillFromSuggestion(
          activityId: 'act1', goal: 10, startDate: _now, expireDate: _future,
        ),
        completes,
      );
    });

    test('throws wrapped message when push() fails', () async {
      final db = FakeDb();
      db.refFor('userActivities/uid1')
          .setThrowOnPush(Exception('Permission denied'));

      final svc = FirebaseSkillService(
        db: db,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.addSkillFromSuggestion(
          activityId: 'act1', goal: 10, startDate: _now, expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to add skill from suggestion'),
        )),
      );
    });

    test('throws wrapped message when set() on pushed ref fails', () async {
      final db = _makeDb();
      // set() is called on pushedRef, so we configure the ref returned by push()
      // by intercepting after push — easier: make push() return a throwing ref
      final throwingRef = FakeDatabaseRef()
        ..setThrowOnSet(Exception('Write error'));
      // Replace push() to return our throwing ref
      db.refFor('userActivities/uid1').pushedRef = throwingRef;

      // We need a custom ref that returns our throwingRef from push().
      // Simplest: use a dedicated FakeDb with a custom ref.
      final customDb = _FakeDbWithCustomPushedRef(throwingRef);
      final svc = FirebaseSkillService(
        db: customDb,
        auth: FakeAuth()..user = FakeUser('uid1'),
      );
      await expectLater(
        svc.addSkillFromSuggestion(
          activityId: 'act1', goal: 10, startDate: _now, expireDate: _future,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to add skill from suggestion'),
        )),
      );
    });
  });
}

// ── Helper: FakeDb that always returns a specific ref for push() ──────────

/// A specialised FakeDb where every ref() call returns a ref whose push()
/// yields [_pushedRef]. Used to simulate set() failures on the pushed ref.
class _FakeDbWithCustomPushedRef extends Fake implements FirebaseDatabase {
  final FakeDatabaseRef _pushedRef;
  _FakeDbWithCustomPushedRef(this._pushedRef);

  @override
  DatabaseReference ref([String? path]) => _FakeRefWithFixedPush(_pushedRef);
}

class _FakeRefWithFixedPush extends Fake implements DatabaseReference {
  final FakeDatabaseRef _pushedRef;
  _FakeRefWithFixedPush(this._pushedRef);

  @override
  DatabaseReference push() => _pushedRef;

  @override
  String? get key => 'ua-fixed';
}

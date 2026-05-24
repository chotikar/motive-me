// Unit tests for DatabaseService using package:test + mocktail.
//
// DatabaseService.forTesting() injects all dependencies so every execution
// branch can be driven without hitting a real platform channel or Firebase.
//
// Branches covered (7 / 7 → 100 % line coverage):
//   1. localUser == null                            → returns null
//   2. localUser found, currentUser == null         → returns null
//   3. localUser found, currentUser found, offline  → returns localUser
//   4. online, snapshot exists                      → returns updatedUser + saves to local
//   5. online, snapshot does NOT exist              → returns localUser (no save)
//   6. online, Firebase ref.get() throws            → inner-catch returns localUser
//   7. getUserInfo() throws                         → outer-catch throws Exception('Failed …')

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart' show setupFirebaseCoreMocks;
import 'package:firebase_database/firebase_database.dart';
import 'package:motive_me/Local/user_local.dart';
import 'package:motive_me/Models/user_model.dart';
import 'package:motive_me/Services/database_service.dart';

// ── Mock classes ──────────────────────────────────────────────────────────────

class MockUserLocal extends Mock implements UserLocal {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

// ── Fixture helpers ───────────────────────────────────────────────────────────

const _uid = 'user-123';

/// Minimal cached user that UserLocal would return.
final _cachedUser = UserModel(
  uid: _uid,
  name: 'Alice',
  email: 'alice@test.com',
  createdAt: 1000,
  updatedAt: 2000,
);

/// Firebase snapshot payload — simulates a fresher record from the DB.
const _firebasePayload = <String, dynamic>{
  'name': 'Alice Updated',
  'email': 'alice@test.com',
  'photoUrl': null,
  'bio': 'Flutter dev',
  'createdAt': 1000,
  'updatedAt': 9999,
};

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUserLocal mockUserLocal;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseDatabase mockDb;
  late MockDatabaseReference mockRef;
  late MockDataSnapshot mockSnapshot;

  // Register fallback values for custom types used in any() matchers.
  setUpAll(() {
    registerFallbackValue(
      UserModel(uid: '', name: '', email: '', createdAt: 0, updatedAt: 0),
    );
  });

  setUp(() {
    mockUserLocal = MockUserLocal();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockDb = MockFirebaseDatabase();
    mockRef = MockDatabaseReference();
    mockSnapshot = MockDataSnapshot();

    // Common stubs shared across most tests.
    when(() => mockUser.uid).thenReturn(_uid);
    when(() => mockDb.ref(any())).thenReturn(mockRef);
  });

  // ── Helper: build service with optional overrides ─────────────────────────

  DatabaseService _makeService({Future<bool> Function()? isConnected}) =>
      DatabaseService.forTesting(
        db: mockDb,
        userLocal: mockUserLocal,
        auth: mockAuth,
        isConnected: isConnected,
      );

  // ── Group 1: no local user ────────────────────────────────────────────────

  group('initializeUserOnAppStart – no local user', () {
    test(
        'returns null immediately and does not check Firebase '
        'when getUserInfo() returns null', () async {
      when(() => mockUserLocal.getUserInfo()).thenAnswer((_) async => null);

      final result = await _makeService().initializeUserOnAppStart();

      expect(result, isNull);
      // Short-circuit: currentUser must never be accessed
      verifyNever(() => mockAuth.currentUser);
      verifyNever(() => mockDb.ref(any()));
    });
  });

  // ── Group 2: local user exists, Firebase session expired ──────────────────

  group('initializeUserOnAppStart – Firebase not authenticated', () {
    setUp(() {
      when(() => mockUserLocal.getUserInfo()).thenAnswer((_) async => _cachedUser);
      when(() => mockAuth.currentUser).thenReturn(null);
    });

    test('returns null when FirebaseAuth.currentUser is null', () async {
      final result = await _makeService().initializeUserOnAppStart();

      expect(result, isNull);
    });

    test('does not query the database when currentUser is null', () async {
      await _makeService().initializeUserOnAppStart();

      verifyNever(() => mockDb.ref(any()));
    });
  });

  // ── Group 3: offline ──────────────────────────────────────────────────────

  group('initializeUserOnAppStart – device is offline', () {
    setUp(() {
      when(() => mockUserLocal.getUserInfo()).thenAnswer((_) async => _cachedUser);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
    });

    test('returns the cached local user without querying Firebase', () async {
      final result = await _makeService(
        isConnected: () async => false,
      ).initializeUserOnAppStart();

      expect(result, _cachedUser);
      verifyNever(() => mockDb.ref(any()));
    });

    test('does not attempt to save anything to local storage', () async {
      await _makeService(
        isConnected: () async => false,
      ).initializeUserOnAppStart();

      verifyNever(() => mockUserLocal.saveUser(any()));
    });
  });

  // ── Group 4: online — snapshot exists ────────────────────────────────────

  group('initializeUserOnAppStart – online, snapshot exists', () {
    setUp(() {
      when(() => mockUserLocal.getUserInfo()).thenAnswer((_) async => _cachedUser);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.value).thenReturn(_firebasePayload);
      when(() => mockRef.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockUserLocal.saveUser(any())).thenAnswer((_) async {});
    });

    test('queries the correct Firebase path (users/<uid>)', () async {
      await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      verify(() => mockDb.ref('users/$_uid')).called(1);
    });

    test('returns an updated UserModel built from the Firebase snapshot', () async {
      final result = await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      expect(result, isNotNull);
      expect(result!.uid, _uid);
      expect(result.name, 'Alice Updated');
      expect(result.bio, 'Flutter dev');
      expect(result.updatedAt, 9999);
    });

    test('persists the updated user to local storage exactly once', () async {
      await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      final captured = verify(() => mockUserLocal.saveUser(captureAny())).captured;
      expect(captured.length, 1);
      final saved = captured.first as UserModel;
      expect(saved.name, 'Alice Updated');
    });

    test('does not return the stale cached user', () async {
      final result = await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      expect(result!.updatedAt, isNot(_cachedUser.updatedAt));
    });
  });

  // ── Group 5: online — snapshot does not exist ─────────────────────────────

  group('initializeUserOnAppStart – online, snapshot missing', () {
    setUp(() {
      when(() => mockUserLocal.getUserInfo()).thenAnswer((_) async => _cachedUser);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockSnapshot.exists).thenReturn(false);
      when(() => mockRef.get()).thenAnswer((_) async => mockSnapshot);
    });

    test('returns the cached local user when the Firebase node does not exist',
        () async {
      final result = await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      expect(result, _cachedUser);
    });

    test('does not call saveUser when snapshot is missing', () async {
      await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      verifyNever(() => mockUserLocal.saveUser(any()));
    });
  });

  // ── Group 6: online — Firebase ref.get() throws ───────────────────────────

  group('initializeUserOnAppStart – Firebase query throws', () {
    setUp(() {
      when(() => mockUserLocal.getUserInfo()).thenAnswer((_) async => _cachedUser);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
    });

    test('falls back to the cached local user when ref.get() throws', () async {
      when(() => mockRef.get()).thenThrow(Exception('Network timeout'));

      final result = await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      expect(result, _cachedUser);
    });

    test('does not rethrow the inner Firebase exception', () async {
      when(() => mockRef.get()).thenThrow(Exception('Permission denied'));

      await expectLater(
        _makeService(isConnected: () async => true).initializeUserOnAppStart(),
        completion(isNotNull), // resolves normally — no throw
      );
    });

    test('does not save anything to local storage on Firebase error', () async {
      when(() => mockRef.get()).thenThrow(Exception('DB error'));

      await _makeService(
        isConnected: () async => true,
      ).initializeUserOnAppStart();

      verifyNever(() => mockUserLocal.saveUser(any()));
    });
  });

  // ── Group 7: getUserInfo() throws → outer catch ───────────────────────────

  group('initializeUserOnAppStart – local storage failure', () {
    test('throws an Exception wrapping "Failed to initialize user" message',
        () async {
      when(() => mockUserLocal.getUserInfo())
          .thenThrow(Exception('SharedPreferences unavailable'));

      await expectLater(
        _makeService().initializeUserOnAppStart(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to initialize user'),
          ),
        ),
      );
    });

    test('wraps the original cause inside the thrown exception message',
        () async {
      when(() => mockUserLocal.getUserInfo())
          .thenThrow(Exception('disk full'));

      await expectLater(
        _makeService().initializeUserOnAppStart(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('disk full'),
          ),
        ),
      );
    });
  });

  // ── Group 8: Production singleton constructor ─────────────────────────────
  //
  // DatabaseService._internal() initialises Firebase singletons at construction
  // time. setupFirebaseCoreMocks() installs the Pigeon-level Firebase stubs so
  // FirebaseDatabase.instance and FirebaseAuth.instance succeed without a real
  // app — letting us cover the factory + _internal() lines.

  group('DatabaseService() – production singleton', () {
    setUpAll(() async {
      setupFirebaseCoreMocks();
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    });

    test('DatabaseService() factory returns the same singleton instance', () {
      final a = DatabaseService();
      final b = DatabaseService();
      expect(identical(a, b), isTrue);
    });

    test('singleton instance is a DatabaseService', () {
      expect(DatabaseService(), isA<DatabaseService>());
    });
  });
}

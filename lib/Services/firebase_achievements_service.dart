import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/achievement_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'network_service.dart';

class FirebaseAchievementsService {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  FirebaseAchievementsService({
    FirebaseDatabase? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> unlockAchievement(String achievementId) async {
    try {
      await NetworkService.checkOrThrow();
      await _db.ref('achievements/$achievementId').update({
        'isUnlocked': true,
        'unlockedAt': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception('Failed to unlock achievement: $e');
    }
  }

  Future<void> saveAchievement(Achievement achievement) async {
    try {
      await NetworkService.checkOrThrow();
      await _db
          .ref('userAchievements/$_uid/${achievement.id}')
          .set(achievement.toMap());
    } catch (e) {
      throw Exception('Failed to save achievement: $e');
    }
  }

  Future<List<Achievement>> getUserAchievements() async {
    try {
      await NetworkService.checkOrThrow();
      final snapshot = await _db.ref('userAchievements/$_uid').get();
      if (!snapshot.exists) return [];

      final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final achievements = map.entries.map((e) {
        return Achievement.fromMap(
          e.key.toString(),
          Map<dynamic, dynamic>.from(e.value as Map),
        );
      }).toList();

      // Sort newest first
      achievements.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
      return achievements;
    } catch (e) {
      throw Exception('Failed to get achievements: $e');
    }
  }

  /// Count achievements for current user
  Future<int> getAchievementCount() async {
    try {
      await NetworkService.checkOrThrow();
      final snapshot = await _db.ref('userAchievements/$_uid').get();
      if (!snapshot.exists) return 0;
      return (snapshot.value as Map).length;
    } catch (_) {
      return 0;
    }
  }
}

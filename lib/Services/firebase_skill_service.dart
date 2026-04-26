import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/activity_model.dart';
import '../Models/user_activity_model.dart';
import 'network_service.dart';

class FirebaseSkillService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> createSkill({
    required String name,
    required int reward,
    required int goal,
    required int startDate,
    required int expireDate,
  }) async {
    try {
      await NetworkService.checkOrThrow();
      final activityRef = _db.ref('activities').push();
      final activityId = activityRef.key!;
      final activity = Activity(id: activityId, name: name, reward: reward);

      // 2. Push new UserActivity
      final userActivityRef = _db.ref('userActivities/$_uid').push();
      final userActivityId = userActivityRef.key!;
      final userActivity = UserActivity(
        id: userActivityId,
        activityId: activityId,
        startDate: startDate,
        expireDate: expireDate,
        goal: goal,
        count: 0,
      );

      // 3. Atomic write
      await _db.ref().update({
        'activities/$activityId': activity.toMap(),
        'userActivities/$_uid/$userActivityId': userActivity.toMap(),
      });
    } catch (e) {
      throw Exception('Failed to create skill: $e');
    }
  }

  /// Suggestion flow: reuses existing Activity, only creates UserActivity
  Future<void> addSkillFromSuggestion({
    required String activityId,
    required int goal,
    required int startDate,
    required int expireDate,
  }) async {
    try {
      await NetworkService.checkOrThrow();
      final ref = _db.ref('userActivities/$_uid').push();
      final userActivityId = ref.key!;
      final userActivity = UserActivity(
        id: userActivityId,
        activityId: activityId,
        startDate: startDate,
        expireDate: expireDate,
        goal: goal,
        count: 0,
      );
      await ref.set(userActivity.toMap());
    } catch (e) {
      throw Exception('Failed to add skill from suggestion: $e');
    }
  }
}

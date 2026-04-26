import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/activity_model.dart';
import '../Models/user_activity_model.dart';
import 'network_service.dart';

class FirebaseActivityService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<String> createActivity(Activity activity) async {
    await NetworkService.checkOrThrow();
    final ref = _db.ref('activities').push();
    final id = ref.key!;
    final newActivity = Activity(id: id, name: activity.name, reward: activity.reward);
    await ref.set(newActivity.toMap()); // toMap() now includes 'id'
    return id;
  }

  Stream<List<Activity>> getUserActivities() {
    return _db.ref('userActivities/$_uid').onValue.asyncMap((event) async {
      try {
        if (event.snapshot.value == null) return <Activity>[];

        final ids = Map<String, dynamic>.from(
          event.snapshot.value as Map,
        ).keys.toList();

        final activities = <Activity>[];
        for (final id in ids) {
          final snap = await _db.ref('activities/$id').get();
          if (snap.exists) {
            activities.add(Activity.fromMap(
                id,
                Map<dynamic, dynamic>.from(snap.value as Map),
            ));
          }
        }
        return activities;
      } catch (e) {
        throw Exception('Failed to get user activities: $e');
      }
    });
  }

  Future<Activity?> getActivityById(String activityId) async {
    try {
      final snapshot = await _db.ref('activities/$activityId').get();
      if (snapshot.exists) {
        return Activity.fromMap(
          activityId,
          Map<dynamic, dynamic>.from(snapshot.value as Map),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get activity: $e');
    }
  }

  /// Fetch all activities for suggestion
  Future<List<Activity>> getAllActivities() async {
    try {
    await NetworkService.checkOrThrow();
      final snapshot = await _db.ref('activities').get();
      if (!snapshot.exists) return [];
      final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return map.entries.map((e) {
        return Activity.fromMap(
          e.key.toString(),
          Map<dynamic, dynamic>.from(e.value as Map),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch activities: $e');
    }
  }

  Future<void> updateActivity(Activity activity) async {
    try {
      await NetworkService.checkOrThrow();
      await _db.ref('activities/${activity.id}').update(activity.toMap());
    } catch (e) {
      throw Exception('Failed to update activity: $e');
    }
  }
  
  Future<void> deleteActivity({
    required String activityId,
    required String userActivityId,
  }) async {
    try {
      await NetworkService.checkOrThrow();
      final uid = _uid; // throws early if not authenticated

      // Use remove() on each ref directly instead of a root-level multi-path
      // update({path: null}). On Flutter Web the JS SDK evaluates .validate
      // rules even for null-value writes in multi-path updates, which causes
      // PERMISSION_DENIED when the activity node has a hasChildren() validator.
      // remove() is the canonical deletion API and skips .validate correctly.
      await _db.ref('userActivities/$uid/$userActivityId').remove();
      await _db.ref('activities/$activityId').remove();
    } catch (e) {
      throw Exception('Failed to delete activity: $e');
    }
  }

  Future<void> checkIn(String userActivityId, UserActivity current) async {
    await NetworkService.checkOrThrow();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < current.startDate) {
      throw Exception('Activity has not started yet');
    }
    if (current.isExpired) {
      throw Exception('This skill has expired');
    }
    if (current.isCompleted) {
      throw Exception('This skill is already completed');
    }
    if (current.hasCheckedInToday) {
      throw Exception('Already checked in today');
    }

    // Append timestamp to checkInDates list using next numeric index
    final nextIndex = current.checkInDates.length.toString();

    await _db.ref('userActivities/$_uid/$userActivityId').update({
      'count': current.count + 1,
      'checkInDates/$nextIndex': now,
    });
  }

  Stream<List<UserActivity>> streamUserActivities() {
    return _db.ref('userActivities/$_uid').onValue.map((event) {
      if (event.snapshot.value == null) return <UserActivity>[];
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return map.entries.map((e) {
        return UserActivity.fromMap(
          e.key.toString(),
          Map<dynamic, dynamic>.from(e.value as Map)
        );
      }).toList();
    });
  }
}
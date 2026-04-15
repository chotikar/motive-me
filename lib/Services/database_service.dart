import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motive_me/Models/user_model.dart';
import '../Models/activity_model.dart';
import '../Models/achievement_model.dart';
import '../Models/user_activity_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  // ========== USER ==========
  Future<void> saveUserToLocalStorage(UserModel userModel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', userModel.uid);
      await prefs.setString('user_name', userModel.name);
      await prefs.setString('user_email', userModel.email);
      await prefs.setString('user_photo_url', userModel.photoUrl ?? '');
      await prefs.setString('user_bio', userModel.bio ?? '');
      await prefs.setInt('user_created_at', userModel.createdAt);
      await prefs.setInt('user_updated_at', userModel.updatedAt);
    } catch (e) {
      throw Exception('Failed to save user to local storage: $e');
    }
  }

  Future<void> _saveUserToLocalStorage(UserModel userModel) async {
    await saveUserToLocalStorage(userModel);
  }

  Future<UserModel?> getUserFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_uid');
      final name = prefs.getString('user_name');
      final email = prefs.getString('user_email');
      
      if (uid == null || name == null || email == null) return null;

      return UserModel(
        uid: uid,
        name: name,
        email: email,
        photoUrl: prefs.getString('user_photo_url'),
        bio: prefs.getString('user_bio'),
        createdAt: prefs.getInt('user_created_at') ?? 0,
        updatedAt: prefs.getInt('user_updated_at') ?? 0,
      );
    } catch (e) {
      throw Exception('Failed to get user from local storage: $e');
    }
  }

  /// Initialize user on app start:
  /// 1. Check if user info is in local storage
  /// 2. If yes, fetch current info from Firebase to update local storage
  /// 3. If no, return null (user needs to log in)
  Future<UserModel?> initializeUserOnAppStart() async {
    try {
      // Check if there's a user in local storage
      final localUser = await getUserFromLocalStorage();
      
      if (localUser == null) {
        return null; // No user, redirect to login
      }

      // Check if user is authenticated with Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return null; // Not authenticated, redirect to login
      }

      // Fetch current user info from Firebase to update local storage
      try {
        final snapshot = await _db.ref('users/${currentUser.uid}').get();
        if (snapshot.exists) {
          final updatedUser = UserModel.fromMap(
            currentUser.uid,
            Map<dynamic, dynamic>.from(snapshot.value as Map),
          );
          // Update local storage with latest info
          await _saveUserToLocalStorage(updatedUser);
          return updatedUser;
        }
      } catch (e) {
        // Firebase fetch failed, return local user
        return localUser;
      }

      return localUser;
    } catch (e) {
      throw Exception('Failed to initialize user: $e');
    }
  }

  Future<void> clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_photo_url');
      await prefs.remove('user_bio');
      await prefs.remove('user_created_at');
      await prefs.remove('user_updated_at');
    } catch (e) {
      throw Exception('Failed to clear local storage: $e');
    }
  }

  Future<void> createUserProfile(UserModel userModel) async {
    try {
      await _db.ref('users/$_uid').set({
        'name': userModel.name,
        'email': userModel.email,
        'photoUrl': userModel.photoUrl,
        'bio': userModel.bio,
        'createdAt': ServerValue.timestamp,
      });
      // Save to local storage
      await _saveUserToLocalStorage(userModel);
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final snapshot = await _db.ref('users/$_uid').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Helper method to convert Firebase profile Map to UserModel
  UserModel mapToUserModel(String uid, Map<String, dynamic> map) {
    return UserModel.fromMap(uid, map);
  }

  /// Update user profile in Firebase and sync to local storage
  Future<UserModel> updateUserProfile({
    String? name,
    String? photo,
    String? bio,
  }) async {
    try {
      // Get current user data
      final currentUser = await getUserFromLocalStorage();
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Create updated user model
      final updatedUser = currentUser.copyWith(
        name: name,
        photoUrl: photo,
        bio: bio,
      );

      // Update in Firebase
      await _db.ref('users/$_uid').update({
        'name': updatedUser.name,
        'photoUrl': updatedUser.photoUrl,
        'bio': updatedUser.bio,
        'updatedAt': ServerValue.timestamp,
      });

      // Fetch updated data from Firebase to sync
      final snapshot = await _db.ref('users/$_uid').get();
      if (snapshot.exists) {
        final updatedUserFromDb = UserModel.fromMap(
          _uid,
          Map<dynamic, dynamic>.from(snapshot.value as Map),
        );
        // Save to local storage
        await _saveUserToLocalStorage(updatedUserFromDb);
        return updatedUserFromDb;
      }

      return updatedUser;
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // ========== ACTIVITY ==========
Future<String> createActivity(Activity activity) async {
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

  Future<void> updateActivity(Activity activity) async {
    try {
      await _db.ref('activities/${activity.id}').update(activity.toMap());
    } catch (e) {
      throw Exception('Failed to update activity: $e');
    }
  }

  Future<void> deleteActivity(String activityId) async {
    try {
      await _db.ref().update({
        'activities/$activityId': null,
        'userActivities/$_uid/$activityId': null,
        'checkIns/$activityId': null,
      });
    } catch (e) {
      throw Exception('Failed to delete activity: $e');
    }
  }

  // ========== ACTIVITY ==========

/// Fetch all activities for suggestion chips
Future<List<Activity>> getAllActivities() async {
  try {
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

/// Custom flow: creates a brand-new Activity + UserActivity atomically
Future<void> createSkill({
  required String name,
  required int reward,
  required int goal,
  required int startDate,
  required int expireDate,
}) async {
  try {
    // 1. Push new Activity
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

  // ========== ACHIEVEMENTS ==========
  Future<void> unlockAchievement(String achievementId) async {
    try {
      await _db.ref('achievements/$achievementId').update({
        'isUnlocked': true,
        'unlockedAt': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception('Failed to unlock achievement: $e');
    }
  }
// Rules: count can only +1, only before expireDate
// checkInDates value must be >= startDate, < expireDate, <= now
Future<void> checkIn(String userActivityId, UserActivity current) async {
  if (!current.canCheckIn) throw Exception('Cannot check in: expired or completed');

  final now = DateTime.now().millisecondsSinceEpoch;
  final nextIndex = current.checkInDates.length.toString();

  await _db.ref('userActivities/$_uid/$userActivityId').update({
    'count': current.count + 1,                    // +1 only
    'checkInDates/$nextIndex': now,                // timestamp in valid range
  });
}
// ========== USER ACTIVITIES (new rules) ==========

/// Real-time stream of current user's UserActivities
Stream<List<UserActivity>> streamUserActivities() {
  return _db.ref('userActivities/$_uid').onValue.map((event) {
    if (event.snapshot.value == null) return <UserActivity>[];
    final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    return map.entries.map((e) {
      return UserActivity.fromMap(
        e.key.toString(),
        Map<dynamic, dynamic>.from(e.value as Map),
      );
    }).toList();
  });
}

// /// Check in: count +1, record timestamp in checkInDates
// /// Firebase rules enforce: count can only +1, only before expireDate
// Future<void> checkIn(String userActivityId, UserActivity current) async {
//   if (current.isExpired) throw Exception('This skill has expired');
//   if (current.isCompleted) throw Exception('This skill is already completed');
//   //if (current.hasCheckedInToday) throw Exception('Already checked in today');

//   final now = DateTime.now().millisecondsSinceEpoch;
//   final nextIndex = current.count.toString(); // 0, 1, 2 ...

//   await _db.ref('userActivities/$_uid/$userActivityId').update({
//     'count': current.count + 1,
//     'checkInDates/$nextIndex': now,
//   });
// }
// ========== ACHIEVEMENTS ==========

/// Save (or overwrite) an achievement under userAchievements/$uid/
Future<void> saveAchievement(Achievement achievement) async {
  try {
    await _db
        .ref('userAchievements/$_uid/${achievement.id}')
        .set(achievement.toMap());
  } catch (e) {
    throw Exception('Failed to save achievement: $e');
  }
}

/// Fetch all unlocked achievements for current user
Future<List<Achievement>> getUserAchievements() async {
  try {
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
    final snapshot = await _db.ref('userAchievements/$_uid').get();
    if (!snapshot.exists) return 0;
    return (snapshot.value as Map).length;
  } catch (_) {
    return 0;
  }
}

// ========== ACHIEVEMENTS (local only) ==========

/// Get all unlocked achievement IDs from local storage
Future<Set<String>> getUnlockedAchievementIds() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('unlocked_achievements') ?? '';
  if (raw.isEmpty) return {};
  return raw.split(',').toSet();
}

/// Save a newly unlocked achievement ID to local storage
Future<void> saveUnlockedAchievementId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await getUnlockedAchievementIds();
  current.add(id);
  await prefs.setString('unlocked_achievements', current.join(','));
}
}
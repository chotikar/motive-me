import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/activity_model.dart';
import '../Models/user_activity_model.dart';

class SkillEntriesLocal {
  static const _key = 'cached_skill_entries';

  /// Save the current skill entries to local storage.
  Future<void> save(
    List<({UserActivity userActivity, Activity activity})> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final list = entries
        .map(
          (e) => {
            'userActivity': e.userActivity.toMap(),
            'activity': e.activity.toMap(),
          },
        )
        .toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Load the last cached skill entries. Returns empty list if nothing saved.
  Future<List<({UserActivity userActivity, Activity activity})>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List;
    return list.map((item) {
      final uaMap = Map<dynamic, dynamic>.from(item['userActivity'] as Map);
      final actMap = Map<dynamic, dynamic>.from(item['activity'] as Map);
      return (
        userActivity: UserActivity.fromMap(uaMap['id'] as String, uaMap),
        activity: Activity.fromMap(actMap['id'] as String, actMap),
      );
    }).toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

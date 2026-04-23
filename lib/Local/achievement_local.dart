import 'package:shared_preferences/shared_preferences.dart';

class AchievementLocal {
  
  Future<Set<String>> getUnlockedAchievementIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('unlocked_achievements') ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').toSet();
  }
    
  Future<void> saveUnlockedAchievementId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getUnlockedAchievementIds();
    current.add(id);
    await prefs.setString('unlocked_achievements', current.join(','));
  }

  Future<void> clearUnlockedAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('unlocked_achievements');
    } catch (e) {
      throw Exception('Failed to clear local storage: $e');
    }
  }
}
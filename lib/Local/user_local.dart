import 'package:shared_preferences/shared_preferences.dart';
import '../Models/user_model.dart';

class UserLocal {

  Future<void> saveUser(UserModel userModel) async {
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

  Future<void> _saveUser(UserModel userModel) async {
    await saveUser(userModel);
  }

  Future<UserModel?> getUserInfo() async {
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

  Future<void> clearUserInfo() async {
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
}
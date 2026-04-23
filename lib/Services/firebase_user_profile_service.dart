import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/user_model.dart';
import '../Local/user_local.dart';
import 'network_service.dart';

class FirebaseUserProfileService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final UserLocal _userLocal = UserLocal();

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> createUserProfile(UserModel userModel) async {
    try {
      await NetworkService.checkOrThrow();
      await _db.ref('users/$_uid').set({
        'name': userModel.name,
        'email': userModel.email,
        'photoUrl': userModel.photoUrl,
        'bio': userModel.bio,
        'createdAt': ServerValue.timestamp,
      });
      // Save to local storage
      await _userLocal.saveUser(userModel);
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      await NetworkService.checkOrThrow();
      final snapshot = await _db.ref('users/$_uid').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  UserModel mapToUserModel(String uid, Map<String, dynamic> map) {
    return UserModel.fromMap(uid, map);
  }

  Future<UserModel> updateUserProfile({
    String? name,
    String? photo,
    String? bio,
  }) async {
    try {
      await NetworkService.checkOrThrow();
      final currentUser = await _userLocal.getUserInfo();
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
        await _userLocal.saveUser(updatedUserFromDb);
        return updatedUserFromDb;
      }

      return updatedUser;
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

}
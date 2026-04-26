import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:motive_me/Models/user_model.dart';
import '../Local/user_local.dart';
import 'network_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final UserLocal _userLocal = UserLocal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<UserModel?> initializeUserOnAppStart() async {
    try {
      // Check if there's a user in local storage
      final localUser = await _userLocal.getUserInfo();

      if (localUser == null) {
        return null; // No user, redirect to login
      }

      // Check if user is authenticated with Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return null; // Not authenticated, redirect to login
      }

      final connected = await NetworkService.isConnected();
      if (!connected) return localUser;

      try {
        final snapshot = await _db.ref('users/${currentUser.uid}').get();
        if (snapshot.exists) {
          final updatedUser = UserModel.fromMap(
            currentUser.uid,
            Map<dynamic, dynamic>.from(snapshot.value as Map),
          );
          // Update local storage with latest info
          await _userLocal.saveUser(updatedUser);
          return updatedUser;
        }
      } catch (e) {
        return localUser;
      }
      return localUser;
    } catch (e) {
      throw Exception('Failed to initialize user: $e');
    }
  }
}

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:motive_me/Models/user_model.dart';
import '../Local/user_local.dart';
import 'network_service.dart';

class DatabaseService {
  final FirebaseDatabase _db;
  final UserLocal _userLocal;
  final FirebaseAuth _auth;
  final Future<bool> Function() _isConnected;

  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal()
      : _db = FirebaseDatabase.instance,
        _userLocal = UserLocal(),
        _auth = FirebaseAuth.instance,
        _isConnected = NetworkService.isConnected;

  DatabaseService.forTesting({
    required FirebaseDatabase db,
    required UserLocal userLocal,
    required FirebaseAuth auth,
    required Future<bool> Function()? isConnected,
  })  : _db = db,
        _userLocal = userLocal,
        _auth = auth,
        _isConnected = isConnected ?? NetworkService.isConnected;

  Future<UserModel?> initializeUserOnAppStart() async {
    try {
      // Check if there's a user in local storage
      final localUser = await _userLocal.getUserInfo();

      if (localUser == null) {
        return null; // No user, redirect to login
      }

      // Check if user is authenticated with Firebase
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return null; // Not authenticated, redirect to login
      }

      final connected = await _isConnected();
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

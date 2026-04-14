import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/user_model.dart';

class UserService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference _userRef(String uid) => _db.ref('users/$uid');

  String get _currentUid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user.uid;
  }

  // ========== CREATE ==========

  /// สร้าง user profile ใน RTDB (เรียกหลัง register สำเร็จ)
  Future<void> createUser(UserModel user) async {
    await _userRef(user.uid).set(user.toMap());
  }

  /// สร้าง profile จาก FirebaseAuth user โดยตรง (shortcut)
  Future<UserModel> createUserFromAuth({
    required String name,
    required User authUser,
  }) async {
    final user = UserModel.newUser(
      uid: authUser.uid,
      name: name,
      email: authUser.email ?? '',
    );
    await createUser(user);
    return user;
  }

  // ========== READ ==========

  /// ดึง user profile ครั้งเดียว (one-time read)
  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _userRef(uid).get();
    if (!snapshot.exists || snapshot.value == null) return null;

    return UserModel.fromMap(
      uid,
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
  }

  /// ดึง current user profile
  Future<UserModel?> getCurrentUser() async {
    return getUser(_currentUid);
  }

  /// Stream user profile (real-time update)
  /// ใช้กับ StreamBuilder ใน UI ได้เลย
  Stream<UserModel?> streamUser(String uid) {
    return _userRef(uid).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return UserModel.fromMap(
        uid,
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  /// Stream current user
  Stream<UserModel?> streamCurrentUser() {
    return streamUser(_currentUid);
  }

  /// เช็คว่ามี user นี้ใน DB แล้วหรือยัง
  Future<bool> userExists(String uid) async {
    final snapshot = await _userRef(uid).get();
    return snapshot.exists;
  }

  // ========== UPDATE ==========

  /// อัปเดต profile (บาง field เท่านั้น)
  Future<void> updateUser({
    String? name,
    String? photoUrl,
    String? bio,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (bio != null) updates['bio'] = bio;

    await _userRef(_currentUid).update(updates);
  }

  /// แทนที่ profile ทั้งก้อน
  Future<void> replaceUser(UserModel user) async {
    await _userRef(user.uid).set(user.toMap());
  }

  // ========== DELETE ==========

  /// ลบ profile (ใช้ตอน delete account)
  /// ⚠️ ระวัง: ไม่ได้ลบ activities/checkIns ของ user นี้ด้วย
  Future<void> deleteUser(String uid) async {
    await _userRef(uid).remove();
  }
}
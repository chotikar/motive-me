class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bio;
  final int createdAt;
  final int updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  // ========== Serialization ==========

  /// แปลง object → Map สำหรับส่งเข้า Firebase
  /// ไม่รวม uid เพราะ uid เป็น "key" ไม่ใช่ "field"
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// แปลง Map (จาก Firebase) → UserModel
  factory UserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      createdAt: map['createdAt'] ?? 0,
      updatedAt: map['updatedAt'] ?? 0,
    );
  }

  // ========== Helpers ==========

  /// สร้าง user ใหม่ (ตอน register) — ใส่ timestamp อัตโนมัติ
  factory UserModel.newUser({
    required String uid,
    required String name,
    required String email,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return UserModel(
      uid: uid,
      name: name,
      email: email,
      photoUrl: null,
      bio: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// สร้าง copy ที่มีบาง field ถูกแก้ — ใช้ตอน update profile
  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? bio,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, email: $email)';
}
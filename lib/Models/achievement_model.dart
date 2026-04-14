class Achievement {
  final String id;
  final String uid;
  final String title;
  final String description;
  final String icon;           // emoji or icon name
  final String category;       // e.g., "streak", "milestone", "performance"
  final int unlockedAt;        // timestamp
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.unlockedAt,
    this.isUnlocked = true,
  });

  // Convert object → Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'icon': icon,
      'category': category,
      'unlockedAt': unlockedAt,
      'isUnlocked': isUnlocked,
    };
  }

  // Convert Map (from Firebase) → object
  factory Achievement.fromMap(String id, Map<dynamic, dynamic> map) {
    return Achievement(
      id: id,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '🏆',
      category: map['category'] ?? 'milestone',
      unlockedAt: map['unlockedAt'] ?? 0,
      isUnlocked: map['isUnlocked'] ?? true,
    );
  }
}

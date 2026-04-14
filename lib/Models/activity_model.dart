class Activity {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String type;          // "weekly" or "monthly"
  final int target;           // จำนวนครั้งที่ต้องทำ
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int createdAt;

  Activity({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  // แปลง object → Map สำหรับส่งเข้า Firebase
  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'type': type,
      'target': target,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  // แปลง Map (จาก Firebase) → object
  factory Activity.fromMap(String id, Map<dynamic, dynamic> map) {
    return Activity(
      id: id,
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'weekly',
      target: map['target'] ?? 1,
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] ?? 0,
    );
  }
}
class CheckIn {
  final String id;
  final String activityId;
  final String userId;
  final String date;        // "YYYY-MM-DD"
  final int timestamp;
  final String? note;

  CheckIn({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.date,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'timestamp': timestamp,
      'note': note,
    };
  }

  factory CheckIn.fromMap(String id, String activityId, Map<dynamic, dynamic> map) {
    return CheckIn(
      id: id,
      activityId: activityId,
      userId: map['userId'] ?? '',
      date: map['date'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      note: map['note'],
    );
  }
}
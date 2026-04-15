class UserActivity {
  final String id;           // == $userActivityId
  final String activityId;   // immutable after creation
  final int startDate;       // timestamp ms, immutable
  final int expireDate;      // timestamp ms > startDate, immutable
  final int goal;            // 1–10000, immutable
  final int count;           // 0 to goal, only +1 at a time, only before expireDate
  final List<int> checkInDates; // { "0": timestamp, "1": timestamp, ... }

  UserActivity({
    required this.id,
    required this.activityId,
    required this.startDate,
    required this.expireDate,
    required this.goal,
    required this.count,
    this.checkInDates = const [],
  });

  // ── Computed helpers ──────────────────────────────────
  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expireDate;

  bool get isCompleted => count >= goal;

  bool get canCheckIn => !isExpired && !isCompleted;

  double get progress => goal == 0 ? 0 : count / goal;

  // ── Serialization ─────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'startDate': startDate,
      'expireDate': expireDate,
      'goal': goal,
      'count': count,
      if (checkInDates.isNotEmpty) 'checkInDates': checkInDates,
      // NO other fields — $other: false rejects anything extra
    };
  }

factory UserActivity.fromMap(String id, Map<dynamic, dynamic> map) {
  final Map<String, int> checkInDates = {};

  final raw = map['checkInDates'];
  if (raw != null) {
    if (raw is List) {
      // Firebase converted integer keys → List
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] != null) {
          checkInDates[i.toString()] = (raw[i] as num).toInt();
        }
      }
    } else if (raw is Map) {
      // Normal Map case
      Map<dynamic, dynamic>.from(raw).forEach((k, v) {
        if (v != null) {
          checkInDates[k.toString()] = (v as num).toInt();
        }
      });
    }
  }

  return UserActivity(
    id: id,
    activityId: map['activityId'] ?? '',
    startDate: (map['startDate'] ?? 0).toInt(),
    expireDate: (map['expireDate'] ?? 0).toInt(),
    goal: (map['goal'] ?? 1).toInt(),
    count: (map['count'] ?? 0).toInt(),
    checkInDates: (map['checkInDates'] ?? const []).toList(),
  );
}

  // Only count and checkInDates can change — all other fields are immutable
  UserActivity copyWith({
    int? count,
    List<int>? checkInDates,
  }) {
    return UserActivity(
      id: id,
      activityId: activityId,
      startDate: startDate,
      expireDate: expireDate,
      goal: goal,
      count: count ?? this.count,
      checkInDates: checkInDates ?? this.checkInDates,
    );
  }

  @override
  String toString() =>
      'UserActivity(id: $id, activityId: $activityId, count: $count/$goal, expired: $isExpired)';
}

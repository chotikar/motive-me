class UserActivity {
  final String id;
  final String activityId;
  final int startDate;
  final int expireDate;
  final int goal;
  final int count;
  final List<int> checkInDates;

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

  // True if there is already a check-in timestamp for today
  bool get hasCheckedInToday {
    final now = DateTime.now();
    return checkInDates.any((ts) {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return d.year == now.year && d.month == now.month && d.day == now.day;
    });
  }

  // Can check in only if: not expired, not completed, not already checked in today
  bool get canCheckIn => !isExpired && !isCompleted && !hasCheckedInToday;

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
    };
  }

  factory UserActivity.fromMap(String id, Map<dynamic, dynamic> map) {
    final List<int> checkInDates = [];

    final raw = map['checkInDates'];
    if (raw != null) {
      if (raw is List) {
        // Firebase auto-converts integer-keyed maps → List
        for (final item in raw) {
          if (item != null) checkInDates.add((item as num).toInt());
        }
      } else if (raw is Map) {
        // Map<key, timestamp> — collect values only
        Map<dynamic, dynamic>.from(raw).forEach((_, v) {
          if (v != null) checkInDates.add((v as num).toInt());
        });
      }
    }

    return UserActivity(
      id: id,
      activityId: map['activityId'] ?? '',
      startDate: (map['startDate'] as num? ?? 0).toInt(),
      expireDate: (map['expireDate'] as num? ?? 0).toInt(),
      goal: (map['goal'] as num? ?? 1).toInt(),
      count: (map['count'] as num? ?? 0).toInt(),
      checkInDates: checkInDates,
    );
  }

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
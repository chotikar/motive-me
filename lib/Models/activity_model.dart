class Activity {
  final String id;
  final String name;   // was 'title'
  final int reward;    // new — required by rules

  Activity({
    required this.id,
    required this.name,
    required this.reward,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,       // required: must equal $activityId
      'name': name,
      'reward': reward,
      // NO other fields — $other: false rejects anything extra
    };
  }

  factory Activity.fromMap(String id, Map<dynamic, dynamic> map) {
    return Activity(
      id: id,
      name: map['name'] ?? '',
      reward: (map['reward'] ?? 0).toInt(),
    );
  }

  Activity copyWith({String? name, int? reward}) {
    return Activity(
      id: id,
      name: name ?? this.name,
      reward: reward ?? this.reward,
    );
  }
}

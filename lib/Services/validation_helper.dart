class ValidationHelper {
  /// Validates the skill name.
  /// - Boundary: Empty/Null -> 'Name is required'
  /// - Boundary: > 80 characters -> 'Max is 80 characters'
  /// - Pattern: Only alphanumeric, spaces, _, -
  static String? validateSkillName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length > 80) {
      return 'Max is 80 characters';
    }
    if (!RegExp(r'^[A-Za-z0-9 _\-]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers, space, _ and - allowed';
    }
    return null;
  }

  /// Validates reward points.
  /// - Boundary: Empty/Null -> 'Reward is required'
  /// - Boundary: < 0 -> 'Must be 0 or more'
  static String? validateReward(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Reward is required';
    }
    final n = int.tryParse(value.trim());
    if (n == null || n < 0) {
      return 'Must be 0 or more';
    }
    return null;
  }

  /// Validates the goal.
  /// - Boundary: Empty/Null -> 'Goal is required'
  /// - Boundary: <= 0 -> 'Must be at least 1'
  /// - Boundary: > 10000 -> 'Max is 10,000'
  static String? validateGoal(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Goal is required';
    }
    final n = int.tryParse(value.trim());
    if (n == null || n <= 0) {
      return 'Must be at least 1';
    }
    if (n > 10000) {
      return 'Max is 10,000';
    }
    return null;
  }

  /// Validates password.
  /// - Boundary: Empty/Null -> 'Please enter a password'
  /// - Boundary: < 6 characters -> 'Password must be at least 6 characters'
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}

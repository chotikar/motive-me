import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Assets/app_colors.dart';
import '../Models/user_model.dart';
import '../Models/activity_model.dart';
import '../Models/user_activity_model.dart';
import '../Services/database_service.dart';

// ── Helpers ────────────────────────────────────────────────

class _SkillEntry {
  final UserActivity userActivity;
  final Activity activity;
  const _SkillEntry({required this.userActivity, required this.activity});
}

class _AchievementDef {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category;
  const _AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
  });
}

// ── Screen ─────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserModel _currentUser;
  int _selectedNavIndex = 0;
  bool _isLoading = true;

  List<_SkillEntry> _skills = [];
  Set<String> _unlockedIds = {};
  final Map<String, Activity> _activityCache = {};
  bool _isCheckingIn = false;
  StreamSubscription<List<UserActivity>>? _skillsSub;

  static const List<_AchievementDef> _achievementDefs = [
    _AchievementDef(
      id: 'monthly_first',
      title: 'Month Starter',
      description: 'Completed 1 habit this month',
      icon: '🌱',
      category: 'monthly',
    ),
    _AchievementDef(
      id: 'monthly_three',
      title: 'Monthly Grinder',
      description: 'Completed 3 habits this month',
      icon: '🔥',
      category: 'monthly',
    ),
    _AchievementDef(
      id: 'monthly_five',
      title: 'Monthly Champion',
      description: 'Completed 5 habits this month',
      icon: '🏆',
      category: 'monthly',
    ),
    _AchievementDef(
      id: 'monthly_ten',
      title: 'Unstoppable',
      description: 'Completed 10 habits this month',
      icon: '💪',
      category: 'monthly',
    ),
    _AchievementDef(
      id: 'monthly_checkins_10',
      title: 'Consistent',
      description: '10 check-ins this month',
      icon: '⭐',
      category: 'monthly',
    ),
    _AchievementDef(
      id: 'monthly_points_100',
      title: 'Reward Collector',
      description: 'Earned 100 points this month',
      icon: '💰',
      category: 'monthly',
    ),
  ];

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserFromLocalStorage();
  }

  @override
  void dispose() {
    _skillsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserFromLocalStorage() async {
    try {
      final user = await DatabaseService().getUserFromLocalStorage();
      if (user != null) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
        await _loadAchievements();
        _startSkillsStream();
      } else {
        if (mounted) routeToLoginScreen();
      }
    } catch (_) {
      if (mounted) routeToLoginScreen();
    }
  }

  void routeToLoginScreen() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedNavIndex = index);
  }

  // ── Skills stream ─────────────────────────────────────────

  void _startSkillsStream() {
    _skillsSub = DatabaseService()
        .streamUserActivities()
        .listen((userActivities) async {
      final entries = <_SkillEntry>[];

      for (final ua in userActivities) {
        Activity? act = _activityCache[ua.activityId];
        if (act == null) {
          act = await DatabaseService().getActivityById(ua.activityId);
          if (act != null) _activityCache[ua.activityId] = act;
        }
        if (act != null) {
          entries.add(_SkillEntry(userActivity: ua, activity: act));
        }
      }

      // Sort: Active → Completed → Expired
      entries.sort((a, b) {
        int rank(_SkillEntry e) {
          if (e.userActivity.isCompleted) return 2;
          if (e.userActivity.isExpired) return 3;
          return 1;
        }
        return rank(a).compareTo(rank(b));
      });

      if (mounted) setState(() => _skills = entries);
      await _checkAndUnlockAchievements(entries);
    });
  }

  // ── Achievements ──────────────────────────────────────────

  Future<void> _loadAchievements() async {
    final ids = await DatabaseService().getUnlockedAchievementIds();
    if (mounted) setState(() => _unlockedIds = ids);
  }

  Future<void> _checkAndUnlockAchievements(List<_SkillEntry> entries) async {
    final now = DateTime.now();
    final monthStart =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final monthEnd =
        DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;

    final thisMonthCompleted = entries.where((e) {
      final ua = e.userActivity;
      return ua.isCompleted &&
          ua.startDate >= monthStart &&
          ua.startDate < monthEnd;
    }).length;

    final thisMonthCheckIns = entries.fold<int>(0, (sum, e) {
      return sum +
          e.userActivity.checkInDates
              .where((ts) => ts >= monthStart && ts < monthEnd)
              .length;
    });

    final thisMonthPoints = entries.fold<int>(0, (sum, e) {
      final checkInsThisMonth = e.userActivity.checkInDates
          .where((ts) => ts >= monthStart && ts < monthEnd)
          .length;
      return sum + (e.activity.reward * checkInsThisMonth);
    });

    bool shouldUnlock(String id) {
      switch (id) {
        case 'monthly_first':       return thisMonthCompleted >= 1;
        case 'monthly_three':       return thisMonthCompleted >= 3;
        case 'monthly_five':        return thisMonthCompleted >= 5;
        case 'monthly_ten':         return thisMonthCompleted >= 10;
        case 'monthly_checkins_10': return thisMonthCheckIns >= 10;
        case 'monthly_points_100':  return thisMonthPoints >= 100;
        default:                    return false;
      }
    }

    bool hasChanges = false;
    for (final def in _achievementDefs) {
      final monthlyId = _monthlyId(def.id);
      if (!_unlockedIds.contains(monthlyId) && shouldUnlock(def.id)) {
        await DatabaseService().saveUnlockedAchievementId(monthlyId);
        _unlockedIds.add(monthlyId);
        hasChanges = true;
        if (mounted) _showAchievementToast(def);
      }
    }

    if (hasChanges && mounted) setState(() {});
  }

  String _monthlyId(String defId) {
    final now = DateTime.now();
    return '${defId}_${now.year}_${now.month.toString().padLeft(2, '0')}';
  }

  void _showAchievementToast(_AchievementDef def) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Text(def.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Achievement Unlocked!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[300]),
                ),
                Text(
                  def.title,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Check-in ──────────────────────────────────────────────

  Future<void> _checkIn(_SkillEntry entry) async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    try {
      await DatabaseService().checkIn(
          entry.userActivity.id, entry.userActivity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Checked in: ${entry.activity.name}!'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  // ── Computed stats ────────────────────────────────────────

  int get _totalSkills => _skills.length;

  int get _thisMonthCompleted {
    final now = DateTime.now();
    final monthStart =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final monthEnd =
        DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;
    return _skills.where((e) {
      final ua = e.userActivity;
      return ua.isCompleted &&
          ua.startDate >= monthStart &&
          ua.startDate < monthEnd;
    }).length;
  }

  int get _thisMonthPoints {
    final now = DateTime.now();
    final monthStart =
        DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final monthEnd =
        DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;
    return _skills.fold<int>(0, (sum, e) {
      final checkInsThisMonth = e.userActivity.checkInDates
          .where((ts) => ts >= monthStart && ts < monthEnd)
          .length;
      return sum + (e.activity.reward * checkInsThisMonth);
    });
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Motive Me')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Motive Me'),
        centerTitle: false,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Skill',
              onPressed: () =>
                  Navigator.pushNamed(context, '/create-skill'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: _buildProfileAvatar(),
              tooltip: 'Profile',
              onPressed: () =>
                  Navigator.pushNamed(context, '/profile'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _activityCache.clear();
          await _loadAchievements();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUser.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            fontWeight: FontWeight.normal,
                            color: AppColors.secondaryText,
                          ),
                    ),
                  ],
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildStatCard(
                        'Total Skills', '$_totalSkills', AppColors.info),
                    const SizedBox(width: 12),
                    _buildStatCard('Done This Month',
                        '$_thisMonthCompleted', AppColors.success),
                    const SizedBox(width: 12),
                    _buildStatCard(
                        'Points', '$_thisMonthPoints', AppColors.warning),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // My Skills header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      'My Skills',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (_totalSkills > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_totalSkills',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Skills list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _skills.isEmpty
                    ? _buildEmptySkills()
                    : Column(
                        children: _skills.map(_buildSkillCard).toList(),
                      ),
              ),
              const SizedBox(height: 24),

              // Achievements header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Achievements',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _unlockedIds.isEmpty
                    ? _buildEmptyAchievements()
                    : _buildAchievementsList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events), label: 'Achievements'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  // ── Skill widgets ─────────────────────────────────────────

  Widget _buildEmptySkills() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.fitness_center,
                size: 48, color: AppColors.getGreyShade(400)),
            const SizedBox(height: 12),
            Text(
              'No skills yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first skill to get started',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/create-skill'),
              icon: const Icon(Icons.add),
              label: const Text('Add Skill'),
            ),
          ],
        ),
      ),
    );
  }

  bool isCheckedInToday(List<int> timestamps) {
  final now = DateTime.now();
  
  return timestamps.any((ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  });
  }

  Widget _buildSkillCard(_SkillEntry entry) {
    final ua = entry.userActivity;
    final act = entry.activity;
    final fmt = DateFormat('dd MMM yyyy');
    final today = DateTime.now();

    final isExpired = ua.isExpired;
    final isCompleted = ua.isCompleted;
    final checkedInToday = isCheckedInToday(ua.checkInDates);
    final canCheckIn = ua.canCheckIn;

    final int totalPoints = act.reward * ua.goal;
    final int currentPoints = act.reward * ua.count;
    final int remainPoints = act.reward * (ua.goal - ua.count);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.4)
              : isExpired
                  ? AppColors.error.withOpacity(0.2)
                  : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + reward point chips
            Row(
              children: [
                Expanded(
                  child: Text(
                    act.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? AppColors.secondaryText
                              : AppColors.primaryText,
                        ),
                  ),
                ),
                // Total points
                _rewardChip(
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.primaryDark,
                  bgColor: AppColors.primaryLight,
                  label: '$totalPoints pts',
                  tooltip: 'Total points',
                ),
                const SizedBox(width: 4),
                // Current earned
                _rewardChip(
                  icon: Icons.star,
                  iconColor: AppColors.secondaryDark,
                  bgColor: AppColors.secondaryLight,
                  label: '+$currentPoints',
                  tooltip: 'Earned points',
                ),
                const SizedBox(width: 4),
                // Remaining
                _rewardChip(
                  icon: Icons.star_border,
                  iconColor: AppColors.secondaryText,
                  bgColor: AppColors.background,
                  label: '$remainPoints left',
                  tooltip: 'Remaining points',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ua.progress,
                minHeight: 7,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(
                  isCompleted
                      ? AppColors.success
                      : AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Count + expiry
            Row(
              children: [
                Text(
                  '${ua.count} / ${ua.goal} times',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today,
                    size: 12, color: AppColors.secondaryText),
                const SizedBox(width: 4),
                Text(
                  'Ends ${fmt.format(DateTime.fromMillisecondsSinceEpoch(ua.expireDate))}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Check-in button
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: canCheckIn && !_isCheckingIn
                        ? () => _checkIn(entry)
                        : null,
                    icon: Icon(
                      (isCompleted || checkedInToday)
                          ? Icons.check
                          : Icons.add_task,
                      size: 16,
                    ),
                    label: Text(
                      isCompleted
                          ? 'Completed'
                          : isExpired
                              ? 'Expired'
                              : checkedInToday
                                  ? 'Done today'
                                  : 'Check In',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canCheckIn
                          ? AppColors.primaryDark
                          : AppColors.getGreyShade(200),
                      foregroundColor: canCheckIn
                          ? AppColors.white
                          : AppColors.secondaryText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      elevation: canCheckIn ? 2 : 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Reward chip helper ────────────────────────────────────

  Widget _rewardChip({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: iconColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Achievement widgets ───────────────────────────────────

  Widget _buildEmptyAchievements() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.emoji_events, size: 40, color: Colors.amber[600]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep Going!',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete your first check-in to unlock achievements',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsList() {
    final unlocked = _achievementDefs
        .where((def) => _unlockedIds.contains(_monthlyId(def.id)))
        .toList();

    if (unlocked.isEmpty) return _buildEmptyAchievements();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unlocked.map((def) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.amber.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(def.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                def.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Existing widgets ──────────────────────────────────────

  Widget _buildProfileAvatar() {
    final photoUrl = _currentUser.photoUrl;
    if (photoUrl == null || photoUrl.isEmpty) {
      return Icon(Icons.person, size: 30, color: AppColors.primaryDark);
    }
    if (!photoUrl.startsWith('http')) {
      try {
        final bytes = base64Decode(photoUrl);
        return ClipOval(
          child: Image.memory(bytes,
              fit: BoxFit.cover,
              width: 30,
              height: 30,
              errorBuilder: (_, __, ___) => Icon(Icons.person,
                  size: 30, color: AppColors.primaryDark)),
        );
      } catch (_) {
        return Icon(Icons.person, size: 30, color: AppColors.primaryDark);
      }
    }
    return ClipOval(
      child: Image.network(photoUrl,
          fit: BoxFit.cover,
          width: 30,
          height: 30,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person, size: 30, color: AppColors.primaryDark)),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
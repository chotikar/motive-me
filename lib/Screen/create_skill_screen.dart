import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../Assets/app_colors.dart';
import '../Models/activity_model.dart';
import '../Services/database_service.dart';

class CreateSkillScreen extends StatefulWidget {
  const CreateSkillScreen({super.key});

  @override
  State<CreateSkillScreen> createState() => _CreateSkillScreenState();
}

class _CreateSkillScreenState extends State<CreateSkillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rewardController = TextEditingController();
  final _goalController = TextEditingController();

  List<Activity> _suggestions = [];
  Activity? _selectedSuggestion; // null = custom mode
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isFetchingSuggestions = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rewardController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────

  Future<void> _loadSuggestions() async {
    try {
      final activities = await DatabaseService().getAllActivities();
      setState(() {
        _suggestions = activities;
        _isFetchingSuggestions = false;
      });
    } catch (_) {
      setState(() => _isFetchingSuggestions = false);
    }
  }

  void _selectSuggestion(Activity activity) {
    setState(() {
      _selectedSuggestion = activity;
      _nameController.text = activity.name;
      _rewardController.text = activity.reward.toString();
    });
  }

  void _clearSuggestion() {
    setState(() {
      _selectedSuggestion = null;
      _nameController.clear();
      _rewardController.clear();
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = isStart
        ? now
        : (_startDate ?? now).add(const Duration(days: 1));

    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ??
            (_startDate ?? now).add(const Duration(days: 7)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && !_endDate!.isAfter(picked)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _addSkill() async {
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startDate == null) {
      setState(() => _errorMessage = 'Please select a start date');
      return;
    }
    if (_endDate == null) {
      setState(() => _errorMessage = 'Please select an end date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final goal = int.parse(_goalController.text.trim());
      final startMs = DateTime(
        _startDate!.year, _startDate!.month, _startDate!.day,
      ).millisecondsSinceEpoch;
      final expireMs = DateTime(
        _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59,
      ).millisecondsSinceEpoch;

      if (_selectedSuggestion != null) {
        // Suggestion selected → only create UserActivity
        await DatabaseService().addSkillFromSuggestion(
          activityId: _selectedSuggestion!.id,
          goal: goal,
          startDate: startMs,
          expireDate: expireMs,
        );
      } else {
        // Custom → create Activity + UserActivity
        await DatabaseService().createSkill(
          name: _nameController.text.trim(),
          reward: int.parse(_rewardController.text.trim()),
          goal: goal,
          startDate: startMs,
          expireDate: expireMs,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skill added!'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCustom = _selectedSuggestion == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Skill'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Suggestions ──────────────────────────────
              _label('Suggestions'),
              const SizedBox(height: 4),
              const Text(
                'Pick an existing activity or create your own',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 10),
              _buildSuggestionRow(),
              const SizedBox(height: 24),

              // ── Error ────────────────────────────────────
              if (_errorMessage != null) ...[
                _errorBox(_errorMessage!),
                const SizedBox(height: 16),
              ],

              // ── Name ─────────────────────────────────────
              _label('Skill Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                enabled: isCustom,
                maxLength: 80,
                // Firebase rule: only A-Z a-z 0-9 space _ -
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 _\-]')),
                ],
                decoration: _inputDeco(
                  hint: 'e.g. Push-ups',
                  locked: !isCustom,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (!RegExp(r'^[A-Za-z0-9 _\-]+$').hasMatch(v.trim())) {
                    return 'Only letters, numbers, space, _ and - allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Reward ───────────────────────────────────
              _label('Reward (points)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rewardController,
                enabled: isCustom,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDeco(
                  hint: 'e.g. 50',
                  locked: !isCustom,
                  prefix: const Icon(Icons.star, size: 18, color: AppColors.secondaryDark),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Reward is required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return 'Must be 0 or more';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Goal ─────────────────────────────────────
              _label('Goal'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDeco(
                  hint: 'How many times to complete (1 – 10,000)',
                  prefix: const Icon(Icons.flag_outlined, size: 18, color: AppColors.primaryDark),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Goal is required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be at least 1';
                  if (n > 10000) return 'Max is 10,000';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Dates ────────────────────────────────────
              _label('Duration'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _dateButton(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateButton(
                      label: 'End Date',
                      date: _endDate,
                      onTap: _startDate == null
                          ? null // disable until start is picked
                          : () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Add Button ───────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addSkill,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Add Skill',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget helpers ────────────────────────────────────

  Widget _buildSuggestionRow() {
    if (_isFetchingSuggestions) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Custom chip (always first)
          _suggestionChip(
            label: '+ Custom',
            reward: null,
            isSelected: _selectedSuggestion == null,
            onTap: _clearSuggestion,
          ),
          // Suggestions from Firebase
          ..._suggestions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _suggestionChip(
                label: a.name,
                reward: a.reward,
                isSelected: _selectedSuggestion?.id == a.id,
                onTap: () => _selectSuggestion(a),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip({
    required String label,
    required int? reward,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.divider,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (reward != null) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 11,
                    color: isSelected
                        ? AppColors.secondary
                        : AppColors.secondaryDark,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$reward pts',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback? onTap,
  }) {
    final fmt = DateFormat('dd MMM yyyy');
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: disabled
                ? AppColors.divider
                : date != null
                    ? AppColors.primaryDark
                    : AppColors.divider,
            width: date != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: disabled
              ? AppColors.surfaceVariant
              : date != null
                  ? AppColors.primaryLight.withOpacity(0.3)
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: disabled
                    ? AppColors.disabled
                    : AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: disabled ? AppColors.disabled : AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  date != null ? fmt.format(date) : 'Pick date',
                  style: TextStyle(
                    fontSize: 13,
                    color: disabled
                        ? AppColors.disabled
                        : date != null
                            ? AppColors.primaryText
                            : AppColors.hintText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
      );

  InputDecoration _inputDeco({
    required String hint,
    bool locked = false,
    Widget? prefix,
  }) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: locked
            ? const Icon(Icons.lock_outline,
                size: 16, color: AppColors.secondaryText)
            : null,
        filled: true,
        fillColor: locked ? AppColors.surfaceVariant : AppColors.surface,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      );

  Widget _errorBox(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.red.withOpacity(0.1),
          border: Border.all(color: Colors.red),
        ),
        child: Text(msg, style: const TextStyle(color: Colors.red)),
      );
}
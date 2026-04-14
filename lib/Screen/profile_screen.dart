import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Assets/app_colors.dart';
import '../Models/user_model.dart';
import '../Services/database_service.dart';
import 'edit_profile_screen.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  int _achievementCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await DatabaseService().getUserFromLocalStorage();
      if (user != null) {
        // Fetch achievement count
        final achievementCount = await DatabaseService().getAchievementCount();
        
        setState(() {
          _user = user;
          _achievementCount = achievementCount;
          _isLoading = false;
        });
      } else {
        // No user found, redirect to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      // Error loading user, redirect to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _logout() async {
    try {
      // Clear local storage
      await DatabaseService().clearLocalStorage();
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error logging out')),
        );
      }
    }
  }

  String _formatDate(int milliseconds) {
    if (milliseconds == 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              _showLogoutConfirmation();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                        border: Border.all(
                          color: AppColors.white,
                          width: 3,
                        ),
                      ),
                      child: _user.photoUrl != null && _user.photoUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                _user.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppColors.primaryDark,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.primaryDark,
                            ),
                    ),
                    const SizedBox(height: 16),
                    // User Name
                    Text(
                      _user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Email
                    Text(
                      _user.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Profile Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio Section
                  if (_user.bio != null && _user.bio!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bio',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.background,
                            border: Border.all(
                              color: AppColors.primaryDark.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _user.bio!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  // Achievements Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(0.1),
                          AppColors.primaryDark.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: AppColors.primaryDark.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 40,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Achievements',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaryText,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_achievementCount',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Account Information Section
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // UID
                  _buildInfoTile(
                    icon: Icons.badge,
                    label: 'Bio',
                    value: _user.bio == "" ? 'No bio available' : _user.bio!
                  ),
                  const SizedBox(height: 12),
                  // Last Updated
                  _buildInfoTile(
                    icon: Icons.update,
                    label: 'Last Updated',
                    value: _formatDate(_user.updatedAt == 0 ? _user.createdAt : _user.updatedAt),
                  ),
                  const SizedBox(height: 24),
                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                      onPressed: () async {
                        final updatedUser = await Navigator.of(context).push<UserModel>(
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(user: _user),
                          ),
                        );

                        // If user was updated, refresh the profile
                        if (updatedUser != null) {
                          setState(() {
                            _user = updatedUser;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    bool isCopyable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
        border: Border.all(
          color: AppColors.primaryDark.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryDark,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy),
              iconSize: 18,
              onPressed: () {
                // TODO: Implement copy to clipboard functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

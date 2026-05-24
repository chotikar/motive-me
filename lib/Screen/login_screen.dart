import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:motive_me/Local/user_local.dart';
import 'package:motive_me/Services/firebase_user_profile_service.dart';
import '../Assets/app_colors.dart';
import '../Services/database_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    print('DIAG SCREEN: _login() function entered');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      print('DIAG SCREEN: inputs are empty, returning early');
      setState(() { 
        _errorMessage = 'Please enter your email and password';
        _isLoading = false;
      });
      return;
    }

    try {
      print('DIAG SCREEN: Calling signInWithEmailAndPassword...');
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = credential.user!.uid;
      print('DIAG SCREEN: signInWithEmailAndPassword successful, uid: $uid');

      // Fetch user info from Firebase and store in local storage
      try {
        final userProfile = await FirebaseUserProfileService().getUserProfile();
        if (userProfile != null) {
          // Convert Map to UserModel and save to local storage
          final userModel = FirebaseUserProfileService().mapToUserModel(
            uid,
            userProfile,
          );
          await UserLocal().saveUser(userModel);
        }
      } catch (e) {
        // If fetching from Firebase fails, continue anyway
        print('Error fetching user profile: $e');
      }

      if (mounted) {
        print('DIAG SCREEN: Navigating to /home');
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      print('DIAG SCREEN: FirebaseAuthException caught: $e');
      setState(() {
        _errorMessage = e.message ?? 'Login failed';
      });
    } catch (e) {
      print('DIAG SCREEN: General exception caught: $e');
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // App Logo
            Icon(Icons.psychology, size: 80, color: AppColors.primaryDark),
            const SizedBox(height: 24),
            // Title
            const Text(
              'Motive Me',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // Email field
            TextField(
              key: const Key('emailField'),
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Password field
            TextField(
              key: const Key('passwordField'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            const SizedBox(height: 24),
            // Login button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('loginButton'),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      )
                    : const Text('Login', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Don\'t have an account? '),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed('/signup');
                  },
                  child: Text(
                    'Sign up',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
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
}

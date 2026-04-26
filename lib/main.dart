import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:motive_me/Local/user_local.dart';
import 'firebase_options.dart';
import 'Assets/app_colors.dart';
import 'Screen/home_screen.dart';
import 'Screen/login_screen.dart';
import 'Screen/signup_screen.dart';
import 'Screen/profile_screen.dart';
import 'Screen/create_skill_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motive Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryDark),
        useMaterial3: true,
      ),
      home: const _SplashGate(),
      routes: {
        '/login': (_) => const LoginView(),
        '/signup': (_) => const SignupView(),
        '/home': (_) => const HomeScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/create-skill': (_) => const CreateSkillScreen(),
      },
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    try {
      final user = await UserLocal().getUserInfo();
      if (!mounted) return;
      if (user != null) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Motive Me',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RevenueDeptApp());
}

class RevenueDeptApp extends StatelessWidget {
  const RevenueDeptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TN Revenue Dept',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _loading = true;
  bool _seenOnboarding = false;
  bool _loggedIn = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    final token = prefs.getString('session_token');

    Map<String, dynamic>? user;
    bool loggedIn = false;

    if (token != null && token.isNotEmpty) {
      user = await ApiService().getMe();
      loggedIn = user != null;
      if (!loggedIn) {
        await prefs.remove('session_token');
      }
    }

    if (mounted) {
      setState(() {
        _seenOnboarding = seenOnboarding;
        _loggedIn = loggedIn;
        _user = user;
        _loading = false;
      });
    }
  }

  void _onOnboardingDone() {
    setState(() => _seenOnboarding = true);
  }

  Future<void> _onLogin() async {
    final user = await ApiService().getMe();
    setState(() {
      _loggedIn = true;
      _user = user;
    });
  }

  void _onLogout() {
    setState(() {
      _loggedIn = false;
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0f3d1a),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance, color: Color(0xFFfbbf24), size: 64),
              SizedBox(height: 20),
              Text(
                'Revenue Department',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Government of Tamil Nadu',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                color: Color(0xFFfbbf24),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      );
    }

    if (!_seenOnboarding) {
      return OnboardingScreen(onDone: _onOnboardingDone);
    }

    if (!_loggedIn) {
      return LoginScreen(onLogin: _onLogin);
    }

    return HomeScreen(onLogout: _onLogout, user: _user);
  }
}

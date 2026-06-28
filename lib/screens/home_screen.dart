import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final Map<String, dynamic>? user;

  const HomeScreen({super.key, required this.onLogout, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Keys to reset/control chat screens
  final GlobalKey<ChatScreenState> _knowledgeKey = GlobalKey<ChatScreenState>();
  final GlobalKey<ChatScreenState> _chargesheetKey = GlobalKey<ChatScreenState>();

  String get _userName {
    if (widget.user == null) return 'Officer';
    return widget.user!['name'] as String? ??
        widget.user!['username'] as String? ??
        widget.user!['email'] as String? ??
        'Officer';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService().logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      widget.onLogout();
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          onResume: (sessionId, mode, messages, title) {
            Navigator.pop(context); // close history screen
            // Switch to correct tab then load session
            setState(() => _currentIndex = mode == 'chargesheet' ? 1 : 0);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mode == 'chargesheet') {
                _chargesheetKey.currentState?.loadSession(sessionId, messages);
              } else {
                _knowledgeKey.currentState?.loadSession(sessionId, messages);
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf5f7f5),
      appBar: AppBar(
        backgroundColor: AppTheme.darkGreen,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset('assets/images/tn-emblem.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revenue Department',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                Text('Welcome, $_userName',
                    style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 11.5, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        actions: [
          // History button
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
            tooltip: 'Chat History',
            onPressed: _openHistory,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(key: _knowledgeKey, mode: 'knowledge'),
          ChatScreen(key: _chargesheetKey, mode: 'chargesheet'),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFe8ede9), width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _BottomTab(label: 'Knowledge Chat', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, isActive: _currentIndex == 0, onTap: () => setState(() => _currentIndex = 0)),
                _BottomTab(label: 'Charge Sheet', icon: Icons.description_outlined, activeIcon: Icons.description_rounded, isActive: _currentIndex == 1, onTap: () => setState(() => _currentIndex = 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomTab({required this.label, required this.icon, required this.activeIcon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isActive ? AppTheme.primaryGreen : Colors.transparent, width: 2.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActive ? activeIcon : icon, size: 22, color: isActive ? AppTheme.primaryGreen : Colors.grey.shade400),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppTheme.primaryGreen : Colors.grey.shade400,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

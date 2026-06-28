import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_SlideData> _slides = [
    _SlideData(
      gradientColors: [const Color(0xFF0a2810), const Color(0xFF0f3d1a)],
      icon: Icons.account_balance,
      iconColor: const Color(0xFFfbbf24),
      title: 'Tamil Nadu\nRevenue Department',
      subtitle:
          'AI-powered document intelligence for government officers. Access policy knowledge instantly.',
      isLast: false,
    ),
    _SlideData(
      gradientColors: [const Color(0xFF0f3d1a), const Color(0xFF1a6b2e)],
      icon: Icons.chat_bubble_rounded,
      iconColor: Colors.white,
      title: 'Knowledge Chat',
      subtitle:
          'Ask any question about revenue policies, GO orders, land records and get precise, cited answers in seconds.',
      isLast: false,
    ),
    _SlideData(
      gradientColors: [const Color(0xFF0a2810), const Color(0xFF1a4a20)],
      icon: Icons.description_rounded,
      iconColor: const Color(0xFFfbbf24),
      title: 'Charge Sheet\nGenerator',
      subtitle:
          'Enter case facts and let AI draft legally precise charge sheets aligned with TN Revenue procedures.',
      isLast: true,
    ),
  ];

  Future<void> _markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return _SlidePage(data: _slides[index]);
            },
          ),
          // Dots indicator
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _controller,
                count: _slides.length,
                effect: const WormEffect(
                  dotColor: Colors.white38,
                  activeDotColor: Color(0xFFfbbf24),
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 12,
                ),
              ),
            ),
          ),
          // Bottom buttons
          Positioned(
            bottom: 40,
            left: 32,
            right: 32,
            child: _currentPage == _slides.length - 1
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFd97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      await _markOnboardingDone();
                      widget.onDone();
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await _markOnboardingDone();
                          widget.onDone();
                        },
                        child: const Text('Skip',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 15)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1a6b2e),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Next',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final List<Color> gradientColors;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLast;

  const _SlideData({
    required this.gradientColors,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });
}

class _SlidePage extends StatelessWidget {
  final _SlideData data;
  const _SlidePage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.15), width: 1.5),
                ),
                child: Icon(data.icon, size: 72, color: data.iconColor),
              ),
              const SizedBox(height: 48),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

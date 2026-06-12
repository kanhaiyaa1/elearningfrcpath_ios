import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.school_outlined,
      color: Color(0xFF2E7D32),
      title: 'Welcome to eLearningFRCPath',
      subtitle: 'Your complete FRCPath exam prep companion — with powerful built-in study tools.',
    ),
    _OnboardingPage(
      icon: Icons.timer_outlined,
      color: Color(0xFF1565C0),
      title: 'Study Timer',
      subtitle: 'Track focused study sessions with Pomodoro-style timing. Build consistent daily habits.',
    ),
    _OnboardingPage(
      icon: Icons.notifications_outlined,
      color: Color(0xFFE65100),
      title: 'Daily Reminders',
      subtitle: 'Set custom study reminders so you never miss a session. Stay on schedule every day.',
    ),
    _OnboardingPage(
      icon: Icons.campaign_outlined,
      color: Color(0xFF6A1B9A),
      title: 'Push Notifications',
      subtitle: 'Get notified about new content, exam updates, and study nudges — even when the app is closed.',
    ),
    _OnboardingPage(
      icon: Icons.bookmark_border,
      color: Color(0xFF00695C),
      title: 'Bookmarks & Reading List',
      subtitle: 'Save important pages and build a reading list to revisit key topics quickly.',
    ),
    _OnboardingPage(
      icon: Icons.dashboard_outlined,
      color: Color(0xFFC62828),
      title: 'Progress Dashboard',
      subtitle: 'Track pages visited, study streaks, and your overall exam preparation progress.',
    ),
    _OnboardingPage(
      icon: Icons.calendar_month_outlined,
      color: Color(0xFF283593),
      title: 'Study Calendar',
      subtitle: 'Plan and schedule study sessions around your exam date with the built-in calendar.',
    ),
    _OnboardingPage(
      icon: Icons.face_retouching_natural,
      color: Color(0xFF37474F),
      title: 'Face ID / Touch ID Lock',
      subtitle: 'Secure the app with biometric authentication. Your progress stays private.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Skip', style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.grey,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// onboarding_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _iconAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _pages = [
  {
  'title': 'Learn Any Language',
  'description': 'Master vocabulary, pronunciation, and grammar with bite-sized lessons.',
  'icon': Icons.public_rounded,
  'gradient': [Color(0xFF4361ee), Color(0xFF7209b7)],
  'emoji': '🌍',
},
{
'title': 'Speak with Confidence',
'description': 'Practice real conversations with native speakers and AI tutors.',
'icon': Icons.forum_rounded,
'gradient': [Color(0xFF7209b7), Color(0xFFf72585)],
'emoji': '💬',
},
{
'title': 'Track Your Progress',
'description': 'Set goals, earn streaks, and see how far you\'ve come.',
'icon': Icons.trending_up_rounded,
'gradient': [Color(0xFFf72585), Color(0xFFff6d00)],
'emoji': '📈',
},
];

@override
void initState() {
  super.initState();
  _iconAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  _fadeAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  _scaleAnimation = CurvedAnimation(
    parent: _iconAnimationController,
    curve: Curves.elasticOut,
  );
  _fadeAnimation = CurvedAnimation(
    parent: _fadeAnimationController,
    curve: Curves.easeIn,
  );

  _iconAnimationController.forward();
  _fadeAnimationController.forward();
}

void _nextPage() {
  if (_currentPage < _pages.length - 1) {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  } else {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}

void _skipToLogin() {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

@override
void dispose() {
  _pageController.dispose();
  _iconAnimationController.dispose();
  _fadeAnimationController.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final size = MediaQuery.of(context).size;

  return Scaffold(
    backgroundColor: colorScheme.background,
    body: SafeArea(
      child: Stack(
        children: [
          // Decorative background elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary.withOpacity(0.08),
                    colorScheme.secondary.withOpacity(0.03),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              // Header with logo and skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App logo
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    // Skip button
                    TextButton(
                      onPressed: _skipToLogin,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Animated page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    // Restart animations on page change
                    _iconAnimationController.reset();
                    _fadeAnimationController.reset();
                    _iconAnimationController.forward();
                    _fadeAnimationController.forward();
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated icon with gradient background
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: page['gradient'] as List<Color>,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: (page['gradient'] as List<Color>)[0].withOpacity(0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pulsing background effect
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(seconds: 2),
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: 1.0 + (math.sin(value * math.pi * 2) * 0.05),
                                        child: Opacity(
                                          opacity: 0.3,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(40),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    onEnd: () {
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                  // Icon
                                  Icon(
                                    page['icon'] as IconData,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Text content with fade animation
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                Text(
                                  page['title']!,
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onBackground,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  page['description']!,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onBackground.withOpacity(0.7),
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Page indicators
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: isActive ? 32 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                          colors: (_pages[index]['gradient'] as List<Color>),
                        )
                            : null,
                        color: isActive ? null : colorScheme.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // Next/Get Started Button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage == _pages.length - 1
                              ? colorScheme.primary
                              : colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: colorScheme.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ).copyWith(
                          elevation: MaterialStateProperty.resolveWith<double>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) return 0;
                              return 8;
                            },
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_currentPage < _pages.length - 1) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Swipe to continue',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
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
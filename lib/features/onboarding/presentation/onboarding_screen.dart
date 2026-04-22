import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:mp3tageditor/core/services/shared_prefs_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = false;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: CupertinoIcons.music_note_list,
      title: 'Audio Tag Editor',
      description:
          'Welcome to the ultimate tool for organizing your audio library. Fix missing metadata, add beautiful cover arts, and bring your library to life.',
    ),
    _OnboardingData(
      icon: CupertinoIcons.music_note_list,
      title: 'Edit Metadata',
      description:
          'Seamlessly update titles, artists, albums, and genres to ensure everything is perfect.',
    ),
    _OnboardingData(
      icon: CupertinoIcons.share,
      title: 'Export & Share',
      description:
          'Save your perfectly tagged files and easily export or share them anywhere, preserving your pristine cover arts and metadata.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final prefs = ref.read(sharedPrefsServiceProvider);
    await prefs.setBool('has_seen_onboarding', true);

    // Show the paywall before navigating away
    await RevenueCatUI.presentPaywallIfNeeded("premium");

    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.4, -0.2),
                  radius: 1.5,
                  colors: [
                    isDark ? const Color(0xFF1F1A40) : const Color(0xFFF3EDFA),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top header (Skip button)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white70 : Colors.black54,
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged:
                        (index) => setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPageContent(_pages[index], isDark);
                    },
                  ),
                ),

                // Bottom Section: Title, Description, Indicators
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: _pages[_currentPage].title,
                          style: Theme.of(
                            context,
                          ).textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                          children: [
                            TextSpan(
                              text: '.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pages[_currentPage].description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          fontSize: 15,
                          color:
                              isDark
                                  ? Colors.white70
                                  : Colors.black87.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: List.generate(
                              _pages.length,
                              (index) => TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                tween: Tween(
                                  end: _currentPage == index ? 24.0 : 8.0,
                                ),
                                builder: (context, value, child) {
                                  return Container(
                                    width: value,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          _currentPage == index
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : (isDark
                                                  ? Colors.white24
                                                  : Colors.black12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child:
                                _currentPage == _pages.length - 1
                                    ? ElevatedButton(
                                      key: const ValueKey('finish'),
                                      onPressed: _finish,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 14,
                                        ),
                                        elevation: 8,
                                        shadowColor: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.5),
                                      ),
                                      child:
                                          _isLoading
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : const Text(
                                                'Start',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                    )
                                    : FloatingActionButton(
                                      key: const ValueKey('next'),
                                      onPressed: () {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                      elevation: 8,
                                      child: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 20,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(_OnboardingData data, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(isDark ? 0.3 : 0.1),
                Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(isDark ? 0.1 : 0.0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(isDark ? 0.2 : 0.15),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              data.icon,
              size: 120,
              color: isDark ? Colors.white : Colors.black87,
              shadows: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 64),
      ],
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String description;

  _OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

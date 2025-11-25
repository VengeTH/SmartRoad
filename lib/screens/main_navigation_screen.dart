import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../core/theme/app_theme.dart";
import "map/map_screen.dart";
import "feed/feed_screen.dart";
import "profile/profile_screen.dart";
import "report/report_hazard_screen.dart";

/// * Main navigation screen with bottom navigation bar
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});
  
  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabAnimationController;
  late PageController _pageController;
  
  final List<Widget> _screens = [
    const MapScreen(),
    const FeedScreen(),
    const ProfileScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: AppTheme.animationNormal,
    )..forward();
  }
  
  @override
  void dispose() {
    _fabAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    
    // * Haptic feedback
    HapticFeedback.selectionClick();
    
    setState(() {
      _currentIndex = index;
    });
    
    // * Animate page transition
    _pageController.animateToPage(
      index,
      duration: AppTheme.animationNormal,
      curve: AppTheme.animationCurve,
    );
    
    // * Animate FAB
    if (index == 0) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // * Disable swipe, use buttons only
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: AppTheme.borderColor,
              width: 1.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: "Map",
                  isActive: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavItem(
                  icon: Icons.feed_outlined,
                  activeIcon: Icons.feed,
                  label: "Feed",
                  isActive: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: "Profile",
                  isActive: _currentIndex == 2,
                  onTap: () => _onTabTapped(2),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? ScaleTransition(
              scale: CurvedAnimation(
                parent: _fabAnimationController,
                curve: AppTheme.animationCurveBounce,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  boxShadow: AppTheme.shadowGlow,
                ),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ReportHazardScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 1.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_alert_rounded),
                  label: const Text(
                    "Report",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            )
          : null,
    );
  }
}

/// * Custom navigation item with premium styling
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingSM,
              horizontal: AppTheme.spacingXS,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppTheme.animationNormal,
                  curve: AppTheme.animationCurve,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.textTertiary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: AppTheme.animationNormal,
                  curve: AppTheme.animationCurve,
                  style: TextStyle(
                    fontSize: isActive ? 12 : 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.textTertiary,
                    letterSpacing: 0.3,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


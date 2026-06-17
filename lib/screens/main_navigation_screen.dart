import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../features/map/map_screen_bridge.dart";
import "feed/feed_screen.dart";
import "routes/routes_screen.dart";
import "profile/profile_screen.dart";
import "report/report_hazard_screen.dart";
import "../core/theme/app_theme.dart";
import "../../providers/navigation_provider.dart";
import "../../providers/map_ui_provider.dart";
import "../../services/supabase_service.dart";
import "../../providers/auth_provider.dart";

/// * Main navigation screen — responsive: bottom nav on mobile, sidebar rail on desktop.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = [
    const MapScreenBridge(),
    const FeedScreen(),
    const RoutesScreen(),
    const ProfileScreen(),
  ];

  static const _navLabels = ["Map", "Feed", "Routes", "Profile"];
  static const _navIcons = [Icons.map_outlined, Icons.feed_outlined, Icons.route_outlined, Icons.person_outline];
  static const _navSelectedIcons = [Icons.map, Icons.feed, Icons.route, Icons.person];

  void _onDestinationSelected(int index) {
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (index == 2 && isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sign in to create or save routes"),
          action: SnackBarAction(
            label: "Sign in",
            onPressed: () => Navigator.of(context).pushNamed("/login"),
          ),
        ),
      );
      return;
    }
    ref.read(navigationTabProvider.notifier).switchToTab(index);
  }

  void _onReportHazard() {
    final service = SupabaseService();
    if (!service.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sign in to report hazards"),
          action: SnackBarAction(
            label: "Sign in",
            onPressed: () => Navigator.of(context).pushNamed("/login"),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReportHazardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationTabProvider);
    final isMapNavigating = ref.watch(mapIsNavigatingProvider);
    final isDesktop = AppTheme.isDesktop(context);
    final isWideDesktop = AppTheme.isWideDesktop(context);

    if (isDesktop) {
      return _buildDesktopLayout(currentIndex, isMapNavigating, isWideDesktop);
    }
    return _buildMobileLayout(currentIndex, isMapNavigating);
  }

  /// * Desktop layout: NavigationRail sidebar + content area
  Widget _buildDesktopLayout(int currentIndex, bool isMapNavigating, bool showLabels) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: showLabels ? NavigationRailLabelType.all : NavigationRailLabelType.none,
            backgroundColor: AppTheme.surfaceColor,
            selectedIconTheme: const IconThemeData(color: AppTheme.brandAccentColor, size: 24),
            unselectedIconTheme: IconThemeData(color: AppTheme.textSecondary, size: 22),
            selectedLabelTextStyle: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            indicatorColor: AppTheme.brandAccentColor.withOpacity(0.15),
            leading: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: IconButton(
                icon: const Icon(Icons.add_alert, color: AppTheme.brandAccentColor),
                tooltip: "Report hazard",
                onPressed: _onReportHazard,
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "SmartRoad",
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            destinations: List.generate(_navLabels.length, (i) {
              return NavigationRailDestination(
                icon: Icon(_navIcons[i]),
                selectedIcon: Icon(_navSelectedIcons[i]),
                label: Text(_navLabels[i]),
              );
            }),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: AppTheme.borderColor),
          Expanded(child: IndexedStack(index: currentIndex, children: _screens)),
        ],
      ),
    );
  }

  /// * Mobile layout: bottom NavigationBar + FAB
  Widget _buildMobileLayout(int currentIndex, bool isMapNavigating) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: List.generate(_navLabels.length, (i) {
          return NavigationDestination(
            icon: Icon(_navIcons[i]),
            selectedIcon: Icon(_navSelectedIcons[i]),
            label: _navLabels[i],
          );
        }),
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              heroTag: "report_hazard_fab",
              onPressed: _onReportHazard,
              mini: isMapNavigating,
              tooltip: "Report hazard",
              child: const Icon(Icons.add_alert),
            )
          : null,
    );
  }
}

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "map/map_screen.dart";
import "feed/feed_screen.dart";
import "routes/routes_screen.dart";
import "profile/profile_screen.dart";
import "report/report_hazard_screen.dart";
import "../../providers/navigation_provider.dart";
import "../../providers/map_ui_provider.dart";
import "../../services/supabase_service.dart";
import "../../providers/auth_provider.dart";

/// * Main navigation screen with bottom navigation bar
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = [
    const MapScreen(),
    const FeedScreen(),
    const RoutesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationTabProvider);
    final isMapNavigating = ref.watch(mapIsNavigatingProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final isGuest = user == null;

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // * Routes tab (index 2) requires sign-in
          if (index == 2 && isGuest) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Sign in to create or save routes"),
                action: SnackBarAction(
                  label: "Sign in",
                  onPressed: () {
                    Navigator.of(context).pushNamed("/login");
                  },
                ),
              ),
            );
            return;
          }
          ref.read(navigationTabProvider.notifier).switchToTab(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: "Map",
          ),
          NavigationDestination(
            icon: Icon(Icons.feed_outlined),
            selectedIcon: Icon(Icons.feed),
            label: "Feed",
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: "Routes",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
      floatingActionButton:
          currentIndex == 0
              ? FloatingActionButton(
                heroTag: "report_hazard_fab",
                onPressed: () {
                  final service = SupabaseService();
                  if (!service.isAuthenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Sign in to report hazards"),
                        action: SnackBarAction(
                          label: "Sign in",
                          onPressed: () {
                            Navigator.of(context).pushNamed("/login");
                          },
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReportHazardScreen(),
                    ),
                  );
                },
                mini: isMapNavigating,
                tooltip: "Report hazard",
                child: const Icon(Icons.add_alert),
              )
              : null,
    );
  }
}

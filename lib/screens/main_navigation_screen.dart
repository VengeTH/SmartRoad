import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "map/map_screen.dart";
import "feed/feed_screen.dart";
import "routes/routes_screen.dart";
import "profile/profile_screen.dart";
import "report/report_hazard_screen.dart";
import "../../providers/navigation_provider.dart";

/// * Main navigation screen with bottom navigation bar
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});
  
  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
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
    
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(navigationTabProvider.notifier).switchToTab(index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: "Feed",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: "Routes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton.extended(
              heroTag: "report_hazard_fab",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReportHazardScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_alert),
              label: const Text("Report"),
            )
          : null,
    );
  }
}


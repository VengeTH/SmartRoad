import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
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

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const MapScreen(),
    const FeedScreen(),
    const ProfileScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
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
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
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


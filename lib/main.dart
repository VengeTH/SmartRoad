import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/config/supabase_config.dart";
import "core/theme/app_theme.dart";
import "screens/map_screen.dart";
import "screens/feed_screen.dart";
import "screens/profile_screen.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // * Initialize Supabase
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }

  runApp(
    const ProviderScope(
      child: SmartRoadApp(),
    ),
  );
}

/// * Main app widget
class SmartRoadApp extends StatelessWidget {
  const SmartRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SmartRoad",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainNavigationScreen(),
    );
  }
}

/// * Main navigation screen with bottom navigation bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MapScreen(),
    FeedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

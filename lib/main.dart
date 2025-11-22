import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/config/supabase_config.dart";
import "core/config/app_config.dart";
import "core/theme/app_theme.dart";
import "services/local_storage_service.dart";
import "screens/map_screen.dart";
import "screens/feed_screen.dart";
import "screens/profile_screen.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // * Add error handling for Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // * Suppress MissingPluginException for path_provider on web - this is expected
    if (details.exception.toString().contains("MissingPluginException") &&
        details.exception.toString().contains("path_provider")) {
      debugPrint("⚠️ path_provider plugin not available on web (this is expected)");
      debugPrint("💡 App will use SharedPreferences instead");
      return; // * Don't show error - this is normal on web
    }
    FlutterError.presentError(details);
    debugPrint("Flutter Error: ${details.exception}");
    debugPrint("Stack: ${details.stack}");
  };

  // * Initialize storage based on configuration
  try {
    if (AppConfig.useLocalStorage) {
      // * Initialize local storage
      // * This will use SharedPreferences on web, file system on mobile
      await LocalStorageService.instance.initialize();
      debugPrint("✅ Using Local Storage (No database required)");
    } else {
      // * Initialize Supabase
      try {
        await SupabaseConfig.initialize();
        debugPrint("✅ Using Supabase");
      } catch (e) {
        debugPrint("❌ Supabase initialization error: $e");
        debugPrint("💡 Tip: Set useLocalStorage = true in app_config.dart to use local storage");
      }
    }
  } on MissingPluginException catch (e) {
    // * Catch MissingPluginException - this is expected on web for path_provider
    debugPrint("⚠️ Plugin not available (this is normal on web): $e");
    debugPrint("💡 App will continue using SharedPreferences");
  } catch (e, stackTrace) {
    debugPrint("❌ Initialization error: $e");
    debugPrint("Stack: $stackTrace");
    // * Don't crash the app - continue with SharedPreferences as fallback
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
      // * Add error builder to catch rendering errors
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child ?? const SizedBox(),
        );
      },
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

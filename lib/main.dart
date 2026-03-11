import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:hive_flutter/hive_flutter.dart";
import "core/theme/app_theme.dart";
import "providers/navigation_provider.dart";
import "services/supabase_service.dart";
import "services/deep_link_service.dart";
import "services/offline_cache_service.dart";
import "services/notification_service.dart";
import "services/route_service.dart";
import "services/music_app_launcher_service.dart";
import "services/gtfs_service.dart";
import "services/location_service.dart";
import "providers/auth_provider.dart";
import "screens/auth/login_screen.dart";
import "screens/auth/signup_screen.dart";
import "screens/main_navigation_screen.dart";
import "screens/splash/splash_screen.dart";
import "widgets/music_app_picker_sheet.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  try {
    await SupabaseService().initialize();
    await RouteService().initialize();
    await OfflineCacheService().initialize();
    await NotificationService().initialize();
    await GTFSService().initializeHive();
    debugPrint("GTFS Hive initialized");
    // * Warm location cache early so location-driven screens render faster.
    unawaited(LocationService().warmUpLocation());
  } catch (e) {
    debugPrint("Initialization error: $e");
  }

  runApp(const ProviderScope(child: SmartRoadApp()));
}

class SmartRoadApp extends ConsumerStatefulWidget {
  const SmartRoadApp({super.key});

  @override
  ConsumerState<SmartRoadApp> createState() => _SmartRoadAppState();
}

class _SmartRoadAppState extends ConsumerState<SmartRoadApp> {
  bool _showSplash = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Uri? _pendingDeepLink;

  @override
  void initState() {
    super.initState();
    // * Show splash screen for 2-3 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
        _processPendingDeepLink();
      }
    });

    // * Start listening for app links (e.g., smartroad://map)
    DeepLinkService().start(onLink: _onDeepLink);
  }

  @override
  void dispose() {
    DeepLinkService().stop();
    super.dispose();
  }

  void _onDeepLink(Uri uri) {
    if (uri.scheme.trim().toLowerCase() != "smartroad") return;

    // * Avoid showing UI on top of the splash screen.
    if (_showSplash) {
      _pendingDeepLink = uri;
      return;
    }

    _pendingDeepLink = uri;
    _processPendingDeepLink();
  }

  void _processPendingDeepLink() {
    final uri = _pendingDeepLink;
    if (uri == null) return;
    _pendingDeepLink = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // * Normalize host/path so both `smartroad://music` and `smartroad:///music` work.
      final host = uri.host.trim().toLowerCase();
      final segments =
          uri.pathSegments.map((s) => s.trim().toLowerCase()).toList();

      final primary =
          host.isNotEmpty ? host : (segments.isNotEmpty ? segments[0] : "");
      final secondary =
          host.isNotEmpty
              ? (segments.isNotEmpty ? segments[0] : "")
              : (segments.length > 1 ? segments[1] : "");

      if (primary == "map") {
        ref.read(navigationTabProvider.notifier).switchToMap();
        return;
      }

      if (primary == "music") {
        // * Ensure the map tab is visible (music chip lives there).
        ref.read(navigationTabProvider.notifier).switchToMap();

        if (secondary == "open") {
          final launcher = MusicAppLauncherService();
          final defaultApp = await launcher.getDefaultInstalledMusicApp();
          if (defaultApp != null) {
            await launcher.openMusicApp(defaultApp);
          }
          return;
        }

        final context = _navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await MusicAppPickerSheet.show(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // * Show splash screen first
    if (_showSplash) {
      return MaterialApp(
        title: "SmartRoad",
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        home: const SplashScreen(),
      );
    }

    return MaterialApp(
      title: "SmartRoad",
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const MainNavigationScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading:
            () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
        error:
            (error, stack) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text("Error: $error"),
                  ],
                ),
              ),
            ),
      ),
      routes: {
        "/login": (context) => const LoginScreen(),
        "/signup": (context) => const SignUpScreen(),
      },
    );
  }
}

import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "dart:ui";
import "core/theme/app_theme.dart";
import "core/config/env.dart";
import "services/supabase_service.dart";
import "services/offline_cache_service.dart";
import "services/notification_service.dart";
import "providers/auth_provider.dart";
import "screens/auth/login_screen.dart";
import "screens/auth/signup_screen.dart";
import "screens/main_navigation_screen.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // * Setup error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint("Flutter Error: ${details.exception}");
      debugPrint("Stack: ${details.stack}");
    }
  };
  
  // * Handle errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Platform Error: $error");
    debugPrint("Stack: $stack");
    return true;
  };
  
  // * Get service instance FIRST (demo mode is set in constructor if needed)
  // * This must happen before any providers are created
  final supabaseService = SupabaseService();
  
  // * Ensure demo mode is set if Supabase isn't configured
  if (!supabaseService.isDemoMode && !Env.validate()) {
    supabaseService.enableDemoMode();
  }
  
  // * Initialize services
  // * Note: Demo mode is already set in constructor if Supabase isn't configured
  await supabaseService.initialize();
  
  // * Only initialize other services if not in demo mode
  if (!supabaseService.isDemoMode) {
  try {
    await OfflineCacheService().initialize();
    await NotificationService().initialize();
  } catch (e) {
      debugPrint("Warning: Some services failed to initialize: $e");
    }
  } else {
    debugPrint("✓ Demo mode enabled - running without Supabase");
  }
  
  runApp(
    const ProviderScope(
      child: SmartRoadApp(),
    ),
  );
}

class SmartRoadApp extends ConsumerWidget {
  const SmartRoadApp({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return MaterialApp(
      title: "SmartRoad",
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, widget) {
        // * Custom error widget for build phase errors
        Widget error = Container(
          color: AppTheme.backgroundColor,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  "Something went wrong",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Please try again",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
        
        if (widget is Scaffold || widget is Navigator) {
          error = Scaffold(body: Center(child: error));
        }
        
        ErrorWidget.builder = (errorDetails) => error;
        
        if (widget != null) return widget;
        throw StateError("widget is null");
      },
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const MainNavigationScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        error: (error, stack) => Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                const SizedBox(height: 16),
                  Text(
                    "Error loading app",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // * Try to reload
                      runApp(
                        const ProviderScope(
                          child: SmartRoadApp(),
                        ),
                      );
                    },
                    child: const Text("Retry"),
                  ),
              ],
              ),
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

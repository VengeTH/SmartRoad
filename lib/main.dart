import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
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
  
  // * Initialize services
  try {
    await SupabaseService().initialize();
    await OfflineCacheService().initialize();
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("Initialization error: $e");
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
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const MainNavigationScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

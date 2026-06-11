import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../services/supabase_service.dart";
import "../../models/smartroad_user.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_theme.dart";
import "../../providers/auth_provider.dart";
import "../main_navigation_screen.dart";

/// * Premium login screen with animations and branding
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _emailController.text = AppConstants.demoEmail;

    // * Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    // * Auto-focus email field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    // * Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    // * Add haptic feedback
    HapticFeedback.mediumImpact();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await SupabaseService().signIn(email, password);

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    const MainNavigationScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text("Login failed: ${e.toString()}")),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDemoLogin() async {
    // * Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final service = SupabaseService();

      // * Check if in demo mode
      if (service.isDemoMode) {
        service.markDemoAuthenticated();

        // * Create a demo user
        final demoUser = SmartRoadUser(
          id: SupabaseService.demoUserId,
          email: AppConstants.demoEmail,
          name: "Demo User",
          createdAt: DateTime.now(),
        );

        // * Set demo user in state
        ref.read(demoUserStateProvider.notifier).state = demoUser;

        // * Small delay for better UX
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const MainNavigationScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      } else {
        // * Regular login
        await service.signIn(AppConstants.demoEmail, AppConstants.demoPassword);

        if (mounted) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const MainNavigationScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      }
    } catch (e) {
      // * Check if it's the special demo mode exception
      if (e.toString().contains("DEMO_MODE_LOGIN")) {
        // * This shouldn't happen, but handle it just in case
        SupabaseService().markDemoAuthenticated();
        final demoUser = SmartRoadUser(
          id: SupabaseService.demoUserId,
          email: AppConstants.demoEmail,
          name: "Demo User",
          createdAt: DateTime.now(),
        );
        ref.read(demoUserStateProvider.notifier).state = demoUser;

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const MainNavigationScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      } else {
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Demo login failed: ${e.toString()}")),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    // * Dismiss keyboard
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final service = SupabaseService();
    if (service.isDemoMode) {
      service.clearDemoAuthentication();
      ref.read(demoUserStateProvider.notifier).state = null;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _showDemoCredentialsDialog() async {
    // * Keep the login screen compact; show demo details in a modal instead of expanding the page height.
    if (!mounted) return;

    HapticFeedback.selectionClick();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.infoColor),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                "Demo Account",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Use these credentials to explore SmartRoad in demo mode.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              const _DemoCredentialRow(
                icon: Icons.email_outlined,
                label: "Email",
                value: AppConstants.demoEmail,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              const _DemoCredentialRow(
                icon: Icons.lock_outline,
                label: "Password",
                value: AppConstants.demoPassword,
                isPassword: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 980;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompactHeight = constraints.maxHeight < 760;
                final horizontalPadding =
                    isWide ? AppTheme.spacingXL : AppTheme.spacingLG;
                final verticalPadding =
                    isCompactHeight ? AppTheme.spacingMD : AppTheme.spacingXL;

                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child:
                              isWide
                                  ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: _buildStoryPanel(
                                          theme,
                                          compact: isCompactHeight,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingXL),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 520,
                                        ),
                                        child: _buildLoginCard(
                                          theme,
                                          isWide: true,
                                          compact: isCompactHeight,
                                          showHeader: false,
                                        ),
                                      ),
                                    ],
                                  )
                                  : ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 520,
                                    ),
                                    child: _buildLoginCard(
                                      theme,
                                      isWide: false,
                                      compact: isCompactHeight,
                                      showHeader: true,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryPanel(ThemeData theme, {required bool compact}) {
    final sectionSpacing = compact ? AppTheme.spacingLG : AppTheme.spacingXL;
    final features = [
      const _StoryFeature(
        icon: Icons.warning_amber_rounded,
        title: "Realtime hazards",
        subtitle: "Community reports with automatic freshness checks.",
        iconColor: AppTheme.warningColor,
      ),
      const _StoryFeature(
        icon: Icons.alt_route_rounded,
        title: "PH-aware routing",
        subtitle: "Tolls, restrictions, and local traffic rules in mind.",
        iconColor: AppTheme.brandAccentColor,
      ),
      const _StoryFeature(
        icon: Icons.groups_2_outlined,
        title: "Built for teams",
        subtitle: "Give enforcers and commuters the same live context.",
        iconColor: AppTheme.infoColor,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(
        compact ? AppTheme.spacingLG : AppTheme.spacingXL,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.brandAccentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  "THE HEEDFUL",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandAccentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                "SmartRoad",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            "Report hazards, guide commuters, and showcase NCR's attentiveness.",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            "A calm, modern safety layer for everyday navigation.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: const [
              _StoryChip(label: "Realtime hazard board"),
              _StoryChip(label: "PH-specific routing"),
              _StoryChip(label: "Community first"),
            ],
          ),
          SizedBox(height: sectionSpacing),
          ...features.take(compact ? 2 : features.length),
          if (!compact) ...[
            SizedBox(height: sectionSpacing),
            Row(
              children: [
                _StoryStat(value: "14 cities", label: "Piloting across NCR"),
                const SizedBox(width: AppTheme.spacingXL),
                _StoryStat(value: "1200+", label: "Hazards resolved"),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            "Be Heedful on the Road",
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary.withOpacity(0.9),
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(
    ThemeData theme, {
    required bool isWide,
    required bool compact,
    required bool showHeader,
  }) {
    final buttonVerticalPadding =
        compact ? AppTheme.spacingSM : AppTheme.spacingMD;
    final sectionSpacing = compact ? AppTheme.spacingSM : AppTheme.spacingMD;

    return Form(
      key: _formKey,
      child: Container(
        padding: EdgeInsets.all(
          compact ? AppTheme.spacingMD : AppTheme.spacingLG,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: AppTheme.borderColor, width: 1),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandAccentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      "THE HEEDFUL",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandAccentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Text(
                    "SmartRoad",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),
            ],
            Text(
              "Sign in",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              "Welcome back! Access The Heedful control room.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: sectionSpacing),
            // * Email Field
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
                suffixIcon:
                    _emailController.text.isNotEmpty
                        ? IconButton(
                          tooltip: "Clear email",
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            _emailController.clear();
                            setState(() {});
                          },
                        )
                        : null,
              ),
              onFieldSubmitted: (_) {
                _passwordFocusNode.requestFocus();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter your email";
                }
                if (!value.contains("@")) {
                  return "Please enter a valid email";
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: sectionSpacing),
            // * Password Field
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _handleLogin();
                }
              },
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? "Show password" : "Hide password",
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter your password";
                }
                if (value.length < 6) {
                  return "Password must be at least 6 characters";
                }
                return null;
              },
            ),
            SizedBox(height: sectionSpacing),
            // * Login Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandAccentColor,
                foregroundColor: const Color(0xFF0F0F0F),
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingSM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                elevation: 4,
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
            ),
            SizedBox(height: sectionSpacing),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleDemoLogin,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: buttonVerticalPadding,
                      ),
                      side: BorderSide(
                        color: AppTheme.brandAccentColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text(
                      "Demo Mode",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: buttonVerticalPadding,
                      ),
                    ),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text(
                      "Guest",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextButton.icon(
              onPressed: _isLoading ? null : _showDemoCredentialsDialog,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text(
                "Demo credentials",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              "Be Heedful on the Road",
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary.withOpacity(0.85),
                fontStyle: FontStyle.italic,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sectionSpacing),
            // * Legal links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed("/legal/privacy");
                  },
                  child: Text(
                    "Privacy Policy",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandAccentColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  "  ·  ",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed("/legal/terms");
                  },
                  child: Text(
                    "Terms of Service",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandAccentColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: sectionSpacing),
            // * Sign Up Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed("/signup");
                  },
                  child: const Text("Sign up"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// * Subtle, modern background used by the auth screens (web + mobile).
class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.backgroundColor.withOpacity(0.9),
              const Color(0xFF0B1224),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// * Story chip widget
class _StoryChip extends StatelessWidget {
  final String label;

  const _StoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}

/// * Story bullet widget
/// * Compact feature row used on the auth story panel.
class _StoryFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const _StoryFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: iconColor.withOpacity(0.25), width: 1),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// * Small stat used on the auth story panel.
class _StoryStat extends StatelessWidget {
  final String value;
  final String label;

  const _StoryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: AppTheme.borderColor.withOpacity(0.9),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// * Demo credential row widget
class _DemoCredentialRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPassword;

  const _DemoCredentialRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = isPassword ? "•" * value.length : value;

    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
        ),
        Expanded(
          child: SelectableText(
            displayValue,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          tooltip: "Copy $label",
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("$label copied to clipboard"),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(
            Icons.copy_rounded,
            size: 18,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

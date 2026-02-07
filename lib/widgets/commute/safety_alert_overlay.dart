import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";

/// * Safety Alert Overlay
/// * Full-screen alert when user is detected off-route
/// * V2: Configurable grace period, improved UI
class SafetyAlertOverlay extends StatefulWidget {
  final String destinationName;
  final double offRouteDistance;
  final int gracePeriodSeconds;
  final bool isNightMode;
  final VoidCallback onImSafe;
  final VoidCallback onSendAlert;

  const SafetyAlertOverlay({
    super.key,
    required this.destinationName,
    required this.offRouteDistance,
    this.gracePeriodSeconds = 30,
    this.isNightMode = false,
    required this.onImSafe,
    required this.onSendAlert,
  });

  @override
  State<SafetyAlertOverlay> createState() => _SafetyAlertOverlayState();
}

class _SafetyAlertOverlayState extends State<SafetyAlertOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  late Animation<double> _pulseAnimation;
  
  Timer? _vibrationTimer;
  
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    
    _remainingSeconds = widget.gracePeriodSeconds;
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.gracePeriodSeconds),
    )..forward();
    
    // * Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        // * Intensify haptic as countdown gets lower
        if (_remainingSeconds <= 10) {
          HapticFeedback.heavyImpact();
        } else if (_remainingSeconds <= 20) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      } else {
        timer.cancel();
        widget.onSendAlert();
      }
    });
    
    // * Start vibration pattern
    _startVibration();
  }

  void _startVibration() {
    HapticFeedback.heavyImpact();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    _vibrationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Color _getCountdownColor() {
    if (_remainingSeconds <= 10) return Colors.red;
    if (_remainingSeconds <= 20) return Colors.orange;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remainingSeconds <= 10;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Colors.orange.shade800,
              Colors.deepOrange.shade900,
              const Color(0xFF4A1500),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Column(
              children: [
                // * Night mode indicator
                if (widget.isNightMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.nightlight_round,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          "Night Mode Active (stricter detection)",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const Spacer(),
                
                // * Animated warning icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXL * 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXXL),
                
                // * Title
                Text(
                  "Safety Alert",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Description
                Text(
                  "You appear to be ${widget.offRouteDistance.toStringAsFixed(1)} km away from your expected route.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingSM),
                
                Text(
                  "Destination: ${widget.destinationName}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingXXL),
                
                // * Countdown
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLG,
                    vertical: AppTheme.spacingMD,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent 
                        ? Colors.red.withOpacity(0.3) 
                        : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: isUrgent 
                          ? Colors.red.withOpacity(0.5) 
                          : Colors.white.withOpacity(0.2),
                      width: isUrgent ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isUrgent ? "URGENT: Sending alert in" : "Auto-sending alert in",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          color: _getCountdownColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: isUrgent ? 32 : 24,
                        ),
                        child: Text("$_remainingSeconds seconds"),
                      ),
                      
                      // * Progress bar
                      const SizedBox(height: AppTheme.spacingSM),
                      AnimatedBuilder(
                        animation: _countdownController,
                        builder: (context, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _countdownController.value,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getCountdownColor(),
                              ),
                              minHeight: 4,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * GPS disclaimer
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.6),
                        size: 18,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          "This could be a GPS error, U-turn, or traffic detour.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // * Big "I'm okay" button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _countdownTimer?.cancel();
                      widget.onImSafe();
                    },
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text(
                      "I'm Okay",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXL),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Send alert now button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _countdownTimer?.cancel();
                      widget.onSendAlert();
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text("Send Alert Now"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingLG),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// * Helper widget to animate based on animation controller
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedBuilderWidget(
      listenable: animation,
      builder: builder,
      child: child,
    );
  }
}

class _AnimatedBuilderWidget extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const _AnimatedBuilderWidget({
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}


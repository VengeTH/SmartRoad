import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";

/// * Safety Alert Overlay
/// * Full-screen alert when user is detected off-route
class SafetyAlertOverlay extends StatefulWidget {
  final String destinationName;
  final double offRouteDistance;
  final VoidCallback onImSafe;
  final VoidCallback onSendAlert;

  const SafetyAlertOverlay({
    super.key,
    required this.destinationName,
    required this.offRouteDistance,
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
  
  // * Auto-send countdown (30 seconds)
  static const int _autoSendSeconds = 30;
  int _remainingSeconds = _autoSendSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _countdownController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _autoSendSeconds),
    )..forward();
    
    // * Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds <= 10) {
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

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLG,
                    vertical: AppTheme.spacingMD,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Auto-sending alert in",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        "$_remainingSeconds seconds",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // * Buttons
                Row(
                  children: [
                    // * I'm safe button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _countdownTimer?.cancel();
                          widget.onImSafe();
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("I'm Safe"),
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
                    
                    const SizedBox(width: AppTheme.spacingMD),
                    
                    // * Send alert button
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          _countdownTimer?.cancel();
                          widget.onSendAlert();
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text("Send Alert"),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepOrange.shade800,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Info text
                Text(
                  "If you're in danger, the alert will be sent automatically.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
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


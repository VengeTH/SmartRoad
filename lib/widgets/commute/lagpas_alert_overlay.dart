import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";

/// * Lagpas Alert Overlay
/// * Full-screen "LAGPAS KA NA!" alert with hold-to-dismiss
class LagpasAlertOverlay extends StatefulWidget {
  final String destinationName;
  final VoidCallback onDismiss;

  const LagpasAlertOverlay({
    super.key,
    required this.destinationName,
    required this.onDismiss,
  });

  @override
  State<LagpasAlertOverlay> createState() => _LagpasAlertOverlayState();
}

class _LagpasAlertOverlayState extends State<LagpasAlertOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _dismissController;
  
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _shakeAnimation;
  late Animation<double> _dismissProgress;
  
  bool _isDismissing = false;
  Timer? _vibrationTimer;
  
  static const Duration _dismissHoldDuration = Duration(seconds: 2);
  
  @override
  void initState() {
    super.initState();
    
    // * Pulse animation for the ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // * Shake animation for the text
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);
    
    _shakeAnimation = Tween<Offset>(
      begin: const Offset(-0.02, 0),
      end: const Offset(0.02, 0),
    ).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    
    // * Dismiss progress animation
    _dismissController = AnimationController(
      vsync: this,
      duration: _dismissHoldDuration,
    );
    
    _dismissProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.linear),
    );
    
    _dismissController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onDismiss();
      }
    });
    
    // * Start vibration pattern
    _startVibration();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _dismissController.dispose();
    _vibrationTimer?.cancel();
    super.dispose();
  }
  
  void _startVibration() {
    // * Initial heavy vibration
    HapticFeedback.heavyImpact();
    
    // * Repeat vibration every 2 seconds
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isDismissing) {
        HapticFeedback.heavyImpact();
      }
    });
  }
  
  void _onDismissStart() {
    setState(() => _isDismissing = true);
    _dismissController.forward();
    HapticFeedback.lightImpact();
  }
  
  void _onDismissEnd() {
    if (_dismissController.isAnimating) {
      _dismissController.reverse();
    }
    setState(() => _isDismissing = false);
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
              AppTheme.errorColor,
              const Color(0xFF8B0000), // Dark red
              const Color(0xFF4A0000), // Darker red
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // * Animated warning icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXL * 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXXL),
              
              // * Shaking "LAGPAS KA NA!" text
              SlideTransition(
                position: _shakeAnimation,
                child: Text(
                  "LAGPAS KA NA!",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),
              
              // * Destination name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
                child: Text(
                  "You passed ${widget.destinationName}",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXXL * 2),
              
              // * Hold to dismiss button
              GestureDetector(
                onTapDown: (_) => _onDismissStart(),
                onTapUp: (_) => _onDismissEnd(),
                onTapCancel: _onDismissEnd,
                child: ListenableBuilder(
                  listenable: _dismissProgress,
                  builder: (context, child) {
                    return Container(
                      width: 200,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: Stack(
                        children: [
                          // * Progress fill
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull - 2),
                            child: LinearProgressIndicator(
                              value: _dismissProgress.value,
                              minHeight: 56,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          
                          // * Button content
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isDismissing ? Icons.hourglass_top : Icons.touch_app,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingSM),
                                Text(
                                  _isDismissing ? "Hold..." : "Hold to dismiss",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),
              
              // * Helper text
              Text(
                "Hold for 2 seconds to dismiss",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


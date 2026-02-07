import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";

/// * Lagpas Recovery Overlay
/// * Full-screen alert when user has passed their destination
/// * Shows helpful recovery hints in Filipino and English
class LagpasRecoveryOverlay extends StatefulWidget {
  final String destinationName;
  final double overshootDistance;
  final String recoveryHint;
  final VoidCallback onDismiss;
  final VoidCallback onStopCommute;

  const LagpasRecoveryOverlay({
    super.key,
    required this.destinationName,
    required this.overshootDistance,
    required this.recoveryHint,
    required this.onDismiss,
    required this.onStopCommute,
  });

  @override
  State<LagpasRecoveryOverlay> createState() => _LagpasRecoveryOverlayState();
}

class _LagpasRecoveryOverlayState extends State<LagpasRecoveryOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    // * Start vibration pattern
    _startVibration();
  }

  void _startVibration() {
    HapticFeedback.heavyImpact();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()} m";
    }
    return "${(meters / 1000).toStringAsFixed(1)} km";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFFDC2626), // Red
              Color(0xFFB91C1C),
              Color(0xFF7F1D1D),
            ],
            stops: [0.0, 0.5, 1.0],
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
                      Icons.wrong_location_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXXL),
                
                // * Title
                Text(
                  "LAGPAS KA NA!",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingSM),
                
                Text(
                  "You passed your stop!",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // * Overshoot distance
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
                        "You're now",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        _formatDistance(widget.overshootDistance),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "past ${widget.destinationName}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                // * Recovery hint
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.tips_and_updates_rounded,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: AppTheme.spacingSM),
                            Text(
                              "How to get back:",
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMD),
                        
                        // * Filipino hint
                        _buildHintRow(
                          context,
                          "FIL",
                          "Bumaba ka sa susunod, tumawid, sakay pabalik",
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        
                        // * English hint
                        _buildHintRow(
                          context,
                          "ENG",
                          "Get off at next stop, cross street, ride back",
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // * Buttons
                Row(
                  children: [
                    // * Got it button
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _vibrationTimer?.cancel();
                          widget.onDismiss();
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Got it!"),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade800,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingMD),
                    
                    // * Stop tracking button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _vibrationTimer?.cancel();
                          widget.onStopCommute();
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text("Stop"),
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
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Info text
                Text(
                  "Don't panic! This happens to everyone.",
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
  
  Widget _buildHintRow(BuildContext context, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}


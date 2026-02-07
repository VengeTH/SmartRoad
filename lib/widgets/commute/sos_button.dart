import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";

/// * SOS Button Widget
/// * A prominent button for manual emergency alerts
/// * Requires long-press to prevent accidental activation
class SosButton extends StatefulWidget {
  final VoidCallback onSOS;
  final bool isCompact;

  const SosButton({
    super.key,
    required this.onSOS,
    this.isCompact = false,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  bool _isHolding = false;
  Timer? _activationTimer;
  
  static const Duration _holdDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _activationTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isHolding = true);
    _progressController.forward();
    
    // * Haptic feedback at start
    HapticFeedback.selectionClick();
    
    // * Start activation timer
    _activationTimer = Timer(_holdDuration, () {
      if (_isHolding) {
        HapticFeedback.heavyImpact();
        _showConfirmationDialog();
      }
    });
  }

  void _onTapUp(TapUpDetails details) {
    _cancelHold();
  }

  void _onTapCancel() {
    _cancelHold();
  }

  void _cancelHold() {
    setState(() => _isHolding = false);
    _progressController.reverse();
    _activationTimer?.cancel();
  }

  void _showConfirmationDialog() {
    _cancelHold();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            const Text(
              "Send SOS?",
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "This will immediately send an emergency alert to your saved contacts with your current location.\n\nAre you sure you want to proceed?",
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSOS();
            },
            icon: const Icon(Icons.sos, size: 18),
            label: const Text("Send SOS"),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactButton();
    }
    return _buildFullButton();
  }

  Widget _buildFullButton() {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: -1.5708, // -90 degrees
                endAngle: 1.5708 + (6.2832 * _progressController.value),
                colors: [
                  _isHolding ? Colors.red : Colors.transparent,
                  Colors.transparent,
                ],
                stops: [_progressController.value, _progressController.value],
              ),
            ),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isHolding 
                    ? Colors.red.shade700 
                    : Colors.red.withOpacity(0.15),
                border: Border.all(
                  color: Colors.red.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: _isHolding
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.sos,
                color: _isHolding ? Colors.white : Colors.red,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactButton() {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.red.withOpacity(_progressController.value),
                  Colors.transparent,
                ],
                stops: [_progressController.value, _progressController.value],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSM,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: _isHolding 
                    ? Colors.red.shade700 
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(
                  color: Colors.red.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sos,
                    color: _isHolding ? Colors.white : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "SOS",
                    style: TextStyle(
                      color: _isHolding ? Colors.white : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    return AnimatedBuilder2(
      listenable: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}


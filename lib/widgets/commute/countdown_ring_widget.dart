import "dart:math" as math;

import "package:flutter/material.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";

/// * Countdown Ring Widget
/// * Displays a circular progress ring showing commute progress
class CountdownRingWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final CommuteStatus status;
  final String distance;
  final String eta;
  final double size;
  final double strokeWidth;

  const CountdownRingWidget({
    super.key,
    required this.progress,
    required this.status,
    required this.distance,
    required this.eta,
    this.size = 280,
    this.strokeWidth = 12,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = _getRingColor();
    final backgroundColor = ringColor.withOpacity(0.15);
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // * Background ring
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: 1.0,
              color: backgroundColor,
              strokeWidth: strokeWidth,
            ),
          ),
          
          // * Progress ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value,
                  color: ringColor,
                  strokeWidth: strokeWidth,
                  useGradient: true,
                  gradientColors: _getGradientColors(),
                ),
              );
            },
          ),
          
          // * Inner content
          Container(
            width: size - strokeWidth * 4,
            height: size - strokeWidth * 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: ringColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // * Status icon
                Icon(
                  _getStatusIcon(),
                  color: ringColor,
                  size: 28,
                ),
                const SizedBox(height: AppTheme.spacingSM),
                
                // * Distance text
                Text(
                  distance,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                
                // * "to go" label
                Text(
                  "to go",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * ETA chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: ringColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: ringColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: ringColor,
                        size: 14,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        eta,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ringColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // * Progress percentage badge
          Positioned(
            bottom: strokeWidth,
            right: strokeWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSM,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: ringColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "${(progress * 100).round()}%",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRingColor() {
    switch (status) {
      case CommuteStatus.idle:
        return AppTheme.textSecondary;
      case CommuteStatus.active:
        return AppTheme.successColor;
      case CommuteStatus.approaching:
        return AppTheme.warningColor;
      case CommuteStatus.arrived:
        return AppTheme.successColor;
      case CommuteStatus.passed:
        return AppTheme.errorColor;
      case CommuteStatus.danger:
        return AppTheme.errorColor;
    }
  }

  List<Color> _getGradientColors() {
    switch (status) {
      case CommuteStatus.idle:
        return [AppTheme.textSecondary, AppTheme.textSecondary];
      case CommuteStatus.active:
        return [AppTheme.successColor, AppTheme.primaryColor];
      case CommuteStatus.approaching:
        return [AppTheme.warningColor, Colors.orange];
      case CommuteStatus.arrived:
        return [AppTheme.successColor, Colors.lightGreen];
      case CommuteStatus.passed:
      case CommuteStatus.danger:
        return [AppTheme.errorColor, Colors.redAccent];
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case CommuteStatus.idle:
        return Icons.place_outlined;
      case CommuteStatus.active:
        return Icons.commute;
      case CommuteStatus.approaching:
        return Icons.notifications_active_rounded;
      case CommuteStatus.arrived:
        return Icons.check_circle_rounded;
      case CommuteStatus.passed:
        return Icons.warning_rounded;
      case CommuteStatus.danger:
        return Icons.emergency_rounded;
    }
  }
}

/// * Custom painter for the ring
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool useGradient;
  final List<Color>? gradientColors;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.useGradient = false,
    this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    if (useGradient && gradientColors != null && gradientColors!.length >= 2) {
      paint.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: gradientColors!,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      paint.color = color;
    }
    
    // * Draw arc starting from top (-90 degrees)
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}


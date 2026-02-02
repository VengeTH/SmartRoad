import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";

/// * Arrival Celebration Widget
/// * Shows confetti and success animation when user arrives at destination
class ArrivalCelebration extends StatefulWidget {
  final String destinationName;
  final VoidCallback onDismiss;

  const ArrivalCelebration({
    super.key,
    required this.destinationName,
    required this.onDismiss,
  });

  @override
  State<ArrivalCelebration> createState() => _ArrivalCelebrationState();
}

class _ArrivalCelebrationState extends State<ArrivalCelebration>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    // * Scale animation for the checkmark
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );
    
    // * Confetti animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    // * Generate particles
    _generateParticles();
    
    // * Start animations
    _scaleController.forward();
    _confettiController.forward();
    
    // * Haptic feedback
    HapticFeedback.heavyImpact();
  }

  void _generateParticles() {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      Colors.pink,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
    ];
    
    for (int i = 0; i < 50; i++) {
      _particles.add(_ConfettiParticle(
        color: colors[_random.nextInt(colors.length)],
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.3,
        size: 4 + _random.nextDouble() * 8,
        velocity: 2 + _random.nextDouble() * 3,
        rotation: _random.nextDouble() * 360,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
      ));
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      child: Stack(
        children: [
          // * Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),
          
          // * Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // * Animated checkmark
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.successColor,
                            Colors.lightGreen,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXXL),
                  
                  // * Title
                  Text(
                    "You've arrived!",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingSM),
                  
                  // * Destination name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
                    child: Text(
                      "Welcome to ${widget.destinationName}",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXXL * 2),
                  
                  // * Dismiss button
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onDismiss();
                    },
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text("Done"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXXL,
                        vertical: AppTheme.spacingMD,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// * Confetti particle data
class _ConfettiParticle {
  final Color color;
  final double x;
  final double y;
  final double size;
  final double velocity;
  final double rotation;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.color,
    required this.x,
    required this.y,
    required this.size,
    required this.velocity,
    required this.rotation,
    required this.rotationSpeed,
  });
}

/// * Confetti painter
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity((1 - progress).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      
      final x = particle.x * size.width;
      final y = (particle.y + progress * particle.velocity) * size.height;
      
      if (y > size.height) continue;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((particle.rotation + progress * particle.rotationSpeed * 360) * math.pi / 180);
      
      // * Draw rectangle confetti
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}


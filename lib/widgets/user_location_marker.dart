import "dart:math" as math;

import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";

/// * User location marker that can rotate based on heading (Google Maps-like).
/// *
/// * If [headingDegrees] is null or invalid, the marker renders without rotation.
class UserLocationMarker extends StatelessWidget {
  final double? headingDegrees;
  final double? mapRotationDegrees;
  final IconData avatarIcon;

  const UserLocationMarker({
    super.key,
    required this.headingDegrees,
    required this.mapRotationDegrees,
    required this.avatarIcon,
  });

  double? _toRadians(double? degrees) {
    if (degrees == null) return null;
    if (!degrees.isFinite) return null;
    final normalized = _normalizeDegrees(degrees);
    return normalized * (math.pi / 180.0);
  }

  double _normalizeDegrees(double degrees) {
    var normalized = degrees % 360.0;
    if (normalized < 0) normalized += 360.0;
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final heading = headingDegrees;
    final mapRotation = mapRotationDegrees;

    // * If the map itself is rotated (navigation mode), rotate the icon relative
    // * to the map so it still points "forward" on screen.
    final effectiveHeadingDegrees = () {
      if (heading == null || !heading.isFinite) {
        return null;
      }
      if (mapRotation == null || !mapRotation.isFinite) {
        return _normalizeDegrees(heading);
      }
      return _normalizeDegrees(heading - mapRotation);
    }();

    final angle = _toRadians(effectiveHeadingDegrees);

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Transform.rotate(
            angle: angle ?? 0,
            child: Icon(
              avatarIcon,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}


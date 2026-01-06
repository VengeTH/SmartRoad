import "package:latlong2/latlong.dart";

/// * Polyline smoothing utilities for route preview/editing.
/// *
/// * Why this exists:
/// * - Fallback routes (when GraphHopper is unavailable) used to interpolate with straight segments.
/// * - Control-point route editing also used straight interpolation, producing sharp corners.
/// *
/// * This file provides a small, dependency-free Catmull–Rom spline implementation that:
/// * - Passes through all waypoints (start → control points → end)
/// * - Produces a visually smooth curve (no sharp kinks)
/// * - Adapts sample density based on segment length
class PolylineSmoothing {
  static const Distance _distance = Distance();

  /// * Build a smooth polyline (Catmull–Rom spline) that passes through [waypoints].
  /// *
  /// * Notes:
  /// * - If [waypoints] has fewer than 2 points, it returns the input unchanged.
  /// * - If [waypoints] has exactly 2 points, the result is a straight line with dense sampling.
  /// * - For 3+ points, the curve is smooth across joints.
  static List<LatLng> catmullRomThroughWaypoints(
    List<LatLng> waypoints, {
    double targetSpacingMeters = 5.0,
    int minPointsPerSegment = 8,
    int maxPointsPerSegment = 120,
  }) {
    // * Defensive parameter validation (keeps app stable even if called incorrectly).
    final safeSpacingMeters = targetSpacingMeters.isFinite && targetSpacingMeters > 0
        ? targetSpacingMeters
        : 5.0;
    final safeMin = minPointsPerSegment.clamp(2, 10000);
    final safeMax = mathMax(maxPointsPerSegment, safeMin + 1).clamp(3, 10000);

    if (waypoints.length < 2) return List<LatLng>.from(waypoints);

    // * For 2 points, we still sample densely so the displayed polyline looks consistent.
    if (waypoints.length == 2) {
      return _denselySampleLine(
        waypoints.first,
        waypoints.last,
        spacingMeters: safeSpacingMeters,
        minPoints: safeMin,
        maxPoints: safeMax,
      );
    }

    final result = <LatLng>[];
    final points = List<LatLng>.from(waypoints);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i - 1 >= 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      final segmentMeters = _distance.as(LengthUnit.Meter, p1, p2).abs();
      final samples = (segmentMeters / safeSpacingMeters)
          .round()
          .clamp(safeMin, safeMax);

      for (int j = 0; j <= samples; j++) {
        // * Avoid duplicating the first waypoint when stitching segments.
        if (i > 0 && j == 0) continue;

        final t = j / samples;
        final lat = _catmullRom(
          p0.latitude,
          p1.latitude,
          p2.latitude,
          p3.latitude,
          t,
        );
        final lon = _catmullRom(
          p0.longitude,
          p1.longitude,
          p2.longitude,
          p3.longitude,
          t,
        );

        // * Guard against NaN/Inf from pathological inputs.
        if (!lat.isFinite || !lon.isFinite) continue;
        result.add(LatLng(lat, lon));
      }
    }

    // * Ensure last waypoint is always included.
    if (result.isEmpty || result.last != waypoints.last) {
      result.add(waypoints.last);
    }

    return result;
  }

  /// * Catmull–Rom spline interpolation (uniform).
  /// *
  /// * Formula:
  /// *   0.5 * ((2 * p1) +
  /// *          (-p0 + p2) * t +
  /// *          (2*p0 - 5*p1 + 4*p2 - p3) * t^2 +
  /// *          (-p0 + 3*p1 - 3*p2 + p3) * t^3)
  static double _catmullRom(double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return 0.5 *
        ((2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
  }

  /// * Dense sampling for a straight segment.
  static List<LatLng> _denselySampleLine(
    LatLng from,
    LatLng to, {
    required double spacingMeters,
    required int minPoints,
    required int maxPoints,
  }) {
    final meters = _distance.as(LengthUnit.Meter, from, to).abs();
    final samples = (meters / spacingMeters).round().clamp(minPoints, maxPoints);

    final points = <LatLng>[];
    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      points.add(
        LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
      );
    }
    return points;
  }

  /// * Small helper because Dart's `math.max` requires importing dart:math.
  static int mathMax(int a, int b) => a > b ? a : b;
}


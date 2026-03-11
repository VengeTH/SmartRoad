/// * Structured commute guide content for the expanded "Commute guide" card.
/// * Built deterministically from GTFS itinerary or heuristic; AI may augment when quality is low.
class CommuteGuideData {
  /// * Where to board (Sasakay) — e.g. stop name + walk distance.
  final String whereToBoard;

  /// * What to take — vehicle/route description or ordered ride steps.
  final String whatToTake;

  /// * Estimated fare text — single value or range (e.g. "~₱45–₱65").
  final String estimatedFareText;

  /// * Distance and time summary.
  final String distanceAndTime;

  /// * Notes — transfer count, walking, or general tips.
  final String notes;

  /// * True when built from GTFS itinerary (high confidence).
  final bool isFromGtfs;

  /// * True when deterministic data is sufficient; AI fallback not needed.
  final bool qualityHigh;

  const CommuteGuideData({
    required this.whereToBoard,
    required this.whatToTake,
    required this.estimatedFareText,
    required this.distanceAndTime,
    required this.notes,
    required this.isFromGtfs,
    required this.qualityHigh,
  });
}

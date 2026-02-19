/// * Gate Access Log Model
/// * Represents a single gate scan/access event — the transaction record
import 'dart:convert';

/// * Pass mode enum for gate access
enum GatePassMode {
  locationBound, // * Valid only inside HOA geofence
  fullDay,       // * Valid all day after first scan
}

extension GatePassModeExtension on GatePassMode {
  String get value {
    switch (this) {
      case GatePassMode.locationBound:
        return 'location_bound';
      case GatePassMode.fullDay:
        return 'full_day';
    }
  }

  String get displayName {
    switch (this) {
      case GatePassMode.locationBound:
        return 'Location-Bound';
      case GatePassMode.fullDay:
        return 'Day Pass';
    }
  }

  String get description {
    switch (this) {
      case GatePassMode.locationBound:
        return 'Valid inside HOA premises only';
      case GatePassMode.fullDay:
        return 'Valid all day from entry until midnight';
    }
  }

  static GatePassMode fromString(String? value) {
    switch (value) {
      case 'full_day':
        return GatePassMode.fullDay;
      case 'location_bound':
      default:
        return GatePassMode.locationBound;
    }
  }
}

/// * Gate Access Log
/// * One entry per guard scan event — serves as the proof of payment/access
class GateAccessLog {
  final String id;
  final String? stickerId;
  final String hoaId;
  final String hoaName;
  final String userId;
  final String? scannedBy;    // * Guard user ID
  final DateTime scanTime;
  final bool accessGranted;
  final GatePassMode passMode;
  final String? notes;
  final DateTime createdAt;

  GateAccessLog({
    required this.id,
    this.stickerId,
    required this.hoaId,
    required this.hoaName,
    required this.userId,
    this.scannedBy,
    required this.scanTime,
    required this.accessGranted,
    this.passMode = GatePassMode.locationBound,
    this.notes,
    required this.createdAt,
  });

  factory GateAccessLog.fromJson(Map<String, dynamic> json) {
    // * hoaName may be joined from hoas table or passed separately
    final hoaData = json['hoas'] as Map<String, dynamic>?;
    final hoaName = (hoaData?['name'] as String?) ?? 
                    (json['hoa_name'] as String?) ?? 
                    'Unknown HOA';

    return GateAccessLog(
      id: json['id'] as String,
      stickerId: json['sticker_id'] as String?,
      hoaId: json['hoa_id'] as String,
      hoaName: hoaName,
      userId: json['user_id'] as String,
      scannedBy: json['scanned_by'] as String?,
      scanTime: DateTime.parse(json['scan_time'] as String).toLocal(),
      accessGranted: (json['access_granted'] as bool?) ?? false,
      passMode: GatePassModeExtension.fromString(json['pass_mode'] as String?),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (stickerId != null) 'sticker_id': stickerId,
      'hoa_id': hoaId,
      'user_id': userId,
      if (scannedBy != null) 'scanned_by': scannedBy,
      'scan_time': scanTime.toUtc().toIso8601String(),
      'access_granted': accessGranted,
      'pass_mode': passMode.value,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// * Encode as a local in-memory JSON string (for demo mode list)
  String toJsonString() => jsonEncode(toJson());

  /// * Human-readable time label
  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(scanTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${scanTime.day}/${scanTime.month}/${scanTime.year}';
  }

  /// * Formatted date/time string
  String get formattedDateTime {
    final h = scanTime.hour.toString().padLeft(2, '0');
    final m = scanTime.minute.toString().padLeft(2, '0');
    return '${scanTime.day}/${scanTime.month}/${scanTime.year} $h:$m';
  }
}

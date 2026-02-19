/// * HOA Day Pass Model
/// * Represents a one-day access pass purchased for a specific HOA and date
import 'gate_access_log.dart';

class HoaDayPass {
  final String id;
  final String userId;
  final String hoaId;
  final String hoaName;
  final DateTime validDate;    // * The calendar date this pass is valid for
  final GatePassMode passMode;
  final bool isActive;
  final DateTime purchasedAt;
  final DateTime createdAt;

  HoaDayPass({
    required this.id,
    required this.userId,
    required this.hoaId,
    required this.hoaName,
    required this.validDate,
    this.passMode = GatePassMode.fullDay,
    required this.isActive,
    required this.purchasedAt,
    required this.createdAt,
  });

  factory HoaDayPass.fromJson(Map<String, dynamic> json) {
    final hoaData = json['hoas'] as Map<String, dynamic>?;
    final hoaName = (hoaData?['name'] as String?) ??
                    (json['hoa_name'] as String?) ??
                    'Unknown HOA';

    return HoaDayPass(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      hoaId: json['hoa_id'] as String,
      hoaName: hoaName,
      validDate: DateTime.parse(json['valid_date'] as String),
      passMode: GatePassModeExtension.fromString(json['pass_mode'] as String?),
      isActive: (json['is_active'] as bool?) ?? true,
      purchasedAt: DateTime.parse(json['purchased_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'hoa_id': hoaId,
      'valid_date': '${validDate.year}-${validDate.month.toString().padLeft(2, '0')}-${validDate.day.toString().padLeft(2, '0')}',
      'pass_mode': passMode.value,
      'is_active': isActive,
      'purchased_at': purchasedAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// * Check if this pass is valid for today
  bool get isValidToday {
    if (!isActive) return false;
    final now = DateTime.now();
    return validDate.year == now.year &&
           validDate.month == now.month &&
           validDate.day == now.day;
  }

  /// * Formatted purchase time
  String get purchasedAtFormatted {
    final h = purchasedAt.hour.toString().padLeft(2, '0');
    final m = purchasedAt.minute.toString().padLeft(2, '0');
    return '${purchasedAt.day}/${purchasedAt.month}/${purchasedAt.year} $h:$m';
  }
}

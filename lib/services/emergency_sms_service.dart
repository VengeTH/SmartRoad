import "package:flutter/foundation.dart";
import "package:intl/intl.dart";
import "package:url_launcher/url_launcher.dart";

import "../models/commute_state.dart";

/// * Emergency SMS Service
/// * Handles sending SMS alerts to emergency contacts
/// * V2: Non-panic message format with better context
class EmergencySmsService {
  static final EmergencySmsService _instance = EmergencySmsService._internal();
  factory EmergencySmsService() => _instance;
  EmergencySmsService._internal();

  /// * User's display name (can be set by app)
  String? _userName;
  
  /// * Set the user's name for personalized messages
  void setUserName(String name) {
    _userName = name;
  }

  /// * Send emergency SMS to all contacts
  Future<bool> sendEmergencyAlert({
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    required String destinationName,
    String? customMessage,
    String? areaName,
  }) async {
    if (contacts.isEmpty) {
      debugPrint("[EmergencySmsService] WARNING: No emergency contacts configured");
      return false;
    }

    final mapsLink = _generateMapsLink(latitude, longitude);
    final message = customMessage ?? _generateDefaultMessage(
      userName: _userName,
      destinationName: destinationName,
      areaName: areaName,
      latitude: latitude,
      longitude: longitude,
      mapsLink: mapsLink,
    );

    bool anySent = false;
    
    for (final contact in contacts) {
      try {
        final success = await _sendSms(contact.phoneNumber, message);
        if (success) {
          anySent = true;
          debugPrint("[EmergencySmsService] OK: SMS sent to ${contact.name}");
        } else {
          debugPrint("[EmergencySmsService] ERROR: Failed to send to ${contact.name}");
        }
      } catch (e) {
        debugPrint("[EmergencySmsService] ERROR: Error sending to ${contact.name}: $e");
      }
    }

    return anySent;
  }

  /// * Send single SMS using url_launcher
  Future<bool> _sendSms(String phoneNumber, String message) async {
    // * Clean phone number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // * Encode message for URL
    final encodedMessage = Uri.encodeComponent(message);
    
    // * Build SMS URI
    final smsUri = Uri.parse('sms:$cleanNumber?body=$encodedMessage');
    
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        debugPrint("[EmergencySmsService] WARNING: Cannot launch SMS app");
        return false;
      }
    } catch (e) {
      debugPrint("[EmergencySmsService] ERROR: Error launching SMS: $e");
      return false;
    }
  }

  /// * Generate Google Maps link for location
  String _generateMapsLink(double latitude, double longitude) {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// * Format coordinates for display
  String _formatCoordinates(double latitude, double longitude) {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lonDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(5)}$latDir, ${longitude.abs().toStringAsFixed(5)}$lonDir';
  }

  /// * Generate default emergency message (non-panic format)
  /// * V2: More informative, less alarming
  String _generateDefaultMessage({
    String? userName,
    required String destinationName,
    String? areaName,
    required double latitude,
    required double longitude,
    required String mapsLink,
  }) {
    final timestamp = DateFormat('MMM d, h:mm a').format(DateTime.now());
    final displayName = userName ?? "A SmartRoad user";
    final locationDesc = areaName ?? _formatCoordinates(latitude, longitude);
    
    return '''SmartRoad Safety Alert

$displayName deviated significantly from their commute route near $locationDesc.

Location: $mapsLink
Time: $timestamp
Destination: $destinationName

Please check in with them.

Note: This may be a GPS error or traffic detour. SmartRoad is a commute tracking app with optional safety features.''';
  }

  /// * Send "I'm safe" message to cancel alert
  Future<bool> sendSafeMessage({
    required List<EmergencyContact> contacts,
    required String destinationName,
  }) async {
    if (contacts.isEmpty) return false;

    final timestamp = DateFormat('h:mm a').format(DateTime.now());
    final displayName = _userName ?? "I";
    
    final message = '''SmartRoad Update: All Clear

$displayName is safe! The earlier alert was a false alarm.

This was likely due to GPS drift, traffic detour, or a route change.

Time: $timestamp

- SmartRoad Commute Mode''';

    bool anySent = false;
    
    for (final contact in contacts) {
      try {
        final success = await _sendSms(contact.phoneNumber, message);
        if (success) anySent = true;
      } catch (e) {
        debugPrint("[EmergencySmsService] ERROR: Error sending safe message: $e");
      }
    }

    return anySent;
  }

  /// * Send manual SOS message (more urgent tone)
  Future<bool> sendManualSOS({
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    required String destinationName,
  }) async {
    if (contacts.isEmpty) return false;

    final mapsLink = _generateMapsLink(latitude, longitude);
    final timestamp = DateFormat('MMM d, h:mm a').format(DateTime.now());
    final displayName = _userName ?? "A SmartRoad user";
    
    final message = '''SmartRoad MANUAL SOS

$displayName has manually triggered an SOS alert.

Location: $mapsLink
Time: $timestamp
They were heading to: $destinationName

Please try to contact them immediately.''';

    bool anySent = false;
    
    for (final contact in contacts) {
      try {
        final success = await _sendSms(contact.phoneNumber, message);
        if (success) {
          anySent = true;
          debugPrint("[EmergencySmsService] OK: Manual SOS sent to ${contact.name}");
        }
      } catch (e) {
        debugPrint("[EmergencySmsService] ERROR: Error sending SOS: $e");
      }
    }

    return anySent;
  }

  /// * Test SMS sending (without actually sending)
  Future<bool> testSmsCapability() async {
    final testUri = Uri.parse('sms:+1234567890');
    return await canLaunchUrl(testUri);
  }
  
  /// * Preview the emergency message (for settings screen)
  String previewEmergencyMessage({
    String? userName,
    String destinationName = "Work",
    String areaName = "Quezon City",
  }) {
    final displayName = userName ?? _userName ?? "User";
    final timestamp = DateFormat('MMM d, h:mm a').format(DateTime.now());
    
    return '''SmartRoad Safety Alert

$displayName deviated significantly from their commute route near $areaName.

Location: [Google Maps Link]
Time: $timestamp
Destination: $destinationName

Please check in with them.

Note: This may be a GPS error or traffic detour.''';
  }
}


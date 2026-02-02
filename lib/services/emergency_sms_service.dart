import "package:flutter/foundation.dart";
import "package:url_launcher/url_launcher.dart";

import "../models/commute_state.dart";

/// * Emergency SMS Service
/// * Handles sending SMS alerts to emergency contacts
class EmergencySmsService {
  static final EmergencySmsService _instance = EmergencySmsService._internal();
  factory EmergencySmsService() => _instance;
  EmergencySmsService._internal();

  /// * Send emergency SMS to all contacts
  Future<bool> sendEmergencyAlert({
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    required String destinationName,
    String? customMessage,
  }) async {
    if (contacts.isEmpty) {
      debugPrint("⚠️ [EmergencySmsService] No emergency contacts configured");
      return false;
    }

    final mapsLink = _generateMapsLink(latitude, longitude);
    final message = customMessage ?? _generateDefaultMessage(
      destinationName: destinationName,
      mapsLink: mapsLink,
    );

    bool anySent = false;
    
    for (final contact in contacts) {
      try {
        final success = await _sendSms(contact.phoneNumber, message);
        if (success) {
          anySent = true;
          debugPrint("✅ [EmergencySmsService] SMS sent to ${contact.name}");
        } else {
          debugPrint("❌ [EmergencySmsService] Failed to send to ${contact.name}");
        }
      } catch (e) {
        debugPrint("❌ [EmergencySmsService] Error sending to ${contact.name}: $e");
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
        debugPrint("⚠️ [EmergencySmsService] Cannot launch SMS app");
        return false;
      }
    } catch (e) {
      debugPrint("❌ [EmergencySmsService] Error launching SMS: $e");
      return false;
    }
  }

  /// * Generate Google Maps link for location
  String _generateMapsLink(double latitude, double longitude) {
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }

  /// * Generate default emergency message
  String _generateDefaultMessage({
    required String destinationName,
    required String mapsLink,
  }) {
    return '''
🚨 SAFETY ALERT

I may be off-route or in an unexpected location.

Original destination: $destinationName

My current location:
$mapsLink

This is an automated message from SmartRoad Commute Mode.
''';
  }

  /// * Send "I'm safe" message to cancel alert
  Future<bool> sendSafeMessage({
    required List<EmergencyContact> contacts,
    required String destinationName,
  }) async {
    if (contacts.isEmpty) return false;

    const message = '''
✅ UPDATE: I'm safe!

False alarm - I'm okay and back on track.

This is an automated message from SmartRoad Commute Mode.
''';

    bool anySent = false;
    
    for (final contact in contacts) {
      try {
        final success = await _sendSms(contact.phoneNumber, message);
        if (success) anySent = true;
      } catch (e) {
        debugPrint("❌ [EmergencySmsService] Error sending safe message: $e");
      }
    }

    return anySent;
  }

  /// * Test SMS sending (without actually sending)
  Future<bool> testSmsCapability() async {
    final testUri = Uri.parse('sms:+1234567890');
    return await canLaunchUrl(testUri);
  }
}


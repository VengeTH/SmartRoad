import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter/foundation.dart";
import "../models/hazard.dart";
import "../core/constants/app_constants.dart";

/// * Local notification service
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  
  /// * Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _initialized = true;
  }
  
  /// * Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // * Can navigate to hazard detail here
    debugPrint("Notification tapped: ${response.payload}");
  }
  
  /// * Show notification for nearby hazard
  Future<void> notifyNearbyHazard(Hazard hazard, double userLat, double userLon) async {
    if (!_initialized) {
      await initialize();
    }
    
    final distance = hazard.distanceTo(userLat, userLon);
    if (distance > AppConstants.notificationRadiusKm) {
      return; // * Too far away
    }
    
    const androidDetails = AndroidNotificationDetails(
      'hazards',
      'Road Hazards',
      channelDescription: 'Notifications for nearby road hazards',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      hazard.id.hashCode,
      'New ${hazard.type.value} nearby',
      '${hazard.description.substring(0, hazard.description.length > 50 ? 50 : hazard.description.length)}...',
      details,
      payload: hazard.id,
    );
  }
  
  /// * Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}


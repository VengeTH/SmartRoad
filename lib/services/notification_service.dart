import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter/foundation.dart";
import "../models/hazard.dart";
import "../core/constants/app_constants.dart";

/// * Notification IDs for commute mode
class _CommuteNotificationIds {
  static const int tracking = 1001;
  static const int alarm = 1002;
  static const int lagpas = 1003;
  static const int arrival = 1004;
}

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
    
    // * Create notification channels for Android
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // * Commute tracking channel (low priority, ongoing)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'commute_tracking',
          'Commute Tracking',
          description: 'Shows commute progress in background',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
      
      // * Commute alarm channel (high priority, with sound)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'commute_alarm',
          'Commute Alarm',
          description: 'Alerts when approaching destination',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      
      // * Lagpas alert channel (max priority, alarm sound)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'commute_lagpas',
          'Lagpas Alert',
          description: 'Critical alert when passing destination',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
    
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
  
  // ============================================================
  // * COMMUTE MODE NOTIFICATIONS
  // ============================================================
  
  /// * Show ongoing foreground notification for commute tracking
  Future<void> showCommuteTrackingNotification({
    required String destinationName,
    required String distanceText,
    required String etaText,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    final androidDetails = AndroidNotificationDetails(
      'commute_tracking',
      'Commute Tracking',
      channelDescription: 'Shows commute progress in background',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      subText: 'Commute Mode',
      styleInformation: BigTextStyleInformation(
        'Distance: $distanceText • ETA: $etaText',
        contentTitle: '📍 Going to $destinationName',
      ),
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      _CommuteNotificationIds.tracking,
      '📍 Going to $destinationName',
      'Distance: $distanceText • ETA: $etaText',
      details,
      payload: 'commute_tracking',
    );
  }
  
  /// * Update the commute tracking notification
  Future<void> updateCommuteTrackingNotification({
    required String destinationName,
    required String distanceText,
    required String etaText,
  }) async {
    // * Just re-show with same ID to update
    await showCommuteTrackingNotification(
      destinationName: destinationName,
      distanceText: distanceText,
      etaText: etaText,
    );
  }
  
  /// * Show commute alarm notification (approaching destination)
  Future<void> showCommuteAlarm({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    const androidDetails = AndroidNotificationDetails(
      'commute_alarm',
      'Commute Alarm',
      channelDescription: 'Alerts when approaching destination',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      _CommuteNotificationIds.alarm,
      title,
      body,
      details,
      payload: 'commute_alarm',
    );
  }
  
  /// * Cancel commute alarm notification
  Future<void> cancelCommuteAlarm() async {
    await _notifications.cancel(_CommuteNotificationIds.alarm);
  }
  
  /// * Show lagpas-baba alert (passed destination)
  Future<void> showLagpasAlert({
    required String destinationName,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    const androidDetails = AndroidNotificationDetails(
      'commute_lagpas',
      'Lagpas Alert',
      channelDescription: 'Critical alert when passing destination',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      ticker: 'LAGPAS KA NA!',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      _CommuteNotificationIds.lagpas,
      '🚨 LAGPAS KA NA!',
      'You passed $destinationName!',
      details,
      payload: 'commute_lagpas',
    );
  }
  
  /// * Cancel lagpas alert
  Future<void> cancelLagpasAlert() async {
    await _notifications.cancel(_CommuteNotificationIds.lagpas);
  }
  
  /// * Show arrival notification
  Future<void> showCommuteArrival({
    required String destinationName,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    const androidDetails = AndroidNotificationDetails(
      'commute_alarm',
      'Commute Alarm',
      channelDescription: 'Alerts when approaching destination',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
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
      _CommuteNotificationIds.arrival,
      '✅ You\'ve arrived!',
      'Welcome to $destinationName',
      details,
      payload: 'commute_arrival',
    );
  }
  
  /// * Cancel all commute-related notifications
  Future<void> cancelCommuteNotifications() async {
    await _notifications.cancel(_CommuteNotificationIds.tracking);
    await _notifications.cancel(_CommuteNotificationIds.alarm);
    await _notifications.cancel(_CommuteNotificationIds.lagpas);
    await _notifications.cancel(_CommuteNotificationIds.arrival);
  }
  
  /// * Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}


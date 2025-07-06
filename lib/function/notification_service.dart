// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-22 15:30:15
// Current User's Login: devivekrt

// File: lib/services/notification_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/material.dart';

// Import your screens here
import '../data/string.dart';
import '../student/notification_center.dart';

/// Handles notification functionality using Firebase Cloud Messaging
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Core notification components
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  final rtdb.FirebaseDatabase _database = rtdb.FirebaseDatabase.instance;

  // Navigation key for context-free navigation
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Initialize the notification service
  Future<void> initialize() async {
    try {

      // Request permissions
      await _requestPermissions();

      // Setup Firebase message handlers
      _setupMessageHandlers();

    } catch (e) {
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

    } catch (e) {
    }
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    try {
      // 1. When app is in foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 2. When app is in background and user taps notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // 3. Check if app was opened from a notification while terminated
      _messaging.getInitialMessage().then((message) {
        if (message != null) {
          _handleInitialMessage(message);
        }
      });

    } catch (e) {
    }
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {

      // Store notification in database
      await _saveNotificationToDatabase(message);

      // Note: We've removed local notifications handling
      // FCM will handle the display of foreground notifications

    } catch (e) {
    }
  }

  /// Handle background message (app is in background)
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    try {

      // Navigate to appropriate screen
      _navigateBasedOnNotification(message.data);
    } catch (e) {
    }
  }

  /// Handle initial message (app was terminated)
  Future<void> _handleInitialMessage(RemoteMessage message) async {
    try {

      // Navigate to appropriate screen after a short delay to ensure app is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateBasedOnNotification(message.data);
      });
    } catch (e) {
    }
  }

  /// Save notification to database
  Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      // Get user ID (from data or current logged in user)
      String? userId = data['userId'];
      if (userId == null || userId.isEmpty) {
        userId = SmartLib.userId;
      }

      if (userId == null || userId.isEmpty) {
        return;
      }

      // Create notification data
      Map<String, dynamic> notificationData = {
        'userId': userId,
        'title': notification?.title ?? data['title'] ?? 'Notification',
        'message': notification?.body ?? data['message'] ?? '',
        'read': false,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'type': data['type'] ?? 'general',
      };

      // Add optional fields if present
      if (data.containsKey('libraryId') && data['libraryId'] != null) {
        notificationData['libraryId'] = data['libraryId'];
      }

      if (data.containsKey('senderType') && data['senderType'] != null) {
        notificationData['senderType'] = data['senderType'];
      }

      if (data.containsKey('senderId') && data['senderId'] != null) {
        notificationData['senderId'] = data['senderId'];
      }

      // Save to Firestore
      await _firestore.collection('notifications').add(notificationData);

      // Update unread count in RTDB for badge
      await _incrementUnreadCount(userId);

    } catch (e) {
    }
  }

  /// Navigate based on notification type
  void _navigateBasedOnNotification(Map<String, dynamic> data) {
    // Get navigator state with null safety
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      return;
    }

    final context = navigatorState.context;

    // Get notification type with default
    final String notificationType = data['type'] ?? 'general';

    // Get user ID from data or current user
    final String userId = data['userId'] ?? SmartLib.userId ?? '';

    // Library ID for some notifications
    final String? libraryId = data['libraryId'];

    // Navigate based on type
    try {
      switch (notificationType) {
        case 'announcement':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationCenterScreen(studentId: userId),
            ),
          );
          break;

        case 'booking_expired':
        // Add your booking expired screen navigation here
          break;

      // Add more cases as needed for different notification types

        default:
        // Default to notification center
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationCenterScreen(studentId: userId),
            ),
          );
      }
    } catch (e) {
    }
  }

  /// Save FCM token when user logs in
  Future<void> saveUserToken(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    try {
      // Get current token
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      // Save to RTDB
      await _database.ref('appStatus/$userId/fcm').update({
        'token': token,
        'updatedAt': rtdb.ServerValue.timestamp,
        'platform': _getPlatform(),
        'appVersion': '1.0.0', // Update with your app version
      });


      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        saveUserToken(userId);
      });
    } catch (e) {
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(
      String notificationId,
      String userId,
      ) async {
    if (notificationId.isEmpty || userId.isEmpty) {
      return;
    }

    try {
      // Update Firestore
      await _firestore.collection('userNotifications').doc(notificationId).update({
        'read': true,
      });

      // Decrement unread count
      await _decrementUnreadCount(userId);

    } catch (e) {
    }
  }

  // This is the corrected _incrementUnreadCount method that avoids accessing value property directly
  Future<void> _incrementUnreadCount(String userId) async {
    try {
      final ref = _database.ref('users/students/$userId/stats');

      // First, try to get the current value
      final snapshot = await ref.get();

      // Initialize with default values
      int currentCount = 0;
      Map<String, dynamic> updates = {};

      // Check if data exists and extract the unread count
      if (snapshot.exists) {
        try {
          // Extract the value safely
          final dynamic snapshotValue = snapshot.value;

          // Check if the value is a Map
          if (snapshotValue is Map) {
            // Try to get the unreadNotifications value
            final unreadValue = snapshotValue['unreadNotifications'];

            if (unreadValue is int) {
              currentCount = unreadValue;
            } else if (unreadValue != null) {
              try {
                currentCount = int.parse(unreadValue.toString());
              } catch (e) {
              }
            }
          }
        } catch (e) {
        }
      }

      // Prepare the update
      updates['unreadNotifications'] = currentCount + 1;

      // Perform the update
      await ref.update(updates);

    } catch (e) {
    }
  }

  // This is the corrected _decrementUnreadCount method that avoids accessing value property directly
  Future<void> _decrementUnreadCount(String userId) async {
    try {
      final ref = _database.ref('users/students/$userId/stats');

      // First, try to get the current value
      final snapshot = await ref.get();

      // Initialize with default values
      int currentCount = 0;
      Map<String, dynamic> updates = {};

      // Check if data exists and extract the unread count
      if (snapshot.exists) {
        try {
          // Extract the value safely
          final dynamic snapshotValue = snapshot.value;

          // Check if the value is a Map
          if (snapshotValue is Map) {
            // Try to get the unreadNotifications value
            final unreadValue = snapshotValue['unreadNotifications'];

            if (unreadValue is int) {
              currentCount = unreadValue;
            } else if (unreadValue != null) {
              try {
                currentCount = int.parse(unreadValue.toString());
              } catch (e) {
              }
            }
          }
        } catch (e) {
        }
      }

      // Only decrement if greater than 0
      if (currentCount > 0) {
        currentCount--;
      }

      // Prepare the update
      updates['unreadNotifications'] = currentCount;

      // Perform the update
      await ref.update(updates);

    } catch (e) {
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    try {
      // Get all unread notifications
      final querySnapshot =
      await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return;
      }

      // Create a batch write
      final batch = _firestore.batch();

      // Add each notification to batch
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }

      // Commit batch
      await batch.commit();

      // Reset unread counter in RTDB
      await _database.ref('users/students/$userId/stats').update({
        'unreadNotifications': 0,
      });

    } catch (e) {
    }
  }

  /// Get platform name for FCM token
  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'flutter';
  }

  /// Clean up when user logs out
  Future<void> cleanUpOnLogout() async {
    try {
      final userId = SmartLib.userId;
      if (userId == null || userId.isEmpty) return;

      // Delete FCM token from RTDB
      await _database.ref('users/students/$userId/fcm/token').remove();

    } catch (e) {
    }
  }

  /// Get unread notification count for a user
  Future<int> getUnreadCount(String userId) async {
    if (userId.isEmpty) {
      return 0;
    }

    try {
      final snapshot =
      await _database
          .ref('users/students/$userId/stats/unreadNotifications')
          .once();

      if (snapshot.snapshot.value == null) {
        return 0;
      }

      if (snapshot.snapshot.value is int) {
        return snapshot.snapshot.value as int;
      }

      return int.tryParse(snapshot.snapshot.value.toString()) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
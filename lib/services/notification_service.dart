import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gdg_nativechatapp/pages/chat/chat_screen.dart';

// Global variable for local notifications
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

// Background message handler - must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Handling a background message: ${message.messageId}');

  final data = message.data;
  final title = message.notification?.title ?? 'New Message';
  final body = message.notification?.body ?? 'You have a new message';

  // Show local notification for background messages
  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel_id',
        'Default Notifications',
        channelDescription: 'Channel for default notifications',
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: data.toString(),
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _pendingToken; // Store token if user not authenticated yet

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  /// Initialize notification service and request permissions
  Future<void> initialize(BuildContext context) async {
    try {
      print('🔔 Initializing NotificationService...');

      // Step 0: Initialize local notifications
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android notification channel configuration
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS notification configuration
      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: androidInitializationSettings,
            iOS: iosInitializationSettings,
          );

      // Initialize local notifications
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          print('📱 Local notification tapped: ${details.payload}');
          // Handle local notification tap if needed
        },
      ); // Step 1: Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('✅ Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        print('❌ Notification permission denied');
        return;
      }

      // Step 1.5: On iOS, request APNS token explicitly
      try {
        await _messaging.requestPermission();
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          print('✅ APNS Token requested: $apnsToken');
        }
      } catch (e) {
        print('ℹ️ APNS token request skipped (may not be iOS): $e');
      }

      // Step 2: Get and save token with retry logic
      await _getTokenWithRetry(maxRetries: 3);

      // Step 3: Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      print('✅ Background message handler registered');

      // Step 4: Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });

      // Step 5: Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Foreground message received: ${message.data}');
        _showForegroundNotification(message);
      });

      // Step 6: Handle background message (user taps notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 Notification tapped from background');
        _handleRemoteMessageClick(context, message);
      });

      // Step 7: Handle terminated state
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from terminated state via notification');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleRemoteMessageClick(context, initialMessage);
        });
      }

      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Get FCM token with retry logic
  Future<void> _getTokenWithRetry({int maxRetries = 5}) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        attempt++;
        print('🔑 Attempting to get FCM token (Attempt $attempt/$maxRetries)');

        // Step 1: Try to get FCM token directly (works on Android without user auth)
        String? token = await _messaging.getToken();

        if (token != null) {
          print('✅ FCM Token obtained: $token');

          // Step 2: Save token to Firestore (only if user is authenticated)
          User? user = _auth.currentUser;
          if (user != null) {
            await _saveTokenToFirestore(token);
          } else {
            print(
              '⚠️ User not authenticated yet, token will be saved after login',
            );
            // Store token in a temporary cache or memory for later use
            _pendingToken = token;
          }
          return; // Success, exit the retry loop
        }

        // Token is null, check reason and retry
        // On iOS, check if APNS token is available
        try {
          String? apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            print('⚠️ APNS token not available yet, retrying...');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          print('✅ APNS Token obtained: $apnsToken');
        } catch (e) {
          print('ℹ️ APNS token check skipped (may not be iOS): $e');
        }

        print('⚠️ FCM token is null, retrying...');
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        print('❌ Error on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }

    print('❌ Failed to get FCM token after $maxRetries attempts');
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user authenticated');
        return;
      }

      String uid = user.uid;
      DocumentReference userDoc = _firestore.collection('users').doc(uid);

      // Try to update first (assumes profile already exists)
      try {
        await userDoc.update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ Token added to existing user document');
      } on FirebaseException catch (e) {
        // If document doesn't exist, create it with merge
        if (e.code == 'not-found') {
          print('ℹ️ User document not found, creating with merge...');
          await userDoc.set({
            'fcmTokens': [token],
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ User document created with token');
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print('❌ Error saving token to Firestore: $e');
    }
  }

  /// Show foreground notification using local notifications
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    print('📱 Displaying foreground notification');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');

    final title = message.notification?.title ?? 'New Message';
    final body = message.notification?.body ?? 'You have a new message';

    // Show local notification for foreground messages
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel_id',
          'Default Notifications',
          channelDescription: 'Channel for default notifications',
          importance: Importance.max,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  /// Handle navigation when user taps a notification (from RemoteMessage)
  void _handleRemoteMessageClick(BuildContext context, RemoteMessage message) {
    try {
      print('🔍 Processing notification click with data: ${message.data}');

      String? chatId = message.data['chatId'];
      String? recipientName = message.data['recipientName'];
      String? recipientPhotoUrl = message.data['recipientPhotoUrl'];
      String? senderId = message.data['senderId'];

      if (chatId == null || chatId.isEmpty) {
        print('❌ chatId is missing or empty');
        return;
      }

      print('✅ Navigating to ChatScreen with chatId: $chatId');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            recipientId: senderId ?? '',
            recipientName: recipientName ?? 'Unknown User',
            recipientPhotoUrl: recipientPhotoUrl ?? '',
          ),
        ),
      );
    } catch (e) {
      print('❌ Error handling notification click: $e');
    }
  }

  /// Remove a specific token (useful for logout)
  Future<void> removeToken() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user authenticated');
        return;
      }

      String uid = user.uid;
      String? token = await _messaging.getToken();

      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
        print('✅ Token removed from Firestore');
      }
    } catch (e) {
      print('❌ Error removing token: $e');
    }
  }

  /// Clear all tokens for current user (useful for logout)
  Future<void> clearAllTokens() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user authenticated');
        return;
      }

      String uid = user.uid;
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': [],
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ All tokens cleared for user');
    } catch (e) {
      print('❌ Error clearing tokens: $e');
    }
  }

  /// Get current FCM token (for debugging)
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  /// Save pending token after user authenticates
  Future<void> savePendingToken() async {
    if (_pendingToken != null) {
      print('💾 Saving pending token...');

      // Wait a short moment to ensure the user profile is created first
      await Future.delayed(const Duration(milliseconds: 500));

      await _saveTokenToFirestore(_pendingToken!);
      _pendingToken = null;

      print('✅ Pending token saved successfully');
    } else {
      print('ℹ️ No pending token to save');
    }
  }
}

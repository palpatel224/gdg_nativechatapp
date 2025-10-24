import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:gdg_nativechatapp/pages/chat/chat_screen.dart';

// Import your ChatScreen
// import 'package:gdg_nativechatapp/screens/chat_screen.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pass the navigatorKey to the service
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService(this.navigatorKey);

  Future<void> initialize(BuildContext context) async {
    // 1. Request Permission
    await _fcm.requestPermission();

    // 2. Get and Save Token
    await _getToken();
    _fcm.onTokenRefresh.listen((token) => _getToken());

    // 3. Setup Handlers
    _setupNotificationHandlers();
  }

  Future<void> _getToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
          print("FCM Token saved to Firestore.");
        }
      }
    } catch (e) {
      print("Error getting or saving FCM token: $e");
    }
  }

  void _setupNotificationHandlers() {
    // --- 1. App is in the FOREGROUND ---
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // You could show a local notification or an in-app banner here
      }
    });

    // --- 2. App is in the BACKGROUND (and user taps notification) ---
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
      _handleNotificationClick(message.data);
    });

    // --- 3. App is TERMINATED (and user taps notification) ---
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state by notification!');
        _handleNotificationClick(message.data);
      }
    });
  }

    // This is the function that handles navigation
  void _handleNotificationClick(Map<String, dynamic> data) {
    final String? chatId = data['chatId'];
    final String? recipientId = data['recipientId'];
    final String? recipientName = data['recipientName'];
    final String? recipientPhotoUrl = data['recipientPhotoUrl'];

    if (chatId != null && recipientId != null && recipientName != null) {
      // Use the GlobalKey to navigate
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            // <--- REPLACE WITH YOUR CHAT SCREEN
            chatId: chatId,
            recipientId: recipientId,
            recipientName: recipientName,
            recipientPhotoUrl: recipientPhotoUrl ?? "", 
          ),
        ),
      );
    }
  }
}



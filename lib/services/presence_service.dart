import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// PresenceService
/// - Observes app lifecycle and updates the current user's presence
///   in both Cloud Firestore (`users/{uid}`) and the Realtime Database
class PresenceService with WidgetsBindingObserver {
  PresenceService();

  /// Call this during app startup (after Firebase.initializeApp)
  void init() {
    WidgetsBinding.instance.addObserver(this);
    // Ensure we set presence initially
    updateUserPresence();
  }

  /// Call this when the app is disposed
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Update user presence in both Firestore and Realtime Database
  Future<void> updateUserPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final rtdbRef = FirebaseDatabase.instance.ref('status/$uid');

    // Note: We build offline maps inline where needed. No local unused var.

    try {
      // Configure RTDB onDisconnect to set offline state when connection is lost
      // Use ServerValue.timestamp for lastSeen in RTDB
      await rtdbRef.onDisconnect().set({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      // When we come online, set RTDB node to online with timestamp
      await rtdbRef.set({'isOnline': true, 'lastSeen': ServerValue.timestamp});

      // Also update Firestore to reflect online state. We use merge to avoid
      // overwriting other fields on the user document.
      await userDocRef.set({'isOnline': true}, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal - presence best-effort
      // Use debugPrint to avoid crashing in production
      debugPrint('PresenceService updateUserPresence error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final rtdbRef = FirebaseDatabase.instance.ref('status/$uid');

    switch (state) {
      case AppLifecycleState.resumed:
        // App in foreground - mark online
        userDocRef.set({'isOnline': true}, SetOptions(merge: true));
        rtdbRef.set({'isOnline': true, 'lastSeen': ServerValue.timestamp});
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App backgrounded or terminated - mark offline and set lastSeen
        userDocRef.set({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // RTDB lastSeen uses ServerValue.timestamp
        rtdbRef.set({'isOnline': false, 'lastSeen': ServerValue.timestamp});
        break;
      default:
        // For any other lifecycle states, be conservative and mark offline
        userDocRef.set({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        rtdbRef.set({'isOnline': false, 'lastSeen': ServerValue.timestamp});
        break;
    }
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service for managing typing status using a presence-based approach
/// Uses a subcollection under conversations for real-time typing detection
class TypingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track typing status for each conversation
  final Map<String, StreamSubscription?> _typingSubscriptions = {};
  final Map<String, Timer?> _typingTimers = {};

  /// Start listening to typing status for a conversation
  /// Returns a stream of typing user IDs
  Stream<List<String>> getTypingStatusStream(String chatId) {
    debugPrint('[TypingService] Setting up typing listener for: $chatId');

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
          final typingUserIds = <String>[];
          final now = DateTime.now();
          const typingTimeout = Duration(seconds: 2);

          for (var doc in snapshot.docs) {
            final userId = doc.id;
            final lastTyped = (doc.data()['lastTyped'] as Timestamp?)?.toDate();

            // Only include users who typed within the last 2 seconds
            if (lastTyped != null &&
                now.difference(lastTyped) < typingTimeout) {
              typingUserIds.add(userId);
            }
          }

          debugPrint('[TypingService] Active typers: $typingUserIds');
          return typingUserIds;
        });
  }

  /// Update typing status - call when user types
  Future<void> updateTypingStatus(String chatId, bool isTyping) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      if (isTyping) {
        debugPrint('[TypingService] User $userId is typing in $chatId');

        // Cancel existing timer for this chat
        _typingTimers[chatId]?.cancel();

        // Write typing status
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('typing')
            .doc(userId)
            .set({'lastTyped': FieldValue.serverTimestamp(), 'userId': userId});

        // Auto-remove typing status after 2 seconds of inactivity
        _typingTimers[chatId] = Timer(const Duration(seconds: 2), () async {
          debugPrint('[TypingService] Auto-removing typing status for $userId');
          try {
            await _firestore
                .collection('chats')
                .doc(chatId)
                .collection('typing')
                .doc(userId)
                .delete();
          } catch (e) {
            debugPrint('[TypingService] Error removing typing status: $e');
          }
        });
      } else {
        debugPrint('[TypingService] User $userId stopped typing in $chatId');

        // Cancel timer
        _typingTimers[chatId]?.cancel();
        _typingTimers.remove(chatId);

        // Remove typing status
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('typing')
            .doc(userId)
            .delete();
      }
    } catch (e) {
      debugPrint('[TypingService] Error updating typing status: $e');
    }
  }

  /// Clean up resources for a conversation
  void dispose(String chatId) {
    _typingSubscriptions[chatId]?.cancel();
    _typingSubscriptions.remove(chatId);

    _typingTimers[chatId]?.cancel();
    _typingTimers.remove(chatId);
  }

  /// Clean up all resources
  void disposeAll() {
    for (var sub in _typingSubscriptions.values) {
      sub?.cancel();
    }
    for (var timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingSubscriptions.clear();
    _typingTimers.clear();
  }
}

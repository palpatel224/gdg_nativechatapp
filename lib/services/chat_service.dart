import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';

/// Service to handle chat-related operations with Firestore
class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Generate a chat ID from two user IDs (sorted alphabetically)
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Get stream of chats for the current user
  Stream<List<ChatModel>> getChatsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    // Listen to chats collection where current user is a participant
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          List<ChatModel> chats = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();

            // Get the other user's ID (the one who is not the current user)
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) continue;

            // Fetch the other user's data
            final userDoc = await _firestore
                .collection('users')
                .doc(otherUserId)
                .get();
            if (!userDoc.exists) continue;

            final userData = userDoc.data()!;
            final user = AppUser.fromMap(userData);

            // Create ChatModel from the data
            chats.add(
              ChatModel.fromFirestore(
                doc,
                user.uid,
                user.displayName,
                user.photoUrl,
                user.isOnline,
              ),
            );
          }

          // Sort by last message time (most recent first)
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

          return chats;
        });
  }

  /// Create or get existing chat between two users
  /// Ensures the chat document exists in Firestore with all required fields
  /// Uses set with merge to avoid permission issues when checking if chat exists
  Future<String> getOrCreateChat(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Generate the chat ID using sorted UIDs
    final chatId = _generateChatId(currentUserId, otherUserId);

    // Create or update the chat using set with merge
    // This avoids needing to read the document first (which can fail with permissions)
    // merge: true ensures we don't overwrite existing chat data
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUserId, otherUserId],
      'lastMessage': {
        'text': '',
        'senderId': '',
        'timestamp': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
      'typingStatus': {currentUserId: false, otherUserId: false},
    }, SetOptions(merge: true));

    return chatId;
  }

  /// Search chats by user name
  Future<List<ChatModel>> searchChats(String query) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return [];
    }

    // Get all chats first
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    List<ChatModel> matchingChats = [];

    for (var doc in chatsSnapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) continue;

      // Fetch the other user's data
      final userDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();
      if (!userDoc.exists) continue;

      final userData = userDoc.data()!;
      final user = AppUser.fromMap(userData);

      // Check if user name matches the query
      if (user.displayName.toLowerCase().contains(query.toLowerCase())) {
        matchingChats.add(
          ChatModel.fromFirestore(
            doc,
            user.uid,
            user.displayName,
            user.photoUrl,
            user.isOnline,
          ),
        );
      }
    }

    // Sort by last message time
    matchingChats.sort(
      (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
    );

    return matchingChats;
  }

  /// Update typing status for a user in a chat
  Future<void> updateTypingStatus(String chatId, bool isTyping) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('chats').doc(chatId).update({
      'typingStatus.$currentUserId': isTyping,
    });
  }

  /// Send a text message
  /// Performs a two-step write process:
  /// 1. Adds message to messages subcollection
  /// 2. Updates lastMessage field in parent chat document (for home screen preview)
  Future<void> sendMessage(String chatId, String text) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final messageData = {
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'messageType': 'text',
    };

    // Step 1: Add message to messages subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Step 2: Update lastMessage in chat document
    // This is critical for showing the latest message preview on the home screen
    // Uses set with merge to ensure the chat document exists
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': {
        'text': text,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  /// Send a location message
  Future<void> sendLocationMessage(
    String chatId,
    double latitude,
    double longitude,
    String address,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final messageData = {
      'senderId': currentUserId,
      'text': null,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'messageType': 'location',
      'locationData': {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      },
    };

    // Add message to messages subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Update lastMessage in chat document
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': {
        'text': 'Location shared',
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      },
    });
  }
}

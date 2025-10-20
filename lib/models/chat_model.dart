import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<String> participants;
  final String? lastMessageSenderId;
  final Map<String, bool> typingStatus;

  const ChatModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.participants = const [],
    this.lastMessageSenderId,
    this.typingStatus = const {},
  });

  factory ChatModel.fromFirestore(
    DocumentSnapshot doc,
    String otherUserId,
    String otherUserName,
    String otherUserAvatar,
    bool otherUserIsOnline,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final lastMessageData = data['lastMessage'] as Map<String, dynamic>?;

    return ChatModel(
      id: doc.id,
      userId: otherUserId,
      userName: otherUserName,
      userAvatar: otherUserAvatar,
      lastMessage: lastMessageData?['text'] ?? '',
      lastMessageTime:
          (lastMessageData?['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      lastMessageSenderId: lastMessageData?['senderId'],
      participants: List<String>.from(data['participants'] ?? []),
      typingStatus: Map<String, bool>.from(data['typingStatus'] ?? {}),
      isOnline: otherUserIsOnline,
      unreadCount: 0, // Will be calculated based on message status
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    userAvatar,
    lastMessage,
    lastMessageTime,
    unreadCount,
    isOnline,
    participants,
    lastMessageSenderId,
    typingStatus,
  ];
}

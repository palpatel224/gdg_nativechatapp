import 'package:equatable/equatable.dart';

class ChatModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const ChatModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

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
  ];
}

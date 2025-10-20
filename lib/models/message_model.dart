import 'package:equatable/equatable.dart';

enum MessageType { text, image, file }

class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final bool isSentByMe;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isRead = false,
    this.isSentByMe = false,
  });

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    senderAvatar,
    content,
    type,
    timestamp,
    isRead,
    isSentByMe,
  ];
}

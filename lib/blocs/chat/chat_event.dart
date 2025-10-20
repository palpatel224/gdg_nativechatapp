import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatLoadMessages extends ChatEvent {
  final String chatId;

  const ChatLoadMessages(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class ChatSendMessage extends ChatEvent {
  final String chatId;
  final String content;

  const ChatSendMessage({required this.chatId, required this.content});

  @override
  List<Object?> get props => [chatId, content];
}

class ChatSendImage extends ChatEvent {
  final String chatId;
  final String imagePath;

  const ChatSendImage({required this.chatId, required this.imagePath});

  @override
  List<Object?> get props => [chatId, imagePath];
}

class ChatTyping extends ChatEvent {
  final String chatId;
  final bool isTyping;

  const ChatTyping({required this.chatId, required this.isTyping});

  @override
  List<Object?> get props => [chatId, isTyping];
}

class ChatMarkAsRead extends ChatEvent {
  final String chatId;
  final String messageId;

  const ChatMarkAsRead({required this.chatId, required this.messageId});

  @override
  List<Object?> get props => [chatId, messageId];
}

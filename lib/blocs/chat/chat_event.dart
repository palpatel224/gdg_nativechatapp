import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Load messages for a specific chat
/// NOTE: ChatScreen uses StreamBuilder directly for real-time updates
/// This event is kept for compatibility with optional BLoC-based integrations
class ChatLoadMessages extends ChatEvent {
  final String chatId;

  const ChatLoadMessages(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

/// Send a text message to a chat
/// NOTE: ChatScreen calls _sendMessage() directly
/// This event can be used by BLoC consumers for centralized message sending
class ChatSendMessage extends ChatEvent {
  final String chatId;
  final String content;

  const ChatSendMessage({required this.chatId, required this.content});

  @override
  List<Object?> get props => [chatId, content];
}

/// Send an image message (placeholder for future implementation)
class ChatSendImage extends ChatEvent {
  final String chatId;
  final String imagePath;

  const ChatSendImage({required this.chatId, required this.imagePath});

  @override
  List<Object?> get props => [chatId, imagePath];
}

/// Update typing status in a chat
/// NOTE: ChatScreen doesn't currently use this, but it's available for BLoC consumers
class ChatTyping extends ChatEvent {
  final String chatId;
  final bool isTyping;

  const ChatTyping({required this.chatId, required this.isTyping});

  @override
  List<Object?> get props => [chatId, isTyping];
}

/// Mark a message as read
/// NOTE: ChatScreen uses StreamBuilder to automatically update statuses
/// This event is kept for compatibility
class ChatMarkAsRead extends ChatEvent {
  final String chatId;
  final String messageId;

  const ChatMarkAsRead({required this.chatId, required this.messageId});

  @override
  List<Object?> get props => [chatId, messageId];
}

/// Internal event: Messages stream has been updated
/// Used internally by ChatBloc to emit new ChatLoaded state
class ChatMessagesUpdated extends ChatEvent {
  final String chatId;
  final List<dynamic> messages;

  const ChatMessagesUpdated(this.chatId, this.messages);

  @override
  List<Object?> get props => [chatId, messages];
}

/// Share live location in a chat
/// Handles permission checking, initial location capture, and starts streaming
class ChatShareLiveLocation extends ChatEvent {
  final String chatId;
  final String recipientId;

  const ChatShareLiveLocation({
    required this.chatId,
    required this.recipientId,
  });

  @override
  List<Object?> get props => [chatId, recipientId];
}

/// Stop sharing live location
/// Cancels position stream and removes location data from Firestore
class ChatStopSharingLocation extends ChatEvent {
  final String chatId;

  const ChatStopSharingLocation(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

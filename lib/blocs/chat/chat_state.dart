import 'package:equatable/equatable.dart';
import '../../models/message_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  final String chatId;
  final List<MessageModel> messages;
  final bool isOtherUserTyping;

  const ChatLoaded({
    required this.chatId,
    required this.messages,
    this.isOtherUserTyping = false,
  });

  ChatLoaded copyWith({
    String? chatId,
    List<MessageModel>? messages,
    bool? isOtherUserTyping,
  }) {
    return ChatLoaded(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
    );
  }

  @override
  List<Object?> get props => [chatId, messages, isOtherUserTyping];
}

class ChatSending extends ChatState {
  const ChatSending();
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

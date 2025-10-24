import 'package:equatable/equatable.dart';
import '../../models/message_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

/// Initial state when BLoC is first created
class ChatInitial extends ChatState {
  const ChatInitial();
}

/// Loading state: Fetching messages or performing operations
class ChatLoading extends ChatState {
  const ChatLoading();
}

/// Loaded state: Chat is ready with messages
/// NOTE: ChatScreen uses StreamBuilder directly and doesn't consume this state
/// However, BLoC consumers can use this state if they want centralized state management
class ChatLoaded extends ChatState {
  final String chatId;
  final List<MessageModel> messages;
  final bool isRecipientTyping; // Track if recipient is typing
  final bool isSharingLocation; // Track if current user is sharing location

  const ChatLoaded({
    required this.chatId,
    required this.messages,
    this.isRecipientTyping = false,
    this.isSharingLocation = false,
  });

  ChatLoaded copyWith({
    String? chatId,
    List<MessageModel>? messages,
    bool? isRecipientTyping,
    bool? isSharingLocation,
  }) {
    return ChatLoaded(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      isRecipientTyping: isRecipientTyping ?? this.isRecipientTyping,
      isSharingLocation: isSharingLocation ?? this.isSharingLocation,
    );
  }

  @override
  List<Object?> get props => [
    chatId,
    messages,
    isRecipientTyping,
    isSharingLocation,
  ];
}

/// Sending state: Message is being sent
class ChatSending extends ChatState {
  const ChatSending();
}

/// Location sharing state: User is actively sharing live location
class ChatSharingLocation extends ChatState {
  final String chatId;

  const ChatSharingLocation(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

/// Error state: Something went wrong
class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

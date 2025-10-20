import 'package:flutter_bloc/flutter_bloc.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../../models/message_model.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(const ChatInitial()) {
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatSendImage>(_onSendImage);
    on<ChatTyping>(_onTyping);
    on<ChatMarkAsRead>(_onMarkAsRead);
  }

  Future<void> _onLoadMessages(
    ChatLoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    try {
      // TODO: Fetch messages from repository
      await Future.delayed(const Duration(seconds: 1));

      // Dummy data for UI
      final messages = _getDummyMessages();
      emit(ChatLoaded(chatId: event.chatId, messages: messages));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (state is ChatLoaded) {
      try {
        // TODO: Send message to repository
        final currentState = state as ChatLoaded;

        final newMessage = MessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'currentUserId',
          senderName: 'Me',
          senderAvatar: '',
          content: event.content,
          timestamp: DateTime.now(),
          isSentByMe: true,
        );

        final updatedMessages = [...currentState.messages, newMessage];
        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
        emit(ChatError(e.toString()));
      }
    }
  }

  Future<void> _onSendImage(
    ChatSendImage event,
    Emitter<ChatState> emit,
  ) async {
    if (state is ChatLoaded) {
      try {
        // TODO: Upload image and send message
        final currentState = state as ChatLoaded;

        final newMessage = MessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'currentUserId',
          senderName: 'Me',
          senderAvatar: '',
          content: event.imagePath,
          type: MessageType.image,
          timestamp: DateTime.now(),
          isSentByMe: true,
        );

        final updatedMessages = [...currentState.messages, newMessage];
        emit(currentState.copyWith(messages: updatedMessages));
      } catch (e) {
        emit(ChatError(e.toString()));
      }
    }
  }

  Future<void> _onTyping(ChatTyping event, Emitter<ChatState> emit) async {
    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(currentState.copyWith(isOtherUserTyping: event.isTyping));
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    // TODO: Mark message as read in repository
  }

  List<MessageModel> _getDummyMessages() {
    return [
      MessageModel(
        id: '1',
        senderId: 'user1',
        senderName: 'John Doe',
        senderAvatar: '',
        content: 'Hey! How are you doing?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isSentByMe: false,
      ),
      MessageModel(
        id: '2',
        senderId: 'currentUserId',
        senderName: 'Me',
        senderAvatar: '',
        content: "I'm good! Thanks for asking. How about you?",
        timestamp: DateTime.now().subtract(const Duration(minutes: 28)),
        isSentByMe: true,
      ),
      MessageModel(
        id: '3',
        senderId: 'user1',
        senderName: 'John Doe',
        senderAvatar: '',
        content: "I'm doing great! Working on a new project.",
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isSentByMe: false,
      ),
      MessageModel(
        id: '4',
        senderId: 'currentUserId',
        senderName: 'Me',
        senderAvatar: '',
        content: 'That sounds exciting! What kind of project?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        isSentByMe: true,
      ),
    ];
  }
}

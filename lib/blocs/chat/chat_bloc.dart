import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService _chatService;
  StreamSubscription? _messagesSubscription;

  ChatBloc(this._chatService) : super(const ChatInitial()) {
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatSendImage>(_onSendImage);
    on<ChatTyping>(_onTyping);
    on<ChatMarkAsRead>(_onMarkAsRead);
    on<ChatMessagesUpdated>(_onMessagesUpdated);
  }

  /// Update message statuses based on current viewing state
  /// - Updates messages from other user to 'delivered' if they are 'sent'
  /// - Updates messages from other user to 'read' when viewing the chat
  Future<void> _updateMessageStatuses(
    String chatId,
    List<QueryDocumentSnapshot> docs,
    String currentUserId,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    bool hasUpdates = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final status = data['status'] as String? ?? 'sent';

      // Only update messages from the other user
      if (senderId != currentUserId) {
        // Mark as delivered if still in sent status
        if (status == 'sent') {
          batch.update(doc.reference, {'status': 'delivered'});
          hasUpdates = true;
        }
        // Mark as read (happens when actively viewing)
        else if (status == 'delivered') {
          batch.update(doc.reference, {'status': 'read'});
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      try {
        await batch.commit();
      } catch (e) {
        // Silently fail for status updates
        print('Failed to update message statuses: $e');
      }
    }
  }

  Future<void> _onLoadMessages(
    ChatLoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        emit(const ChatError('User not authenticated'));
        return;
      }

      // Cancel previous subscription if exists
      await _messagesSubscription?.cancel();

      // Listen to messages stream with real-time updates
      // Query orders messages by timestamp in descending order (newest first)
      // This works with ListView.builder's reverse: true for optimal chat UX
      _messagesSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(event.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              // Update message statuses (delivered/read) before processing
              _updateMessageStatuses(
                event.chatId,
                snapshot.docs,
                currentUserId,
              );

              // Get other user's info for message display
              final messages = snapshot.docs.map((doc) {
                final data = doc.data();
                final senderId = data['senderId'] as String;
                final isSentByMe = senderId == currentUserId;

                // Parse status from Firestore data
                final statusStr = data['status'] as String? ?? 'sent';
                MessageStatus status;
                switch (statusStr) {
                  case 'read':
                    status = MessageStatus.read;
                    break;
                  case 'delivered':
                    status = MessageStatus.delivered;
                    break;
                  default:
                    status = MessageStatus.sent;
                }

                return MessageModel(
                  id: doc.id,
                  senderId: senderId,
                  senderName: isSentByMe ? 'Me' : 'User',
                  senderAvatar: '',
                  text: data['text'] as String?,
                  messageType: data['messageType'] == 'location'
                      ? MessageType.location
                      : MessageType.text,
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  status: status,
                  isSentByMe: isSentByMe,
                  locationData: data['locationData'] != null
                      ? LocationData.fromMap(
                          data['locationData'] as Map<String, dynamic>,
                        )
                      : null,
                );
              }).toList();

              add(ChatMessagesUpdated(event.chatId, messages));
            },
            onError: (error) {
              add(ChatError(error.toString()) as ChatEvent);
            },
          );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onMessagesUpdated(
    ChatMessagesUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final messages = event.messages.cast<MessageModel>();
    emit(ChatLoaded(chatId: event.chatId, messages: messages));
  }

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Validate message content
      final trimmedContent = event.content.trim();
      if (trimmedContent.isEmpty) {
        return; // Do nothing if message is empty
      }

      // Send message through service
      // This performs a two-step write:
      // 1. Adds message to messages subcollection
      // 2. Updates lastMessage field in parent chat document for home screen preview
      await _chatService.sendMessage(event.chatId, trimmedContent);

      // Messages will be updated via the stream subscription
    } catch (e) {
      emit(ChatError('Failed to send message: ${e.toString()}'));
    }
  }

  Future<void> _onSendImage(
    ChatSendImage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // TODO: Upload image functionality will be added later
      // For now, this is a placeholder
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onTyping(ChatTyping event, Emitter<ChatState> emit) async {
    try {
      await _chatService.updateTypingStatus(event.chatId, event.isTyping);
    } catch (e) {
      // Silently fail for typing indicators
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // TODO: Implement mark as read functionality
    } catch (e) {
      // Silently fail for read receipts
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService _chatService;
  StreamSubscription? _messagesSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription? _typingStatusSubscription;

  // Typing debounce management
  Timer? _typingTimer;
  bool _isCurrentUserTyping = false;

  // Cache for state management
  List<MessageModel> _cachedMessages = [];
  bool _cachedRecipientTyping = false;
  String _currentChatId = '';

  ChatBloc(this._chatService) : super(const ChatInitial()) {
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatSendImage>(_onSendImage);
    on<ChatUserTyping>(_onUserTyping);
    on<ChatListenTypingStatus>(_onListenTypingStatus);
    on<ChatMarkAsRead>(_onMarkAsRead);
    on<ChatMessagesUpdated>(_onMessagesUpdated);
    on<ChatShareLiveLocation>(_onShareLiveLocation);
    on<ChatStopSharingLocation>(_onStopSharingLocation);
  }

  /// Update message statuses based on current viewing state
  /// - Updates messages from other user to 'delivered' if they are 'sent'
  /// - Does NOT automatically mark as 'read' - that's handled by ChatScreen when user is actively viewing
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
        // This happens when the chat is loaded, even in background
        if (status == 'sent') {
          batch.update(doc.reference, {'status': 'delivered'});
          hasUpdates = true;
        }
        // REMOVED: Don't automatically mark as 'read' here
        // The ChatScreen will handle marking as 'read' only when user is actively viewing
      }
    }

    if (hasUpdates) {
      try {
        await batch.commit();
      } catch (e) {
        // Silently fail for status updates
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
    final currentState = state;
    final isSharingLocation = currentState is ChatLoaded
        ? currentState.isSharingLocation
        : false;

    // Cache messages and chatId for typing status updates
    _cachedMessages = messages;
    _currentChatId = event.chatId;

    // Use the cached typing status from the typing listener
    final isRecipientTyping = _cachedRecipientTyping;
    debugPrint(
      '[BLoC] _onMessagesUpdated: Using cached isRecipientTyping: $isRecipientTyping',
    );

    emit(
      ChatLoaded(
        chatId: event.chatId,
        messages: messages,
        isRecipientTyping: isRecipientTyping,
        isSharingLocation: isSharingLocation,
      ),
    );
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

  /// Handle user typing in the message input field
  /// Implements debounce logic with efficient Firestore writes:
  /// - Only updates Firestore when typing state changes (not on every keystroke)
  /// - Uses a 2-second debounce to detect when user stops typing
  /// - Minimizes writes to prevent connection issues
  Future<void> _onUserTyping(
    ChatUserTyping event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserUid == null) {
        return;
      }

      debugPrint('[Typing] User is typing in chat: ${event.chatId}');

      // If not already typing, immediately update Firestore to true
      if (!_isCurrentUserTyping) {
        _isCurrentUserTyping = true;
        debugPrint('[Typing] Setting typing status to true in Firestore');
        await _chatService.updateTypingStatus(event.chatId, true);
      }

      // Cancel any existing timer for this chat
      _typingTimer?.cancel();

      // Start a new 2-second debounce timer
      _typingTimer = Timer(const Duration(seconds: 2), () async {
        _isCurrentUserTyping = false;
        debugPrint(
          '[Typing] Debounce timeout - Setting typing status to false in Firestore',
        );
        try {
          await _chatService.updateTypingStatus(event.chatId, false);
        } catch (e) {
          debugPrint('[Typing] Error updating typing status to false: $e');
        }
      });
    } catch (e) {
      debugPrint('[Typing] Exception in _onUserTyping: $e');
    }
  }

  Future<void> _onListenTypingStatus(
    ChatListenTypingStatus event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Cancel previous subscription if exists
      await _typingStatusSubscription?.cancel();

      final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserUid == null) {
        return;
      }

      debugPrint(
        '[Typing] Setting up typing status listener for chat: ${event.chatId}',
      );

      // Listen to chat document for typing status updates
      _typingStatusSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(event.chatId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!snapshot.exists) {
                debugPrint('[Typing] Chat document does not exist');
                return;
              }

              final data = snapshot.data() as Map<String, dynamic>;
              if (data.isEmpty) {
                debugPrint('[Typing] Chat document is empty');
                return;
              }

              final typingStatus =
                  data['typingStatus'] as Map<String, dynamic>? ?? {};

              debugPrint('[Typing] Typing status data: $typingStatus');
              debugPrint(
                '[Typing] Typing status keys: ${typingStatus.keys.toList()}',
              );
              debugPrint(
                '[Typing] Typing status values: ${typingStatus.values.toList()}',
              );

              // Find recipient ID (the participant who is not current user)
              final participants = List<String>.from(
                data['participants'] ?? [],
              );

              final recipientId = participants.firstWhere(
                (id) => id != currentUserUid,
                orElse: () => '',
              );

              if (recipientId.isEmpty) {
                debugPrint('[Typing] Could not find recipient ID');
                return;
              }

              debugPrint(
                '[Typing] Recipient ID: $recipientId, Participants: $participants, Current User: $currentUserUid',
              );
              debugPrint(
                '[Typing] Checking typingStatus[$recipientId] = ${typingStatus[recipientId]}',
              );

              // Check if recipient is typing
              final isRecipientTyping = typingStatus[recipientId] == true;

              debugPrint('[Typing] Recipient is typing: $isRecipientTyping');

              // Cache the typing status
              _cachedRecipientTyping = isRecipientTyping;

              // Update state with new typing status
              final updatedState = state;
              if (updatedState is ChatLoaded) {
                final oldIsTyping = updatedState.isRecipientTyping;

                // Always emit even if value appears same - Firestore might have updated other fields
                final newState = updatedState.copyWith(
                  isRecipientTyping: isRecipientTyping,
                );

                if (oldIsTyping != isRecipientTyping) {
                  debugPrint(
                    '[Typing] Typing status changed from $oldIsTyping to $isRecipientTyping',
                  );
                } else {
                  debugPrint(
                    '[Typing] Typing status unchanged ($isRecipientTyping), but emitting to ensure UI updates',
                  );
                }

                emit(newState);
                debugPrint(
                  '[Typing] Emitted new ChatLoaded state with isRecipientTyping: $isRecipientTyping',
                );
              } else {
                // State is not ChatLoaded yet, emit a new ChatLoaded state with cached messages
                debugPrint(
                  '[Typing] Current state is not ChatLoaded (${updatedState.runtimeType}), creating ChatLoaded with cached messages',
                );

                if (_cachedMessages.isNotEmpty && _currentChatId.isNotEmpty) {
                  final newState = ChatLoaded(
                    chatId: _currentChatId,
                    messages: _cachedMessages,
                    isRecipientTyping: isRecipientTyping,
                    isSharingLocation: false,
                  );
                  emit(newState);
                  debugPrint(
                    '[Typing] Emitted ChatLoaded state with cached messages and isRecipientTyping: $isRecipientTyping',
                  );
                } else {
                  debugPrint(
                    '[Typing] Cached messages or chatId not available, skipping emission',
                  );
                }
              }
            },
            onError: (error) {
              debugPrint('[Typing] Error listening to typing status: $error');
            },
          );
    } catch (e) {
      debugPrint('[Typing] Exception in _onListenTypingStatus: $e');
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

  /// Handle sharing live location
  /// Requests permissions, captures initial location, sends invitation message,
  /// and starts streaming location updates to Firestore
  Future<void> _onShareLiveLocation(
    ChatShareLiveLocation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      // Check location service status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(const ChatError('Location services are disabled'));
        return;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(const ChatError('Location permissions are denied'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(const ChatError('Location permissions are permanently denied'));
        return;
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Send invitation message
      final messageData = <String, dynamic>{
        'senderId': currentUserId,
        'text': '📍 Shared my live location.',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'messageType': 'location',
        'locationData': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(event.chatId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(event.chatId)
          .update({
            'lastMessage': {
              'text': '📍 Shared my live location.',
              'senderId': currentUserId,
              'timestamp': FieldValue.serverTimestamp(),
            },
          });

      // Update state to indicate location sharing is active
      final currentState = state;
      if (currentState is ChatLoaded) {
        emit(currentState.copyWith(isSharingLocation: true));
      } else {
        emit(ChatSharingLocation(event.chatId));
      }

      // Start live location updates
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position position) {
            // Update live location in Firestore
            FirebaseFirestore.instance
                .collection('chats')
                .doc(event.chatId)
                .collection('liveLocations')
                .doc(currentUserId)
                .set({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
          });
    } catch (e) {
      emit(ChatError('Failed to share location: $e'));
    }
  }

  /// Handle stopping live location sharing
  /// Cancels the position stream and removes location data from Firestore
  Future<void> _onStopSharingLocation(
    ChatStopSharingLocation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(event.chatId)
            .collection('liveLocations')
            .doc(currentUserId)
            .delete();
      }

      // Update state to indicate location sharing stopped
      final currentState = state;
      if (currentState is ChatLoaded) {
        emit(currentState.copyWith(isSharingLocation: false));
      }
    } catch (e) {
      emit(ChatError('Failed to stop sharing location: $e'));
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _typingStatusSubscription?.cancel();
    _typingTimer?.cancel();
    return super.close();
  }
}

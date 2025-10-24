import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'map_screen.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../blocs/chat/chat_state.dart';
import '../../widgets/typing_indicator.dart';
import '../../services/typing_service.dart';

/// ChatScreen - A complete StatefulWidget for real-time one-on-one chat
/// Displays messages using Firestore StreamBuilder and allows sending messages
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String recipientPhotoUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isScreenActive = true; // Track if screen is visible and in foreground
  bool _isSharingLocation = false;
  late final TypingService _typingService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _typingService = TypingService();

    // Mark messages as delivered when this chat screen is opened
    _markMessagesAsDelivered();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _typingService.dispose(widget.chatId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      // Only mark messages as read when app is in foreground
      _isScreenActive = state == AppLifecycleState.resumed;
    });
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Today: show time
      return DateFormat.jm().format(date);
    } else if (difference.inDays == 1) {
      return 'yesterday at ${DateFormat.jm().format(date)}';
    } else if (difference.inDays < 7) {
      return '${DateFormat.E().format(date)} at ${DateFormat.jm().format(date)}';
    } else {
      return DateFormat.yMMMd().add_jm().format(date);
    }
  }

  /// Mark all undelivered messages from the other user as 'delivered'
  /// This runs once when the chat screen is opened
  Future<void> _markMessagesAsDelivered() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserUid)
          .where('status', isEqualTo: 'sent')
          .get();

      if (messagesSnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'status': 'delivered'});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark messages as delivered: $e');
    }
  }

  /// Update message statuses to 'read' for messages sent by the other user
  /// This function uses batch writes for efficient updates
  /// IMPORTANT: Only marks as 'read' when the app is in foreground and this screen is active
  Future<void> _updateStatuses(List<DocumentSnapshot> docs) async {
    // Only mark as read if screen is active (in foreground)
    if (!_isScreenActive) return;

    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();

    bool hasUpdates = false;

    // Loop through messages and mark unread messages from other user as 'read'
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final status = data['status'] as String?;

      // Only update messages sent by the other user that are not yet 'read'
      if (senderId != currentUserUid && status != 'read') {
        batch.update(doc.reference, {'status': 'read'});
        hasUpdates = true;
      }
    }

    // Commit batch only if there are updates to perform
    if (hasUpdates) {
      try {
        await batch.commit();
      } catch (e) {
        // Silently fail for read receipts
        debugPrint('Failed to update message statuses: $e');
      }
    }
  }

  /// Share live location with the chat
  /// Dispatches ChatShareLiveLocation event to BLoC
  /// BLoC handles: permissions, initial location, message sending, and stream management
  Future<void> _shareLiveLocation() async {
    try {
      // Dispatch event to ChatBloc which handles all location sharing logic
      if (mounted && context.mounted) {
        context.read<ChatBloc>().add(
          ChatShareLiveLocation(
            chatId: widget.chatId,
            recipientId: widget.recipientId,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Stop sharing live location
  /// Dispatches ChatStopSharingLocation event to BLoC
  /// BLoC handles: stream cancellation and Firestore cleanup
  Future<void> _stopSharingLocation() async {
    try {
      // Dispatch event to ChatBloc which handles cleanup
      if (mounted && context.mounted) {
        context.read<ChatBloc>().add(ChatStopSharingLocation(widget.chatId));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Failed to stop sharing location: $e');
    }
  }

  /// Handle text input changes to detect typing
  /// Updates Firestore typing status using TypingService
  void _handleTyping() {
    if (_messageController.text.trim().isNotEmpty) {
      _typingService.updateTypingStatus(widget.chatId, true);
    }
  }

  /// Send a text message to Firestore
  /// This function performs validation and a two-step write process:
  /// 1. Adds the message to the messages subcollection
  /// 2. Updates the lastMessage field in the parent chat document
  Future<void> _sendMessage() async {
    // Validate: Check if message is not empty after trimming whitespace
    final trimmedText = _messageController.text.trim();
    if (trimmedText.isEmpty) {
      return; // Do nothing if message is empty
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Create message data with all required fields
      final messageData = <String, dynamic>{
        'senderId': currentUserId,
        'text': trimmedText,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'messageType': 'text',
      };

      // Step 1: Add message to messages subcollection
      // This stores the actual message content
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      // Step 2: Update lastMessage in parent chat document
      // This is crucial for showing chat previews on the home screen
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
            'lastMessage': {
              'text': trimmedText,
              'senderId': currentUserId,
              'timestamp': FieldValue.serverTimestamp(),
            },
          });

      // Cleanup: Clear the text field after sending
      _messageController.clear();

      // Stop typing indicator
      _typingService.updateTypingStatus(widget.chatId, false);
    } catch (e) {
      // Show error to user if sending fails
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.recipientId)
              .snapshots(),
          builder: (context, snapshot) {
            String subtitle = '';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isOnline = data['isOnline'] == true;
              final lastSeen = data['lastSeen'] as Timestamp?;

              if (isOnline) {
                subtitle = 'Online';
              } else if (lastSeen != null) {
                subtitle = 'Last seen: ${_formatLastSeen(lastSeen.toDate())}';
              }
            }

            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.recipientPhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(widget.recipientPhotoUrl)
                      : null,
                  child: widget.recipientPhotoUrl.isEmpty
                      ? Text(
                          widget.recipientName.isNotEmpty
                              ? widget.recipientName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recipientName,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: BlocListener<ChatBloc, ChatState>(
        listener: (context, state) {
          // Listen for error states and show snackbar
          if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          // Listen for location sharing state changes
          if (state is ChatSharingLocation) {
            setState(() {
              _isSharingLocation = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Started sharing live location'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          if (state is ChatLoaded) {
            // Update UI based on location sharing state
            setState(() {
              _isSharingLocation = state.isSharingLocation;
            });
          }
        },
        child: Column(
          children: [
            // Location sharing banner
            if (_isSharingLocation)
              Container(
                color: Colors.blue[100],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You are sharing your live location',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _stopSharingLocation,
                      child: const Text(
                        'Stop',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Part 1: Real-Time Message Display
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Listen to messages subcollection with real-time updates
                // Query orders by timestamp descending (newest first in Firestore)
                // This works perfectly with ListView's reverse: true property
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Handle loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Handle error state
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  }

                  // Handle empty state
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Say hi to ${widget.recipientName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  // Update message statuses to 'read' when viewing
                  _updateStatuses(messages);

                  // Display messages using ListView.builder
                  // reverse: true makes the list start from the bottom (most recent message visible)
                  // descending: true in the query means newest messages come first in the list
                  // Together they ensure: newest messages appear at bottom, scroll starts at bottom
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Start from bottom - essential for chat UI
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      // Since reverse:true and descending:true, messages[0] is the newest
                      // and will appear at the bottom of the screen
                      final message =
                          messages[index].data() as Map<String, dynamic>;
                      final senderId = message['senderId'] as String;
                      final text = message['text'] as String? ?? '';
                      final timestamp = message['timestamp'] as Timestamp?;
                      final status = message['status'] as String? ?? 'sent';
                      final messageType =
                          message['messageType'] as String? ?? 'text';
                      final locationData =
                          message['locationData'] as Map<String, dynamic>?;

                      // Display MessageBubble with proper styling including status ticks
                      return MessageBubble(
                        text: text,
                        senderId: senderId,
                        status: status,
                        timestamp: timestamp?.toDate(),
                        messageType: messageType,
                        locationData: locationData,
                        onLocationTap: () {
                          // Navigate to MapScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapScreen(
                                chatId: widget.chatId,
                                recipientId: senderId,
                                recipientName:
                                    senderId ==
                                        FirebaseAuth.instance.currentUser!.uid
                                    ? 'Your'
                                    : widget.recipientName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // Typing Indicator - Shows when recipient is typing
            StreamBuilder<List<String>>(
              stream: _typingService.getTypingStatusStream(widget.chatId),
              initialData: const [],
              builder: (context, typingSnapshot) {
                final isRecipientTyping =
                    typingSnapshot.data?.contains(widget.recipientId) ?? false;

                if (!isRecipientTyping) {
                  return const SizedBox.shrink(); // No widget when not typing
                }

                // Show typing indicator when recipient is typing
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TypingIndicator(),
                );
              },
            ),

            // Part 2: Message Input Area
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                child: Row(
                  children: [
                    // Location sharing button
                    IconButton(
                      icon: Icon(
                        _isSharingLocation
                            ? Icons.location_off
                            : Icons.location_on,
                        color: _isSharingLocation ? Colors.red : Colors.black87,
                      ),
                      onPressed: () {
                        print(
                          'Location button tapped - Sharing: $_isSharingLocation',
                        );
                        if (_isSharingLocation) {
                          _stopSharingLocation();
                        } else {
                          _shareLiveLocation();
                        }
                      },
                      tooltip: _isSharingLocation
                          ? 'Stop sharing location'
                          : 'Share live location',
                    ),
                    // Expanded TextField for typing messages
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          onChanged: (_) => _handleTyping(),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send IconButton
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MessageBubble Widget - Displays individual messages
/// Differentiates between sent and received messages with styling
/// Shows status ticks (sent/delivered/read) for sent messages
class MessageBubble extends StatelessWidget {
  final String text;
  final String senderId;
  final String status;
  final DateTime? timestamp;
  final String messageType;
  final Map<String, dynamic>? locationData;
  final VoidCallback? onLocationTap;

  const MessageBubble({
    super.key,
    required this.text,
    required this.senderId,
    required this.status,
    this.timestamp,
    this.messageType = 'text',
    this.locationData,
    this.onLocationTap,
  });

  /// Helper function to build status icon based on message status
  /// WhatsApp-style status indicators:
  /// - Single grey tick for 'sent'
  /// - Double grey ticks for 'delivered'
  /// - Double blue ticks for 'read'
  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'read':
        return const Icon(
          Icons.done_all, // Double tick
          color: Colors.blue, // Blue for read
          size: 16,
        );
      case 'delivered':
        return const Icon(
          Icons.done_all, // Double tick
          color: Colors.grey, // Grey for delivered
          size: 16,
        );
      case 'sent':
        return const Icon(
          Icons.done, // Single tick
          color: Colors.grey, // Grey for sent
          size: 16,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if message was sent by current user
    final isSentByMe = senderId == FirebaseAuth.instance.currentUser!.uid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: messageType == 'location' ? onLocationTap : null,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Primary color (black) for sent messages
              // Grey color for received messages
              color: isSentByMe ? Colors.black87 : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isSentByMe ? 20 : 6),
                bottomRight: Radius.circular(isSentByMe ? 6 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location preview for location messages
                if (messageType == 'location' && locationData != null) ...[
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Static map preview using Google Maps Static API
                          Image.network(
                            'https://maps.googleapis.com/maps/api/staticmap?'
                            'center=${locationData!['latitude']},${locationData!['longitude']}'
                            '&zoom=15&size=400x300&maptype=roadmap'
                            '&markers=color:red%7C${locationData!['latitude']},${locationData!['longitude']}'
                            '&key=${dotenv.env['GOOGLE_API_KEY']?.replaceAll("'", "").replaceAll('"', "").trim() ?? ""}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.map,
                                      size: 48,
                                      color: isSentByMe
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to view location',
                                      style: TextStyle(
                                        color: isSentByMe
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Overlay for tap indicator
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(
                            bottom: 8,
                            right: 8,
                            child: Icon(
                              Icons.open_in_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Message text
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isSentByMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    // Status icon - only visible for sent messages
                    if (isSentByMe) ...[
                      const SizedBox(width: 6),
                      _buildStatusIcon(status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

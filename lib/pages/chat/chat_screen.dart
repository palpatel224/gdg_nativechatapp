import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ChatScreen - A complete StatefulWidget for real-time one-on-one chat
/// Displays messages using Firestore StreamBuilder and allows sending messages
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientName;
  final String recipientPhotoUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.recipientName,
    required this.recipientPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages as delivered when this chat screen is opened
    _markMessagesAsDelivered();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
  Future<void> _updateStatuses(List<DocumentSnapshot> docs) async {
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
        title: Row(
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
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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

                    // Display MessageBubble with proper styling including status ticks
                    return MessageBubble(
                      text: text,
                      senderId: senderId,
                      status: status,
                      timestamp: timestamp?.toDate(),
                    );
                  },
                );
              },
            ),
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
                  // Expanded TextField for typing messages
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
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

  const MessageBubble({
    super.key,
    required this.text,
    required this.senderId,
    required this.status,
    this.timestamp,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Message text
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
        ),
      ),
    );
  }
}

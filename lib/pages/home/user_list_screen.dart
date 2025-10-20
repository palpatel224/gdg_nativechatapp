import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../chat/chat_page.dart';

/// UserListScreen - Displays a list of all registered users from Firestore
/// Allows the current user to select someone to chat with
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _isCreatingChat = false;

  /// Handle user tap - create or get chat and navigate to ChatPage
  /// CRITICAL: This ensures the chat document exists in Firestore BEFORE navigation
  /// This fixes the edge case where new chats don't appear on the home page
  Future<void> _handleUserTap(AppUser user) async {
    if (_isCreatingChat) return;

    setState(() {
      _isCreatingChat = true;
    });

    try {
      // Get the current user's UID
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Get the tapped user's UID
      final otherUserId = user.uid;

      // Generate a unique and consistent chatId for this one-on-one chat
      // by sorting the two UIDs alphabetically and joining them with an underscore.
      // This ensures that no matter which user initiates the chat, the same
      // chat room ID is always generated (e.g., "alpha456_zulu123" will always
      // be the same for users "alpha456" and "zulu123").
      final List<String> userIds = [currentUserId, otherUserId];
      userIds.sort(); // Sort alphabetically to ensure consistency
      final chatId = userIds.join(
        '_',
      ); // Join with underscore: "alpha456_zulu123"

      // CRITICAL FIX: Create or update the chat document using set with merge
      // This ensures the chat document exists before navigation without requiring a read
      // Using SetOptions(merge: true) prevents overwriting existing data
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': {
          'text': '', // Empty initially
          'senderId': '',
          'timestamp': FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'typingStatus': {currentUserId: false, otherUserId: false},
      }, SetOptions(merge: true)); // Merge to avoid overwriting existing chats

      if (!mounted) return;

      // Navigate to ChatPage with the chat information
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            chatId: chatId,
            userName: user.displayName,
            userAvatar: user.photoUrl,
            isOnline: user.isOnline,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingChat = false;
        });
      }
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
        title: const Text(
          'New Chat',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream to listen to real-time updates from Firestore 'users' collection
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          // Handle the waiting state while data is being fetched
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle error state if the stream encounters an error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Check if snapshot has data
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data available'));
          }

          // Get the current logged-in user's UID
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          // Convert Firestore documents to AppUser objects
          final allUsers = snapshot.data!.docs
              .map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          // Filter out the current user from the list
          // This ensures the current user doesn't see themselves in the user list
          final filteredUsers = allUsers
              .where((user) => user.uid != currentUserId)
              .toList();

          // Handle empty list case after filtering
          if (filteredUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No other users are registered yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Display the filtered list of users using ListView.builder for efficiency
          return Container(
            color: Colors.white,
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];

                return ListTile(
                  // Display user's profile picture
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Display user's display name
                  title: Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  // Display user's status
                  subtitle: Text(
                    user.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  // Add online indicator
                  trailing: user.isOnline
                      ? Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  // Handle tap to create or get chat and navigate to ChatScreen
                  onTap: _isCreatingChat ? null : () => _handleUserTap(user),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

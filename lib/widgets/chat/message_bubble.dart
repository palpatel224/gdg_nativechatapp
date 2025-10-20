import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;

  const MessageBubble({super.key, required this.message});

  /// Helper function to build status icon based on message status
  /// WhatsApp-style status indicators:
  /// - Single grey tick for 'sent'
  /// - Double grey ticks for 'delivered'
  /// - Double blue ticks for 'read'
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.read:
        return const Icon(
          Icons.done_all, // Double tick
          color: Colors.blue, // Blue for read
          size: 16,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all, // Double tick
          color: Colors.grey, // Grey for delivered
          size: 16,
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.done, // Single tick
          color: Colors.grey, // Grey for sent
          size: 16,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isSentByMe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 6),
              bottomRight: Radius.circular(isMe ? 6 : 20),
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
              // Message content
              Flexible(
                child: message.messageType == MessageType.text
                    ? Text(
                        message.text ?? '',
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      )
                    : message.messageType == MessageType.location
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                color: isMe ? Colors.white : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          if (message.locationData != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              message.locationData!.address,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${message.locationData!.latitude.toStringAsFixed(4)}, '
                              'Lon: ${message.locationData!.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              // Status icon - only visible for sent messages
              if (isMe) ...[
                const SizedBox(width: 6),
                _buildStatusIcon(message.status),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

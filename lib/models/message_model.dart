import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, location }

enum MessageStatus { sent, delivered, read }

class LocationData extends Equatable {
  final double latitude;
  final double longitude;
  final String address;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
  };

  factory LocationData.fromMap(Map<String, dynamic> map) => LocationData(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    address: map['address'] ?? '',
  );

  @override
  List<Object?> get props => [latitude, longitude, address];
}

class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String? text;
  final MessageType messageType;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isSentByMe;
  final LocationData? locationData;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.text,
    this.messageType = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isSentByMe = false,
    this.locationData,
  });

  factory MessageModel.fromFirestore(
    DocumentSnapshot doc,
    String currentUserId,
    String senderName,
    String senderAvatar,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    final messageTypeStr = data['messageType'] as String? ?? 'text';
    final statusStr = data['status'] as String? ?? 'sent';

    LocationData? location;
    if (data['locationData'] != null) {
      location = LocationData.fromMap(
        data['locationData'] as Map<String, dynamic>,
      );
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: senderName,
      senderAvatar: senderAvatar,
      text: data['text'],
      messageType: messageTypeStr == 'location'
          ? MessageType.location
          : MessageType.text,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(statusStr),
      isSentByMe: data['senderId'] == currentUserId,
      locationData: location,
    );
  }

  static MessageStatus _parseStatus(String status) {
    switch (status) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sent;
    }
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'status': status.name,
    'messageType': messageType.name,
    if (locationData != null) 'locationData': locationData!.toMap(),
  };

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    senderAvatar,
    text,
    messageType,
    timestamp,
    status,
    isSentByMe,
    locationData,
  ];
}

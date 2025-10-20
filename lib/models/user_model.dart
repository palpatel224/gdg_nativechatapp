import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? email;
  final String displayName;
  final String photoUrl;
  final String status;
  final bool isOnline;
  final DateTime? lastSeen;
  final List<String> fcmTokens;

  AppUser({
    required this.uid,
    this.email,
    required this.displayName,
    required this.photoUrl,
    required this.status,
    this.isOnline = false,
    this.lastSeen,
    this.fcmTokens = const [],
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'status': status,
    'isOnline': isOnline,
    'lastSeen': lastSeen != null
        ? Timestamp.fromDate(lastSeen!)
        : FieldValue.serverTimestamp(),
    'fcmTokens': fcmTokens,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    uid: m['uid'] ?? '',
    email: m['email'],
    displayName: m['displayName'] ?? 'Guest User',
    photoUrl: m['photoUrl'] ?? '',
    status: m['status'] ?? 'Hey there! I\'m new here.',
    isOnline: m['isOnline'] ?? false,
    lastSeen: m['lastSeen'] != null
        ? (m['lastSeen'] as Timestamp).toDate()
        : null,
    fcmTokens: m['fcmTokens'] != null ? List<String>.from(m['fcmTokens']) : [],
  );

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? status,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? fcmTokens,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }
}

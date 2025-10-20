import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Creates a user profile document in Firestore if it doesn't already exist.
  /// This function should be called after successful authentication (sign-up or sign-in).
  ///
  /// The function checks if the user document exists before creating it to prevent
  /// overwriting existing user data on subsequent logins.
  Future<void> createUserProfileInFirestore(User user) async {
    try {
      // Get a reference to the user document using the user's UID
      final userDocRef = _firestore.collection('users').doc(user.uid);

      // Check if the document already exists
      final docSnapshot = await userDocRef.get();

      // Only create the document if it doesn't exist
      if (!docSnapshot.exists) {
        // Prepare the initial user profile data
        final userData = {
          'uid': user.uid,
          'displayName':
              (user.displayName != null && user.displayName!.isNotEmpty)
              ? user.displayName
              : 'Guest User',
          'photoUrl': user.photoURL ?? '',
          'status': 'Hey there! I\'m new here.',
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
          'fcmTokens': <String>[],
        };

        // Create the document with initial data
        await userDocRef.set(userData);
        print('User profile created successfully for UID: ${user.uid}');
      } else {
        print('User profile already exists for UID: ${user.uid}');
      }
    } catch (e) {
      // Handle any errors that occur during the Firestore operation
      print('Error creating user profile in Firestore: $e');
      rethrow; // Re-throw to allow caller to handle the error if needed
    }
  }

  Future<void> createOrUpdateProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<String?> uploadProfilePhoto(String uid, File file) async {
    final ref = _storage.ref().child('users/$uid/profile.jpg');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }
}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

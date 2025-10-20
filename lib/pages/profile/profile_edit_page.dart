import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../repositories/auth_repository.dart';
import '../../models/user_model.dart';

class ProfileEditPage extends StatefulWidget {
  final IAuthRepository repo;
  const ProfileEditPage({super.key, required this.repo});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _name = TextEditingController();
  final _status = TextEditingController();
  File? _photo;

  Future<void> _pickPhoto() async {
    final p = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (p != null) setState(() => _photo = File(p.path));
  }

  Future<void> _save() async {
    final uid = widget.repo.currentUser?.uid;
    final email = widget.repo.currentUser?.email;
    if (uid == null) return;

    String? photoUrl;
    if (_photo != null) {
      photoUrl = await widget.repo.uploadProfilePhoto(uid, _photo!);
    }

    final user = AppUser(
      uid: uid,
      email: email,
      displayName: _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : 'Guest User',
      photoUrl: photoUrl ?? '',
      status: _status.text.trim().isNotEmpty
          ? _status.text.trim()
          : 'Hey there! I\'m new here.',
    );
    await widget.repo.updateProfile(user);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 48,
                child: const Icon(Icons.camera_alt),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _status,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

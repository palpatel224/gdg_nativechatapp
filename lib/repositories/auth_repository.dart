import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';

abstract class IAuthRepository {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signUpWithEmail(String email, String password);
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> signInWithGoogle();
  Future<void> signOut();
  Future<void> updateProfile(AppUser user);
  Future<String?> uploadProfilePhoto(String uid, File file);
}

class AuthRepository implements IAuthRepository {
  final AuthService _authService;
  final ProfileService _profileService;
  final GoogleSignIn _googleSignIn;

  AuthRepository(
    this._authService,
    this._profileService, [
    GoogleSignIn? google,
  ]) : _googleSignIn = google ?? GoogleSignIn();

  @override
  Stream<User?> authStateChanges() => _authService.authStateChanges();

  @override
  User? get currentUser => _authService.currentUser;

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) =>
      _authService.signUpWithEmail(email: email, password: password);

  @override
  Future<UserCredential> signInWithEmail(String email, String password) =>
      _authService.signInWithEmail(email: email, password: password);

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<UserCredential> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign in aborted');
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    await _profileService.createOrUpdateProfile(user.uid, user.toMap());
  }

  @override
  Future<String?> uploadProfilePhoto(String uid, File file) =>
      _profileService.uploadProfilePhoto(uid, file);
}

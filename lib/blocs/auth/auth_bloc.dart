import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository _repo;
  StreamSubscription? _sub;

  AuthBloc(this._repo) : super(AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignedOut>(_onSignOut);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);

    _sub = _repo.authStateChanges().listen((user) {
      if (user != null)
        add(AuthStarted());
      else
        add(AuthSignedOut());
    });
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final user = _repo.currentUser;
    if (user != null)
      emit(AuthAuthenticated(user));
    else
      emit(AuthUnauthenticated());
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _repo.signInWithEmail(
        event.email,
        event.password,
      );
      // Create user profile in Firestore if it doesn't exist
      await _repo.createUserProfile(credential.user!);
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Step 1: Create the user account
      final credential = await _repo.signUpWithEmail(
        event.email,
        event.password,
      );

      if (credential.user == null) {
        emit(AuthFailure('Failed to create user account'));
        return;
      }

      try {
        // Step 2: Update display name if provided
        if (event.displayName != null && event.displayName!.isNotEmpty) {
          await credential.user!.updateDisplayName(event.displayName);
        }

        // Step 3: Upload profile photo if provided (user is now authenticated)
        if (event.profilePhoto != null) {
          try {
            final photoUrl = await _repo.uploadProfilePhoto(
              credential.user!.uid,
              event.profilePhoto!,
            );
            if (photoUrl != null && photoUrl.isNotEmpty) {
              await credential.user!.updatePhotoURL(photoUrl);
            }
          } catch (photoError) {
            // Log photo upload error but don't fail the signup
            print('Photo upload failed: $photoError');
            // Continue with signup even if photo upload fails
          }
        }

        // Step 4: Reload user to get updated profile
        await credential.user!.reload();
        final updatedUser = _repo.currentUser;

        // Step 5: Create user profile in Firestore with the updated user info
        await _repo.createUserProfile(updatedUser ?? credential.user!);

        emit(AuthAuthenticated(updatedUser ?? credential.user!));
      } catch (profileError) {
        // If profile update fails, still authenticate the user
        print('Profile update error: $profileError');
        // Try to create basic Firestore profile
        try {
          await _repo.createUserProfile(credential.user!);
        } catch (firestoreError) {
          print('Firestore creation error: $firestoreError');
        }
        emit(AuthAuthenticated(credential.user!));
      }
    } catch (e) {
      print('Signup error: $e');
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignOut(AuthSignedOut event, Emitter<AuthState> emit) async {
    await _repo.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final credential = await _repo.signInWithGoogle();
      // Create user profile in Firestore if it doesn't exist
      await _repo.createUserProfile(credential.user!);
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

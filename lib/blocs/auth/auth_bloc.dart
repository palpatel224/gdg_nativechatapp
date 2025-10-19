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
      final credential = await _repo.signUpWithEmail(
        event.email,
        event.password,
      );
      if (event.displayName != null) {
        await credential.user?.updateDisplayName(event.displayName);
      }
      emit(AuthAuthenticated(credential.user!));
    } catch (e) {
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

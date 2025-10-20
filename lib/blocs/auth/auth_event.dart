import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthSignedOut extends AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignInRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? displayName;
  final File? profilePhoto;
  AuthSignUpRequested(
    this.email,
    this.password, {
    this.displayName,
    this.profilePhoto,
  });
  @override
  List<Object?> get props => [email, password, displayName, profilePhoto];
}

class AuthGoogleSignInRequested extends AuthEvent {}

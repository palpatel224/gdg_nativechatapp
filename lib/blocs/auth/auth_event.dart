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
  AuthSignUpRequested(this.email, this.password, {this.displayName});
  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthGoogleSignInRequested extends AuthEvent {}

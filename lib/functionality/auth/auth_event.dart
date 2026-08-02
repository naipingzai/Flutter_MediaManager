part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckEvent extends AuthEvent {
  const AuthCheckEvent();
}

class AuthLoginEvent extends AuthEvent {
  final String serverUrl;
  final String token;
  final String username;
  final String rootPath;
  final AuthMethod authMethod;

  const AuthLoginEvent({
    required this.serverUrl,
    required this.token,
    this.username = '',
    this.rootPath = '/life-journal',
    this.authMethod = AuthMethod.token,
  });

  @override
  List<Object?> get props => [serverUrl, token, username, rootPath, authMethod];
}

class AuthLogoutEvent extends AuthEvent {
  const AuthLogoutEvent();
}

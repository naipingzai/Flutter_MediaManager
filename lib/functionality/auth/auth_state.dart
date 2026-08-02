part of 'auth_bloc.dart';

enum AuthStatus {
  initial,
  checking,
  unauthenticated,
  loggingIn,
  authenticated,
  error,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final WebDavConfig? config;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.config,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    WebDavConfig? config,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      config: config ?? this.config,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, config, errorMessage];
}

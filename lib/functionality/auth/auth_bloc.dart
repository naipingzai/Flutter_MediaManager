import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/post.dart';
import '../../services/webdav_service.dart';
import '../../services/log_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  WebDavService? _webDavService;
  LogService? _logService;

  set webDavLogger(LogService logger) => _logService = logger;
  LogService? get logger => _logService;

  AuthBloc() : super(const AuthState()) {
    on<AuthCheckEvent>(_onCheck);
    on<AuthLoginEvent>(_onLogin);
    on<AuthLogoutEvent>(_onLogout);
  }

  WebDavService? get webDavService => _webDavService;

  void _log(String title, {String? detail, bool error = false}) {
    _logService?.log(
      error ? LogLevel.error : LogLevel.info,
      title,
      detail: detail,
      source: 'Auth',
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('timeout')) return '连接超时，请检查网络';
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return '无法连接到服务器，请检查地址';
    }
    if (msg.contains('HandshakeException') ||
        msg.contains('CertificateException')) {
      return 'SSL 证书验证失败';
    }
    if (msg.contains('401')) return '认证失败，请检查用户名和密码';
    if (msg.contains('403')) return '无权限访问，请检查账号权限';
    if (msg.contains('404')) return '服务器返回 404，请检查路径';
    if (msg.contains('500')) return '服务器内部错误';
    return '连接失败，请检查网络和服务器设置';
  }

  Future<void> _onCheck(AuthCheckEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.checking));
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('webdav_config');
      if (configJson == null) {
        _log('检查认证：无已保存配置，进入本地模式');
        emit(state.copyWith(status: AuthStatus.local));
        return;
      }
      WebDavConfig config;
      try {
        config = WebDavConfig.fromJson(jsonDecode(configJson));
      } catch (parseErr) {
        _log('旧配置解析失败，清除并重新开始', detail: parseErr.toString(), error: true);
        await prefs.remove('webdav_config');
        emit(state.copyWith(status: AuthStatus.unauthenticated));
        return;
      }
      _webDavService = WebDavService(config);
      _webDavService!.logger = _logService;
      _log('检查已有配置连接', detail: config.rootUrl);
      final connected = await _webDavService!.testConnection();
      _log(connected ? '自动连接成功' : '自动连接失败',
          detail: config.rootUrl, error: !connected);
      if (connected) {
        emit(state.copyWith(status: AuthStatus.authenticated, config: config));
      } else {
        // 连接失败不清除配置，进入本地模式（配置保留以便重试）
        emit(state.copyWith(status: AuthStatus.local, config: config));
      }
    } catch (e) {
      _logService?.error('认证检查异常', detail: e.toString());
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('webdav_config');
      } catch (_) {}
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loggingIn));
    _log('开始登录', detail: '${event.serverUrl} ${event.rootPath}');
    try {
      final config = WebDavConfig(
        serverUrl: event.serverUrl,
        token: event.token,
        username: event.username,
        rootPath: event.rootPath.isNotEmpty
            ? event.rootPath
            : '/flutter_media_manager',
        authMethod: event.authMethod,
      );
      _webDavService = WebDavService(config);
      _webDavService!.logger = _logService;
      _log('测试 WebDAV 连接', detail: config.rootUrl);
      final result = await _webDavService!.testConnectionDetailed();
      _log(result.success ? '连接成功' : '连接失败',
          detail: result.toString(), error: !result.success);
      if (!result.success) {
        _log('连接失败', detail: result.errorDetail, error: true);
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: '连接失败: ${result.errorDetail}',
        ));
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('webdav_config', jsonEncode(config.toJson()));
      _log('登录成功，配置已保存');
      emit(state.copyWith(status: AuthStatus.authenticated, config: config));
    } catch (e) {
      _logService?.error('登录异常', detail: e.toString());
      emit(state.copyWith(
          status: AuthStatus.error, errorMessage: _friendlyError(e)));
    }
  }

  Future<void> _onLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    _log('退出登录');
    final prefs = await SharedPreferences.getInstance();
    // ★ 只清除 WebDAV 配置；其他设置（昵称/头像/同步开关/同步间隔）必须保留
    //  修复：原来用 prefs.clear() 会误删所有 SharedPreferences，导致用户退出登录后
    //  丢失本地设置（昵称、头像路径、主题等），并使云端数据管理切换逻辑出错
    await prefs.remove('webdav_config');
    _webDavService = null;
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}

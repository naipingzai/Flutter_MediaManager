import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../functionality/auth/auth_bloc.dart';
import '../../models/post.dart';

/// WebDAV 登录页面
///
/// [fromProfile] 用于在登录成功后清除整个调用栈（ProfileScreen + LoginScreen）。
/// 当为 true 时，登录成功后会用 pushAndRemoveUntil 跳到 HomeScreen。
class LoginScreen extends StatefulWidget {
  final bool fromProfile;
  const LoginScreen({super.key, this.fromProfile = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _tokenController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _obscureToken = true;

  // webdav
  AuthMethod _authMethod = AuthMethod.basic;

  // Web 端自动预填 CORS 代理地址 + 默认账号密码
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final uri = Uri.base;
      final proxyParam = uri.queryParameters['proxy'];
      if (proxyParam != null && proxyParam.isNotEmpty) {
        _serverController.text = proxyParam;
      } else {
        final host = uri.host;
        if (host == 'localhost' || host == '127.0.0.1') {
          _serverController.text = 'http://localhost:8080/webdav';
        } else {
          _serverController.text = 'http://$host:8080/webdav';
        }
      }
      _usernameController.text = uri.queryParameters['user'] ?? '17302587963';
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _tokenController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthLoginEvent(
            serverUrl: _serverController.text.trim(),
            token: _tokenController.text.trim(),
            username: _authMethod == AuthMethod.basic
                ? _usernameController.text.trim()
                : '',
            authMethod: _authMethod,
          ));
    }
  }

  /// 返回 - 清空表单+重置状态，让用户重新输入
  void _onReset() {
    _serverController.clear();
    _tokenController.clear();
    _usernameController.clear();
    _authMethod = AuthMethod.basic;
    // 重置 bloc 状态
    context.read<AuthBloc>().add(const AuthLogoutEvent());
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {});
  }

  /// 取消正在进行的连接
  void _onCancel() {
    context.read<AuthBloc>().add(const AuthLogoutEvent());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // 永远显示 AppBar，含返回按钮
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '返回',
          onPressed: () {
            // 弹出到上一页（如果有的话）
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              _onReset();
            }
          },
        ),
        title: const Text('连接 WebDAV'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.status == AuthStatus.error &&
                state.errorMessage != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: cs.error,
                    duration: const Duration(seconds: 6),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: '清空',
                      textColor: cs.onError,
                      onPressed: _onReset,
                    ),
                  ),
                );
              });
            }
            // 登录成功后：从 ProfileScreen 进入的情况下，清除整个调用栈
            if (state.status == AuthStatus.authenticated &&
                widget.fromProfile) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            }
          },
          builder: (context, state) {
            final isLoading = state.status == AuthStatus.loggingIn;
            final hasError = state.status == AuthStatus.error;
            final errorText = state.errorMessage;

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 56,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '媒体管理',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '连接 WebDAV 服务器开始使用',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 错误提示卡片
                            if (hasError && errorText != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: cs.error.withOpacity(0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            color: cs.error, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          '连接失败',
                                          style: textTheme.titleSmall?.copyWith(
                                            color: cs.onErrorContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      errorText,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: cs.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 认证方式切换
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    cs.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _authMethod = AuthMethod.token),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _authMethod == AuthMethod.token
                                              ? cs.primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '令牌登录',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _authMethod ==
                                                      AuthMethod.token
                                                  ? cs.onPrimary
                                                  : cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _authMethod = AuthMethod.basic),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _authMethod == AuthMethod.basic
                                              ? cs.primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '账号密码',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _authMethod ==
                                                      AuthMethod.basic
                                                  ? cs.onPrimary
                                                  : cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 服务器地址
                            TextFormField(
                              controller: _serverController,
                              enabled: !isLoading,
                              decoration: InputDecoration(
                                labelText: '服务器地址',
                                prefixIcon: const Icon(Icons.dns_outlined),
                              ),
                              keyboardType: TextInputType.url,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return '请输入服务器地址';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Token 模式
                            if (_authMethod == AuthMethod.token)
                              TextFormField(
                                controller: _tokenController,
                                enabled: !isLoading,
                                obscureText: _obscureToken,
                                decoration: InputDecoration(
                                  labelText: '访问令牌',
                                  hintText: 'App 密码或 Token',
                                  prefixIcon:
                                      const Icon(Icons.vpn_key_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureToken
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () {
                                      setState(
                                          () => _obscureToken = !_obscureToken);
                                    },
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '请输入访问令牌';
                                  }
                                  return null;
                                },
                              ),

                            // Basic Auth 模式
                            if (_authMethod == AuthMethod.basic) ...[
                              TextFormField(
                                controller: _usernameController,
                                enabled: !isLoading,
                                decoration: const InputDecoration(
                                  labelText: '用户名',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return '请输入用户名';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _tokenController,
                                enabled: !isLoading,
                                obscureText: _obscureToken,
                                decoration: InputDecoration(
                                  labelText: '密码',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureToken
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () {
                                      setState(
                                          () => _obscureToken = !_obscureToken);
                                    },
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '请输入密码';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            // 主操作按钮 - Loading时显示「取消」, 错误时显示「重新连接」, 否则显示「连接」
                            if (isLoading)
                              FilledButton.tonal(
                                onPressed: _onCancel,
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.close_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('取消连接',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            else
                              FilledButton(
                                onPressed: _onLogin,
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_outlined, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      hasError ? '重新连接' : '连接',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),

                            // 「清空表单」按钮 - 永远可见，让用户能重新输入
                            TextButton(
                              onPressed: _onReset,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('清空表单重新输入'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // 提示
                            Text(
                              _authMethod == AuthMethod.token
                                  ? '支持坚果云、Nextcloud、群晖等 WebDAV 服务的 App 密码或 Token'
                                  : '使用 WebDAV 服务的用户名和密码登录',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Loading 遮罩
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      color: cs.surface.withOpacity(0.5),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('正在连接 WebDAV 服务器...'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

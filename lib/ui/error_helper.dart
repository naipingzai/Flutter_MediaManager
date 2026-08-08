/// WebDAV / HTTP 错误消息助手
class ErrorHelper {
  ErrorHelper._();

  /// 把任意异常映射成用户友好的中文消息
  static String friendly(Object e, {String prefix = ''}) {
    final msg = e.toString();
    String result;

    if (msg.contains('401') || msg.contains('Unauthorized')) {
      result = '认证失败，请检查账号和令牌';
    } else if (msg.contains('403') || msg.contains('Forbidden')) {
      result = '无权限访问，请检查账号权限';
    } else if (msg.contains('404') || msg.contains('Not Found')) {
      result = '资源不存在或路径错误';
    } else if (msg.contains('407') || msg.contains('Proxy Authentication')) {
      result = '代理认证失败';
    } else if (msg.contains('500') || msg.contains('Internal Server Error')) {
      result = '服务器内部错误';
    } else if (msg.contains('502') || msg.contains('Bad Gateway')) {
      result = '网关错误';
    } else if (msg.contains('503') || msg.contains('Service Unavailable')) {
      result = '服务不可用';
    } else if (msg.contains('504') || msg.contains('Gateway Timeout')) {
      result = '网关超时';
    } else if (msg.contains('timeout')) {
      result = '连接超时，请检查网络';
    } else if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup')) {
      result = '无法连接到服务器，请检查地址';
    } else if (msg.contains('HandshakeException') ||
        msg.contains('CertificateException')) {
      result = 'SSL 证书验证失败';
    } else if (msg.contains('Connection refused')) {
      result = '服务器拒绝连接，请检查 WebDAV 服务是否运行';
    } else {
      result = '操作失败：$e';
    }

    if (prefix.isEmpty) return result;
    return '$prefix$result';
  }

  /// 检查是否是认证错误（需要重新登录）
  static bool isAuthError(Object e) {
    final msg = e.toString();
    return msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('Unauthorized') ||
        msg.contains('Forbidden');
  }
}

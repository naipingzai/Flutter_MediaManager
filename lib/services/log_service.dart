import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 日志级别
enum LogLevel { info, success, warning, error }

/// 单条日志
class AppLog {
  final DateTime timestamp;
  final LogLevel level;
  final String title;
  final String? detail;
  final String? source;

  const AppLog({
    required this.timestamp,
    required this.level,
    required this.title,
    this.detail,
    this.source,
  });

  String get formatted {
    final ts =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final src = source != null ? '[$source] ' : '';
    return '[$ts] $src$title${detail != null ? '\n  $detail' : ''}';
  }
}

/// 日志收集服务（可观察的日志列表）
class LogService extends ChangeNotifier {
  final ListQueue<AppLog> _logs = ListQueue();
  static const int _maxLogs = 500;

  /// 全部日志（只读列表）
  List<AppLog> get logs => _logs.toList(growable: false);

  /// 添加日志（同时输出到终端）
  void log(LogLevel level, String title, {String? detail, String? source}) {
    final entry = AppLog(
      timestamp: DateTime.now(),
      level: level,
      title: title,
      detail: detail,
      source: source,
    );
    _logs.addFirst(entry);
    while (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    // 统一输出到终端
    _printToConsole(entry);
    notifyListeners();
  }

  /// 输出日志到终端（始终输出）
  void _printToConsole(AppLog entry) {
    final levelTag = switch (entry.level) {
      LogLevel.info => 'INFO',
      LogLevel.success => 'OK',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERROR',
    };
    final src = entry.source != null ? '[${entry.source}] ' : '';
    final detail = entry.detail != null ? '\n  └─ ${entry.detail}' : '';
    final msg = '[$levelTag] $src${entry.title}$detail';
    developer.log(msg, name: 'AppLog');
    // ignore: avoid_print
    print(msg);
  }

  void info(String title, {String? detail, String? source}) =>
      log(LogLevel.info, title, detail: detail, source: source);

  void success(String title, {String? detail, String? source}) =>
      log(LogLevel.success, title, detail: detail, source: source);

  void warn(String title, {String? detail, String? source}) =>
      log(LogLevel.warning, title, detail: detail, source: source);

  void error(String title, {String? detail, String? source}) =>
      log(LogLevel.error, title, detail: detail, source: source);

  /// 清空日志
  void clear() {
    _logs.clear();
    notifyListeners();
  }

  /// 导出为文本
  String export() {
    return _logs.toList().reversed.join('\n');
  }
}

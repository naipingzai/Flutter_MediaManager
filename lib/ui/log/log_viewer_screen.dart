import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/log_service.dart';

/// 日志查看器（可复制）
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  bool _selectMode = false;
  final Set<int> _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final logService = LogServiceProvider.of(context);
    final logs = logService.logs;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _selectMode ? '已选 ${_selected.length} 条' : '日志 (${logs.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '返回',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_selectMode) ...[
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selected.length == logs.length ? '取消全选' : '全选',
              ),
            ),
            TextButton(
              onPressed: _selected.isEmpty ? null : _copySelected,
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selectMode = false;
                _selected.clear();
              }),
              child: const Text('取消'),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.copy_all_rounded),
              tooltip: '复制全部',
              onPressed: _copyAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空',
              onPressed: _clearAll,
            ),
          ],
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('暂无日志', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('操作记录会显示在这里',
                      style: textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final isSelected = _selected.contains(index);
                return _LogTile(
                  log: log,
                  selectMode: _selectMode,
                  isSelected: isSelected,
                  onTap: () => _onTapLog(index, logs.length),
                  onLongPress: () => _onLongPressLog(index),
                );
              },
            ),
    );
  }

  void _onTapLog(int index, int total) {
    if (_selectMode) {
      setState(() {
        if (_selected.contains(index)) {
          _selected.remove(index);
        } else {
          _selected.add(index);
        }
      });
    } else {
      _showLogDetail(context, LogServiceProvider.of(context).logs[index]);
    }
  }

  void _onLongPressLog(int index) {
    if (!_selectMode) {
      setState(() => _selectMode = true);
    }
    setState(() {
      _selected.add(index);
    });
  }

  void _toggleSelectAll() {
    final logs = LogServiceProvider.of(context).logs;
    setState(() {
      if (_selected.length == logs.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(List.generate(logs.length, (i) => i));
      }
    });
  }

  Future<void> _copySelected() async {
    final logs = LogServiceProvider.of(context).logs;
    final indices = _selected.toList()..sort();
    final text = indices.map((i) => logs[i].formatted).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${_selected.length} 条日志'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _copyAll() async {
    final logService = LogServiceProvider.of(context);
    final text = logService.export();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${logService.logs.length} 条日志到剪贴板'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              LogServiceProvider.of(ctx).clear();
              setState(() {
                _selectMode = false;
                _selected.clear();
              });
              Navigator.pop(ctx);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _showLogDetail(BuildContext context, AppLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LevelChip(level: log.level),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.title,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: '复制',
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: log.formatted));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('已复制到剪贴板'),
                                  duration: Duration(seconds: 2)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('时间: ${log.timestamp.toString().substring(0, 19)}',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  if (log.source != null) ...[
                    const SizedBox(height: 4),
                    Text('来源: ${log.source}',
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                  if (log.detail != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: SelectableText(
                          log.detail!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 简单的 LogService Provider 访问器（避免循环引用）
class LogServiceProvider {
  static LogService of(BuildContext context) {
    return context.read<LogService>();
  }
}

class _LogTile extends StatelessWidget {
  final AppLog log;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LogTile({
    required this.log,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _getLevelIcon() {
    switch (log.level) {
      case LogLevel.info:
        return Icons.info_outline_rounded;
      case LogLevel.success:
        return Icons.check_circle_outline_rounded;
      case LogLevel.warning:
        return Icons.warning_amber_outlined;
      case LogLevel.error:
        return Icons.error_outline_rounded;
    }
  }

  Color _getLevelColor(ColorScheme cs) {
    switch (log.level) {
      case LogLevel.info:
        return cs.primary;
      case LogLevel.success:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return cs.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _getLevelColor(cs);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outlineVariant.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? cs.primaryContainer.withOpacity(0.3) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              Icon(_getLevelIcon(), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatTime(log.timestamp)}${log.source != null ? ' • ${log.source}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selectMode)
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _LevelChip extends StatelessWidget {
  final LogLevel level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (level) {
      LogLevel.info => cs.primary,
      LogLevel.success => Colors.green,
      LogLevel.warning => Colors.orange,
      LogLevel.error => cs.error,
    };
    final text = switch (level) {
      LogLevel.info => 'INFO',
      LogLevel.success => 'OK',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERR',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

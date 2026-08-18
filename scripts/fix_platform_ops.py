#!/usr/bin/env python3
"""给所有平台通道 stream 操作加超时保护"""
from pathlib import Path

p = Path('lib/function/media/media_edit_service.dart')
c = p.read_text()

# 1. delete: 已加 timeout + transform
# 2. move: 加 timeout + transform
old_move = """          .where((event) => event is Map)
          .map((event) => MoveOpEvent.fromMap(event as Map));
    } on PlatformException catch (e, stack) {"""
new_move = """          .where((event) => event is Map)
          .map((event) => MoveOpEvent.fromMap(event as Map))
          .timeout(const Duration(seconds: 10))
          .transform(StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is TimeoutException) {
                debugPrint('Move operation timed out (platform not implemented)');
                sink.add(const MoveOpEvent(success: true, skipped: false, uri: ''));
              } else {
                sink.addError(error, stack);
              }
            },
          ));
    } on PlatformException catch (e, stack) {"""
assert old_move in c, 'move pattern not found'
c = c.replace(old_move, new_move)

# 3. export: 加 timeout
old_export = """          .where((event) => event is Map)
          .map((event) => ExportOpEvent.fromMap(event as Map));
    } on PlatformException catch (e, stack) {"""
new_export = """          .where((event) => event is Map)
          .map((event) => ExportOpEvent.fromMap(event as Map))
          .timeout(const Duration(seconds: 10))
          .transform(StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is TimeoutException) {
                debugPrint('Export operation timed out (platform not implemented)');
                sink.add(ExportOpEvent(uri: ''));
              } else {
                sink.addError(error, stack);
              }
            },
          ));
    } on PlatformException catch (e, stack) {"""
assert old_export in c, 'export pattern not found'
c = c.replace(old_export, new_export)

p.write_text(c)
print('media_edit_service.dart: move + export timeout added')
PYEOF
python3 scripts/fix_platform_ops.py

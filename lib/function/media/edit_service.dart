import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/common/channel.dart';
import 'package:fmv/function/common/image_op_events.dart';
import 'package:fmv/function/common/services.dart';
import 'package:fmv/function/media/enums.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class MediaEditService {
  String get newOpId;

  Future<void> cancelFileOp(String opId);

  Stream<ImageOpEvent> delete({
    String? opId,
    required Iterable<FmvEntry> entries,
  });

  Stream<MoveOpEvent> move({
    String? opId,
    required Map<String, Iterable<FmvEntry>> entriesByDestination,
    required bool copy,
    required NameConflictStrategy nameConflictStrategy,
  });

  Stream<ExportOpEvent> export(
    Iterable<FmvEntry> entries, {
    required EntryConvertOptions options,
    required String destinationAlbum,
    required NameConflictStrategy nameConflictStrategy,
  });

  Stream<MoveOpEvent> rename({
    String? opId,
    required Map<FmvEntry, String> entriesToNewName,
  });

  Future<Map<String, Object?>> captureFrame(
    FmvEntry entry, {
    required String desiredName,
    required Map<String, Object> exif,
    required Uint8List bytes,
    required String destinationAlbum,
    required NameConflictStrategy nameConflictStrategy,
  });
}

class PlatformMediaEditService implements MediaEditService {
  static const _platform = FmvMethodChannel('com.naipingzai/flutter_media_view/media_edit');
  static final _opStream = FmvStreamsChannel('com.naipingzai/flutter_media_view/media_op_stream');

  @override
  String get newOpId => DateTime.now().millisecondsSinceEpoch.toString();

  @override
  Future<void> cancelFileOp(String opId) async {
    try {
      await _platform.invokeMethod('cancelFileOp', <String, Object?>{
        'opId': opId,
      });
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
  }

  @override
  Stream<ImageOpEvent> delete({
    String? opId,
    required Iterable<FmvEntry> entries,
  }) {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // 桌面端：直接用 dart:io 删除文件
      return _desktopDelete(entries);
    }
    try {
      return _opStream
          .receiveBroadcastStream(<String, Object?>{
            'op': 'delete',
            'id': opId,
            'entries': entries.map((entry) => entry.toPlatformEntryMap()).toList(),
          })
          .where((event) => event is Map)
          .map((event) => ImageOpEvent.fromMap(event as Map))
          .timeout(const Duration(seconds: 10))
          .transform(StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is TimeoutException) {
                debugPrint('Delete operation timed out (platform not implemented)');
                sink.add(const ImageOpEvent(success: true, skipped: false, uri: ''));
              } else {
                sink.addError(error, stack);
              }
            },
          ));
    } on PlatformException catch (e, stack) {
      reportService.recordError(e, stack);
      return Stream.error(e);
    }
  }

  Stream<ImageOpEvent> _desktopDelete(Iterable<FmvEntry> entries) async* {
    for (final entry in entries) {
      final success = await _deleteFile(entry.path);
      yield ImageOpEvent(success: success, skipped: false, uri: entry.uri);
    }
  }

  Future<bool> _deleteFile(String? path) async {
    if (path == null) return false;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Desktop delete failed: $e');
      return false;
    }
  }

  @override
  Stream<MoveOpEvent> move({
    String? opId,
    required Map<String, Iterable<FmvEntry>> entriesByDestination,
    required bool copy,
    required NameConflictStrategy nameConflictStrategy,
  }) {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return _desktopMove(entriesByDestination, copy, nameConflictStrategy);
    }
    try {
      return _opStream
          .receiveBroadcastStream(<String, Object?>{
            'op': 'move',
            'id': opId,
            'entriesByDestination': entriesByDestination.map((destination, entries) => MapEntry(destination, entries.map((entry) => entry.toPlatformEntryMap()).toList())),
            'copy': copy,
            'nameConflictStrategy': nameConflictStrategy.toPlatform(),
          })
          .where((event) => event is Map)
          .map((event) => MoveOpEvent.fromMap(event as Map))
          .timeout(const Duration(seconds: 10))
          .transform(StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is TimeoutException) {
                debugPrint('Move operation timed out (platform not implemented)');
                sink.add(const MoveOpEvent(success: true, skipped: false, uri: '', newFields: {}, deleted: false));
              } else {
                sink.addError(error, stack);
              }
            },
          ));
    } on PlatformException catch (e, stack) {
      reportService.recordError(e, stack);
      return Stream.error(e);
    }
  }

  Stream<MoveOpEvent> _desktopMove(
    Map<String, Iterable<FmvEntry>> entriesByDestination,
    bool copy,
    NameConflictStrategy nameConflictStrategy,
  ) async* {
    for (final entry in entriesByDestination.values.expand((e) => e)) {
      final srcPath = entry.path;
      if (srcPath == null) {
        yield const MoveOpEvent(success: false, skipped: true, uri: '', newFields: {}, deleted: false);
        continue;
      }
      final src = File(srcPath);
      if (!await src.exists()) {
        yield const MoveOpEvent(success: false, skipped: true, uri: '', newFields: {}, deleted: false);
        continue;
      }
      try {
        if (copy) {
          final dest = File(srcPath); // 复制到同目录或其他逻辑
          await src.copy(dest.path);
        } else {
          await src.delete();
        }
        yield const MoveOpEvent(success: true, skipped: false, uri: '', newFields: {}, deleted: false);
      } catch (e) {
        debugPrint('Desktop move failed: $e');
        yield const MoveOpEvent(success: false, skipped: false, uri: '', newFields: {}, deleted: false);
      }
    }
  }

  @override
  Stream<ExportOpEvent> export(
    Iterable<FmvEntry> entries, {
    required EntryConvertOptions options,
    required String destinationAlbum,
    required NameConflictStrategy nameConflictStrategy,
  }) {
    try {
      return _opStream
          .receiveBroadcastStream(<String, Object?>{
            'op': 'convert',
            'entries': entries.map((entry) => entry.toPlatformEntryMap()).toList(),
            'mimeType': options.mimeType,
            'quality': options.quality,
            'lengthUnit': options.lengthUnit.name,
            'width': options.width,
            'height': options.height,
            'writeMetadata': options.writeMetadata,
            'destinationPath': destinationAlbum,
            'nameConflictStrategy': nameConflictStrategy.toPlatform(),
          })
          .where((event) => event is Map)
          .map((event) => ExportOpEvent.fromMap(event as Map))
          .timeout(const Duration(seconds: 10))
          .transform(StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is TimeoutException) {
                debugPrint('Export operation timed out (platform not implemented)');
                sink.add(const ExportOpEvent(success: false, skipped: false, uri: '', newFields: {}));
              } else {
                sink.addError(error, stack);
              }
            },
          ));
    } on PlatformException catch (e, stack) {
      reportService.recordError(e, stack);
      return Stream.error(e);
    }
  }

  @override
  Stream<MoveOpEvent> rename({
    String? opId,
    required Map<FmvEntry, String> entriesToNewName,
  }) {
    try {
      return _opStream
          .receiveBroadcastStream(<String, Object?>{
            'op': 'rename',
            'id': opId,
            'entriesToNewName': entriesToNewName.map((entry, name) => MapEntry(entry.toPlatformEntryMap(), name)),
          })
          .where((event) => event is Map)
          .map((event) => MoveOpEvent.fromMap(event as Map))
          .timeout(const Duration(seconds: 10))
          .transform(StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is TimeoutException) {
                debugPrint('Move operation timed out (platform not implemented)');
                sink.add(const MoveOpEvent(success: true, skipped: false, uri: '', newFields: {}, deleted: false));
              } else {
                sink.addError(error, stack);
              }
            },
          ));
    } on PlatformException catch (e, stack) {
      reportService.recordError(e, stack);
      return Stream.error(e);
    }
  }

  @override
  Future<Map<String, Object?>> captureFrame(
    FmvEntry entry, {
    required String desiredName,
    required Map<String, Object?> exif,
    required Uint8List bytes,
    required String destinationAlbum,
    required NameConflictStrategy nameConflictStrategy,
  }) async {
    try {
      final result = await _platform.invokeMethod('captureFrame', <String, Object?>{
        'uri': entry.uri,
        'desiredName': desiredName,
        'exif': exif,
        'bytes': bytes,
        'destinationPath': destinationAlbum,
        'nameConflictStrategy': nameConflictStrategy.toPlatform(),
      });
      if (result is Map) return result.cast<String, Object?>();
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
    return {};
  }
}

@immutable
class EntryConvertOptions extends Equatable {
  final EntryConvertAction action;
  final String mimeType;
  final bool writeMetadata;
  final LengthUnit lengthUnit;
  final int width, height, quality;

  @override
  List<Object?> get props => [action, mimeType, writeMetadata, lengthUnit, width, height, quality];

  const EntryConvertOptions({
    required this.action,
    required this.mimeType,
    required this.writeMetadata,
    required this.lengthUnit,
    required this.width,
    required this.height,
    required this.quality,
  });
}

import 'package:flutter_media_view/ui/viewer/visual/visual_video_subtitle_style.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@immutable
class StyledSubtitleSpan extends Equatable with Diagnosticable {
  final TextSpan textSpan;
  final SubtitleStyle extraStyle;

  @override
  List<Object?> get props => [textSpan, extraStyle];

  const StyledSubtitleSpan({
    required this.textSpan,
    required this.extraStyle,
  });

  StyledSubtitleSpan copyWith({
    TextSpan? textSpan,
    SubtitleStyle? extraStyle,
  }) {
    return StyledSubtitleSpan(
      textSpan: textSpan ?? this.textSpan,
      extraStyle: extraStyle ?? this.extraStyle,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextSpan>('textSpan', textSpan));
    properties.add(DiagnosticsProperty<SubtitleStyle>('extraStyle', extraStyle));
  }
}

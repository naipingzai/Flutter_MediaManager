import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraDateFieldSourceView on DateFieldSource {
  String getText(BuildContext context) {
    return switch (this) {
      DateFieldSource.fileModifiedDate => context.l10n.editEntryDateDialogSourceFileModifiedDate,
      DateFieldSource.exifDate => 'Exif date',
      DateFieldSource.exifDateOriginal => 'Exif original date',
      DateFieldSource.exifDateDigitized => 'Exif digitized date',
      DateFieldSource.exifGpsDate => 'Exif GPS date',
    };
  }
}

import 'package:flutter_media_view/function/function_accessibility_service.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:aves_model/aves_model.dart';

extension ExtraAccessibilityTimeout on AccessibilityTimeout {
  Future<Duration> getSnackBarDuration(bool hasAction) async {
    switch (this) {
      case .system:
        if (hasAction) {
          return Duration(milliseconds: await (AccessibilityService.getRecommendedTimeToTakeAction(ADurations.opToastActionDisplay)));
        } else {
          return Duration(milliseconds: await (AccessibilityService.getRecommendedTimeToRead(ADurations.opToastTextDisplay)));
        }
      case .s1:
        return const Duration(seconds: 1);
      case .s3:
        return const Duration(seconds: 3);
      case .s5:
        return const Duration(seconds: 5);
      case .s10:
        return const Duration(seconds: 10);
      case .s30:
        return const Duration(seconds: 30);
    }
  }
}

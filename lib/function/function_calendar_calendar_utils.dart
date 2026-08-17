import 'package:flutter_media_view/function/function_aves_locale.dart';
import 'package:flutter_media_view/function/function_calendar_ops_base.dart';
import 'package:flutter_media_view/function/function_calendar_ops_gregorian.dart';
import 'package:flutter_media_view/function/function_calendar_ops_persian.dart';

extension ExtraIntl4xCalendar on ACalendar {
  int get maxDaysInYear => 366;

  int get maxDaysInMonth => 31;

  CalendarOps get ops {
    switch (this) {
      case .gregorian:
        return GregorianCalendarOps.instance;
      case .persian:
        return PersianCalendarOps.instance;
      default:
        throw UnimplementedError();
    }
  }
}

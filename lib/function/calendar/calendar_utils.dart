import 'package:flutter_media_view/function/locale/aves_locale.dart';
import 'package:flutter_media_view/function/calendar/ops_base.dart';
import 'package:flutter_media_view/function/calendar/ops_gregorian.dart';
import 'package:flutter_media_view/function/calendar/ops_persian.dart';

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

import 'package:fmv/function/filters/filters.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class WeekDayFilter extends CollectionFilter {
  static const type = 'weekday';

  late final int weekday;
  late final EntryPredicate _test;

  @override
  List<Object?> get props => [weekday, reversed];

  // `weekday` should be in [1, 7], with 1 as Monday
  WeekDayFilter(this.weekday, {super.reversed = false}) {
    _test = (entry) => entry.bestDate?.weekday == weekday;
  }

  factory WeekDayFilter.fromMap(Map<String, Object?> json) {
    return WeekDayFilter(
      json['weekday'] as int,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toJsonMap() => {
    'type': type,
    'weekday': weekday,
    if (reversed) 'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => true;

  @override
  String get universalLabel => weekday.toString();

  @override
  String getLabel(BuildContext context) {
    final dateSymbols = DateFormat(null, context.localeName).dateSymbols;
    return dateSymbols.STANDALONEWEEKDAYS[weekday % 7];
  }

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) => Icon(AIcons.dateWeekday, size: size);

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed-$weekday';
}

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_favourites.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class FavouriteFilter extends CollectionFilter {
  static const type = 'favourite';

  static bool _test(FmvEntry entry) => entry.isFavourite;

  static const instance = FavouriteFilter._private();
  static const instanceReversed = FavouriteFilter._private(reversed: true);

  @override
  List<Object?> get props => [reversed];

  const FavouriteFilter._private({super.reversed = false});

  factory FavouriteFilter.fromMap(Map<String, Object?> json) {
    final reversed = json['reversed'] as bool? ?? false;
    return reversed ? instanceReversed : instance;
  }

  @override
  Map<String, Object?> toJsonMap() => {
    'type': type,
    if (reversed) 'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => false;

  @override
  String get universalLabel => type;

  @override
  String getLabel(BuildContext context) => context.l10n.filterFavouriteLabel;

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) => Icon(AIcons.favourite, size: size);

  @override
  Future<Color> color(BuildContext context) {
    final colors = context.read<FmvColorsData>();
    return SynchronousFuture(colors.favourite);
  }

  @override
  String get category => type;

  @override
  String get key => '$type-$reversed';
}

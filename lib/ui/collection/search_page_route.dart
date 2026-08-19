import 'package:fmv/function/source/collection_lens.dart';
import 'package:fmv/function/source/collection_source.dart';
import 'package:fmv/ui/theme/themes.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/search/common_search_route.dart';
import 'package:fmv/ui/collection/search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CollectionSearchPageRoute extends SearchPageRoute {
  CollectionSearchPageRoute({
    required BuildContext context,
    CollectionLens? parentCollection,
    bool canPop = true,
    String? initialQuery,
  }) : super(
         delegate: CollectionSearchDelegate(
           searchFieldLabel: context.l10n.searchCollectionFieldHint,
           searchFieldStyle: Themes.searchFieldStyle(context),
           source: parentCollection?.source ?? context.read<CollectionSource>(),
           parentCollection: parentCollection,
           canPop: canPop,
           initialQuery: initialQuery,
         ),
       );
}

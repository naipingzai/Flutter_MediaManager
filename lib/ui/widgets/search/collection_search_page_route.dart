import 'package:flutter_media_view/function/function_source_collection_lens.dart';
import 'package:flutter_media_view/function/function_source_collection_source.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/ui/widgets/common/search/route.dart';
import 'package:flutter_media_view/ui/widgets/search/collection_search_delegate.dart';
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

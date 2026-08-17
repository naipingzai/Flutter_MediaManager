import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_favourites.dart';

extension ExtraAvesEntryFav on AvesEntry {
  bool get isFavourite => favourites.isFavourite(this);

  Future<void> toggleFavourite() async {
    if (isFavourite) {
      await removeFromFavourites();
    } else {
      await addToFavourites();
    }
  }

  Future<void> addToFavourites() async {
    if (!isFavourite) {
      await favourites.add({this});
    }
  }

  Future<void> removeFromFavourites() async {
    if (isFavourite) {
      await favourites.removeEntries({this});
    }
  }
}

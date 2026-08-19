import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/model/favourites.dart';

extension ExtraFmvEntryFav on FmvEntry {
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

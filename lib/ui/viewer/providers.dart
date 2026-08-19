import 'package:fmv/function/source/collection_lens.dart';
import 'package:fmv/ui/viewer/multipage_conductor.dart';
import 'package:fmv/ui/viewer/video_conductor.dart';
import 'package:fmv/ui/viewer/view_conductor.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ViewStateConductorProvider extends ProxyProvider<MediaQueryData, ViewStateConductor> {
  ViewStateConductorProvider({
    super.key,
    super.child,
  }) : super(
         create: (context) => ViewStateConductor(),
         update: (context, mq, value) {
           value!.viewportSize = mq.size;
           return value;
         },
         dispose: (context, value) => value.dispose(),
       );
}

class VideoConductorProvider extends Provider<VideoConductor> {
  VideoConductorProvider({
    super.key,
    CollectionLens? collection,
    super.child,
  }) : super(
         create: (context) => VideoConductor(collection: collection),
         dispose: (context, value) => value.dispose(),
       );
}

class MultiPageConductorProvider extends Provider<MultiPageConductor> {
  MultiPageConductorProvider({
    super.key,
    super.child,
  }) : super(
         create: (context) => MultiPageConductor(),
         dispose: (context, value) => value.dispose(),
       );
}

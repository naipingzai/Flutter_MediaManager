import 'package:fmv/function/utils/function_highlight.dart';
import 'package:provider/provider.dart';

class HighlightInfoProvider extends ChangeNotifierProvider<HighlightInfo> {
  HighlightInfoProvider({
    super.key,
    super.child,
  }) : super(
         create: (context) => HighlightInfo(),
       );
}

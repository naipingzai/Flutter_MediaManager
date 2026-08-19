import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/durations.dart';
import 'package:provider/provider.dart';

class DurationsProvider extends ProxyProvider<Settings, DurationsData> {
  DurationsProvider({
    super.key,
    super.child,
  }) : super(
         update: (context, settings, _) {
           return settings.animate ? DurationsData() : DurationsData.noAnimation();
         },
       );
}

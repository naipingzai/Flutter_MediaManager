import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/ui_view.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_identity_buttons_overlay_button.dart';
import 'package:flutter_media_view/ui/ui_widgets_settings_common_quick_actions_action_panel.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_overlay_bottom_video_controls.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VideoControlButtonsPage extends StatelessWidget {
  static const routeName = '/settings/video/control_buttons';

  static const List<String> settingKeys = [SettingKeys.videoControlActionsKey];

  static const _availableActions = [...EntryActions.videoPlayback, EntryAction.openVideoPlayer];

  const VideoControlButtonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AvesScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !settings.useTvLayout,
        title: Text(context.l10n.settingsVideoButtonsTile),
      ),
      body: SafeArea(
        child: Selector<Settings, List<EntryAction>>(
          selector: (context, s) => s.videoControlActions,
          builder: (context, selectedActionList, child) {
            return Column(
              crossAxisAlignment: .stretch,
              children: [
                ActionPanel(
                  child: Container(
                    alignment: AlignmentDirectional.center,
                    height: OverlayButton.getSize(context) + 48,
                    child: selectedActionList.isNotEmpty
                        ? VideoControlRow(onActionSelected: (_) {})
                        : Text(
                            context.l10n.settingsViewerQuickActionEmpty,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: _availableActions.map((action) {
                      return SwitchListTile(
                        value: selectedActionList.contains(action),
                        onChanged: (v) {
                          final selectedActionSet = settings.videoControlActions.toSet();
                          if (v) {
                            selectedActionSet.add(action);
                          } else {
                            selectedActionSet.remove(action);
                          }
                          settings.videoControlActions = _availableActions.where(selectedActionSet.contains).toList();
                        },
                        title: Text(action.getText(context)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

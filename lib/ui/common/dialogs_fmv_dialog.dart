import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FmvDialog extends StatefulWidget {
  static const confirmationRouteName = '/dialog/confirmation';
  static const warningRouteName = '/dialog/warning';

  final String? title;
  final ScrollController? scrollController;
  final List<Widget>? scrollableContent;
  final double horizontalContentPadding;
  final Widget? content;
  final List<Widget> actions;

  static const Radius cornerRadius = Radius.circular(24);
  static const double defaultHorizontalContentPadding = 24;
  static const double controlCaptionPadding = 16;
  static const double borderWidth = 1.0;
  static const EdgeInsets actionsPadding = EdgeInsets.symmetric(vertical: 4, horizontal: 16);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 8);

  const FmvDialog({
    super.key,
    this.title,
    this.scrollController,
    this.scrollableContent,
    this.horizontalContentPadding = defaultHorizontalContentPadding,
    this.content,
    this.actions = const [],
  }) : assert((scrollableContent != null) ^ (content != null));

  @override
  State<FmvDialog> createState() => _FmvDialogState();

  static Decoration contentDecoration(BuildContext context) => BoxDecoration(
    border: Border(
      bottom: Divider.createBorderSide(context, width: borderWidth),
    ),
  );

  static ShapeBorder shape(BuildContext context) {
    return RoundedRectangleBorder(
      side: Divider.createBorderSide(context, width: borderWidth),
      borderRadius: const BorderRadius.all(cornerRadius),
    );
  }
}

class _FmvDialogState extends State<FmvDialog> {
  final ScrollController _internalScrollController = ScrollController();

  ScrollController get scrollController => widget.scrollController ?? _internalScrollController;

  @override
  void dispose() {
    _internalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    return AlertDialog(
      title: title != null
          ? Padding(
              // padding to avoid transparent border overlapping
              padding: const EdgeInsets.symmetric(horizontal: FmvDialog.borderWidth),
              child: DialogTitle(title: title),
            )
          : null,
      titlePadding: EdgeInsets.zero,
      // the `scrollable` flag of `AlertDialog` makes it
      // scroll both the title and the content together,
      // and overflow feedback ignores the dialog shape,
      // so we restrict scrolling to the content instead
      content: _buildContent(context),
      contentPadding: widget.scrollableContent != null
          ? EdgeInsets.zero
          : EdgeInsets.only(
              left: widget.horizontalContentPadding,
              top: 20,
              right: widget.horizontalContentPadding,
            ),
      actions: widget.actions,
      actionsPadding: FmvDialog.actionsPadding,
      buttonPadding: FmvDialog.buttonPadding,
      // clipping to prevent highlighted material to bleed through rounded corners
      clipBehavior: Clip.antiAlias,
      shape: FmvDialog.shape(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final content = widget.content;
    if (content != null) {
      return content;
    }

    final scrollableContent = widget.scrollableContent;
    if (scrollableContent != null) {
      Widget child = ListView(
        controller: scrollController,
        shrinkWrap: true,
        children: scrollableContent,
      );

      if (!settings.useTvLayout) {
        child = Theme(
          data: Theme.of(context).copyWith(
            scrollbarTheme: ScrollbarThemeData(
              thumbVisibility: WidgetStateProperty.all(true),
              radius: const Radius.circular(16),
              crossAxisMargin: 4,
              // adapt margin when corner is around content itself, not outside for the title
              mainAxisMargin: 4 + (widget.title != null ? 0 : FmvDialog.cornerRadius.y / 2),
              interactive: true,
            ),
          ),
          child: Scrollbar(
            controller: scrollController,
            notificationPredicate: (notification) {
              // as of Flutter v3.0.1, the `Scrollbar` does not only respond to the nearest `ScrollView`
              // despite the `defaultScrollNotificationPredicate` checking notification depth,
              // as the notifications coming from the controller in `ListWheelScrollView` in `WheelSelector` still have a depth of 0.
              // Cancelling notification bubbling seems ineffective, so we check the metrics type as a workaround.
              return defaultScrollNotificationPredicate(notification) && notification.metrics is! FixedExtentMetrics;
            },
            child: child,
          ),
        );
      }

      return Container(
        // padding to avoid transparent border overlapping
        padding: const EdgeInsets.symmetric(horizontal: FmvDialog.borderWidth),
        // workaround because the dialog tries
        // to size itself to the content intrinsic size,
        // but the `ListView` viewport does not have one
        width: MediaQuery.sizeOf(context).width / 2,
        child: DecoratedBox(
          decoration: FmvDialog.contentDecoration(context),
          child: child,
        ),
      );
    }

    return const SizedBox();
  }
}

class DialogTitle extends StatelessWidget {
  final String title;

  const DialogTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: FmvDialog.contentDecoration(context),
      child: Text(
        title,
        textAlign: TextAlign.center,
      ),
    );
  }
}

Future<void> showNoMatchingAppDialog(BuildContext context) => showWarningDialog(
  context: context,
  message: context.l10n.noMatchingAppDialogMessage,
);

Future<void> showWarningDialog({
  required BuildContext context,
  required String message,
}) => showFmvDialog<void>(
  context: context,
  builder: (context) => FmvMessageDialog.info(message),
  routeSettings: const RouteSettings(name: FmvDialog.warningRouteName),
);

Future<T?> showFmvDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
}) {
  final animate = context.read<Settings>().animate;
  final animationStyle = animate ? null : AnimationStyle.noAnimation;

  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    fullscreenDialog: fullscreenDialog,
    requestFocus: requestFocus,
    animationStyle: animationStyle,
  );
}

class CancelButton<T> extends StatelessWidget {
  final String? text;
  final T? result;

  const CancelButton({
    super.key,
    this.text,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.maybeOf(context)?.pop<T>(result),
      // MD2 button labels were upper case but they are lower case in MD3
      child: Text(text ?? Themes.asButtonLabel(context.l10n.cancelTooltip)),
    );
  }
}

class OkButton<T> extends StatelessWidget {
  final String? text;
  final T? result;

  const OkButton({
    super.key,
    this.text,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.maybeOf(context)?.pop<T>(result),
      // MD2 button labels were upper case but they are lower case in MD3
      child: Text(text ?? Themes.asButtonLabel(MaterialLocalizations.of(context).okButtonLabel)),
    );
  }
}

class FmvMessageDialog extends StatelessWidget {
  final String message;
  final List<Widget> actions;

  const FmvMessageDialog({
    super.key,
    required this.message,
    required this.actions,
  });

  factory FmvMessageDialog.info(String message) {
    return FmvMessageDialog(
      message: message,
      actions: const [OkButton()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FmvDialog(
      content: Text(message),
      actions: actions,
    );
  }
}

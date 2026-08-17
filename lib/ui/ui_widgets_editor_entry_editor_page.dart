import 'dart:async';

import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_viewer_view_state.dart';
import 'package:flutter_media_view/ui/ui_widgets_editor_control_panel.dart';
import 'package:flutter_media_view/ui/ui_widgets_editor_image.dart';
import 'package:flutter_media_view/ui/ui_widgets_editor_transform_controller.dart';
import 'package:flutter_media_view/ui/ui_widgets_editor_transform_cropper.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_overlay_top_minimap.dart';
import 'package:aves_magnifier/aves_magnifier.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImageEditorPage extends StatefulWidget {
  static const routeName = '/image_editor';

  final AvesEntry entry;

  const ImageEditorPage({
    super.key,
    required this.entry,
  });

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  final Set<StreamSubscription> _subscriptions = {};
  final ValueNotifier<EditorAction?> _actionNotifier = ValueNotifier(null);
  final ValueNotifier<EdgeInsets> _marginNotifier = ValueNotifier(EdgeInsets.zero);
  final ValueNotifier<ViewState> _viewStateNotifier = ValueNotifier<ViewState>(ViewState.zero);
  final AvesMagnifierController _magnifierController = AvesMagnifierController();
  late final TransformController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = TransformController(widget.entry.displaySize);
    _actionNotifier.addListener(_onActionChanged);
    _subscriptions.add(_transformController.transformationStream.map((v) => v.matrix).distinct().listen(_onTransformationMatrixChanged));
  }

  @override
  void dispose() {
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
    _actionNotifier.dispose();
    _marginNotifier.dispose();
    _viewStateNotifier.dispose();
    _magnifierController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiProvider(
        providers: [
          Provider<AvesMagnifierController>.value(value: _magnifierController),
          Provider<TransformController>.value(value: _transformController),
        ],
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRect(
                      child: EditorImage(
                        magnifierController: _magnifierController,
                        transformController: _transformController,
                        actionNotifier: _actionNotifier,
                        marginNotifier: _marginNotifier,
                        viewStateNotifier: _viewStateNotifier,
                        entry: widget.entry,
                      ),
                    ),
                    if (settings.showOverlayMinimap)
                      PositionedDirectional(
                        start: 8,
                        bottom: 8,
                        child: Minimap(viewStateNotifier: _viewStateNotifier),
                      ),
                    ValueListenableBuilder<EditorAction?>(
                      valueListenable: _actionNotifier,
                      builder: (context, action, child) {
                        switch (action) {
                          case .transform:
                            return Cropper(
                              magnifierController: _magnifierController,
                              transformController: _transformController,
                              marginNotifier: _marginNotifier,
                            );
                          case null:
                            return const SizedBox();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              EditorControlPanel(
                entry: widget.entry,
                actionNotifier: _actionNotifier,
              ),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  void _onActionChanged() {
    switch (_actionNotifier.value) {
      case .transform:
        _transformController.reset();
        _marginNotifier.value = Cropper.imageMargin;
      default:
        _marginNotifier.value = EdgeInsets.zero;
    }
  }

  void _onTransformationMatrixChanged(Matrix4 transformationMatrix) {
    final boundaries = _magnifierController.scaleBoundaries;
    if (boundaries != null) {
      _magnifierController.setScaleBoundaries(
        boundaries.copyWith(
          externalTransform: transformationMatrix,
        ),
      );
    }
  }
}

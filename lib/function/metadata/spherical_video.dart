import 'package:xml/xml.dart';

/// 球形视频（Spherical Video V1）元数据解析器，
/// 移植自 Android `metadata/SphericalVideo.kt`，无平台依赖，可复用于任何目标。
class GSpherical {
  // cf https://github.com/google/spatial-media
  static const sphericalVideoV1Uuid = 'ffcc8263-f855-4a93-8814-587a02521fdd';
  static const _rdfNs = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
  static const _gsphericalNs = 'http://ns.google.com/videos/1.0/spherical/';

  bool _spherical = false;
  bool _stitched = false;
  String _stitchingSoftware = '';
  String _projectionType = '';
  String? _stereoMode;
  int? _sourceCount;
  int? _initialViewHeadingDegrees;
  int? _initialViewPitchDegrees;
  int? _initialViewRollDegrees;
  int? _timestamp;
  int? _fullPanoWidthPixels;
  int? _fullPanoHeightPixels;
  int? _croppedAreaImageWidthPixels;
  int? _croppedAreaImageHeightPixels;
  int? _croppedAreaLeftPixels;
  int? _croppedAreaTopPixels;

  /// [xmlText] 为嵌入 MP4 `uuid` 盒的 XML 字符串（Spherical Video V1 规范）
  GSpherical(String xmlText) {
    try {
      final document = XmlDocument.parse(xmlText);
      final root = document.rootElement;
      if (root.name.local != 'SphericalVideo' && root.namespaceUri != _rdfNs) {
        // 宽容处理：部分文件可能无 RDF 命名空间，只要根元素匹配即可
        if (root.name.local != 'SphericalVideo') return;
      }
      _read(root);
    } on Exception {
      // 解析失败时保持默认值，与 Kotlin 端吞异常行为一致
    }
  }

  void _read(XmlElement root) {
    root.descendants.whereType<XmlElement>().forEach((element) {
      if (element.namespaceUri != _gsphericalNs) return;
      final text = element.innerText.trim();
      switch (element.name.local) {
        case 'Spherical':
          _spherical = text == 'true';
        case 'Stitched':
          _stitched = text == 'true';
        case 'StitchingSoftware':
          _stitchingSoftware = text;
        case 'ProjectionType':
          _projectionType = text;
        case 'StereoMode':
          _stereoMode = text;
        case 'SourceCount':
          _sourceCount = int.tryParse(text);
        case 'InitialViewHeadingDegrees':
          _initialViewHeadingDegrees = int.tryParse(text);
        case 'InitialViewPitchDegrees':
          _initialViewPitchDegrees = int.tryParse(text);
        case 'InitialViewRollDegrees':
          _initialViewRollDegrees = int.tryParse(text);
        case 'Timestamp':
          _timestamp = int.tryParse(text);
        case 'FullPanoWidthPixels':
          _fullPanoWidthPixels = int.tryParse(text);
        case 'FullPanoHeightPixels':
          _fullPanoHeightPixels = int.tryParse(text);
        case 'CroppedAreaImageWidthPixels':
          _croppedAreaImageWidthPixels = int.tryParse(text);
        case 'CroppedAreaImageHeightPixels':
          _croppedAreaImageHeightPixels = int.tryParse(text);
        case 'CroppedAreaLeftPixels':
          _croppedAreaLeftPixels = int.tryParse(text);
        case 'CroppedAreaTopPixels':
          _croppedAreaTopPixels = int.tryParse(text);
      }
    });
  }

  /// 输出与 Android 端一致的展示字段（值为 null 的键被剔除）
  Map<String, String> describe() {
    final fields = <String, String?>{
      'Spherical': '$_spherical',
      'Stitched': '$_stitched',
      'Stitching Software': _stitchingSoftware,
      'Projection Type': _projectionType,
      'Stereo Mode': _stereoMode,
      'Source Count': _sourceCount?.toString(),
      'Initial View Heading Degrees': _initialViewHeadingDegrees?.toString(),
      'Initial View Pitch Degrees': _initialViewPitchDegrees?.toString(),
      'Initial View Roll Degrees': _initialViewRollDegrees?.toString(),
      'Timestamp': _timestamp?.toString(),
      'Full Panorama Width Pixels': _fullPanoWidthPixels?.toString(),
      'Full Panorama Height Pixels': _fullPanoHeightPixels?.toString(),
      'Cropped Area Image Width Pixels': _croppedAreaImageWidthPixels?.toString(),
      'Cropped Area Image Height Pixels': _croppedAreaImageHeightPixels?.toString(),
      'Cropped Area Left Pixels': _croppedAreaLeftPixels?.toString(),
      'Cropped Area Top Pixels': _croppedAreaTopPixels?.toString(),
    };
    fields.removeWhere((k, v) => v == null);
    return fields.cast<String, String>();
  }
}

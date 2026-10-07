import 'dart:ui';

enum ImageOutputFormat {
  jpg('JPG', 'jpg', 'image/jpeg'),
  png('PNG', 'png', 'image/png');

  final String label;
  final String extension;
  final String mimeType;

  const ImageOutputFormat(this.label, this.extension, this.mimeType);
}

enum CropAspectRatio {
  free('Bebas', null),
  square('1:1 (Persegi)', 1.0),
  ratio4_3('4:3 (Standar)', 4.0 / 3.0),
  ratio16_9('16:9 (Landscape)', 16.0 / 9.0),
  ratio9_16('9:16 (Story/TikTok)', 9.0 / 16.0);

  final String label;
  final double? ratio;

  const CropAspectRatio(this.label, this.ratio);
}

class ProcessingConfig {
  static const Object _sentinel = Object();

  int quality; // 1 - 100
  ImageOutputFormat targetFormat;
  int? resizeWidth;
  int? resizeHeight;
  bool keepAspectRatio;
  CropAspectRatio cropRatio;
  Rect? customCropRect; // Normalized 0.0 - 1.0
  int rotationAngle; // 0, 90, 180, 270
  bool flipHorizontal;
  bool flipVertical;
  int? targetMaxSizeBytes; // E.g., 500 KB limit for auto compression

  ProcessingConfig({
    this.quality = 80,
    this.targetFormat = ImageOutputFormat.jpg,
    this.resizeWidth,
    this.resizeHeight,
    this.keepAspectRatio = true,
    this.cropRatio = CropAspectRatio.free,
    this.customCropRect,
    this.rotationAngle = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.targetMaxSizeBytes,
  });

  ProcessingConfig copyWith({
    Object? quality = _sentinel,
    Object? targetFormat = _sentinel,
    Object? resizeWidth = _sentinel,
    Object? resizeHeight = _sentinel,
    Object? keepAspectRatio = _sentinel,
    Object? cropRatio = _sentinel,
    Object? customCropRect = _sentinel,
    Object? rotationAngle = _sentinel,
    Object? flipHorizontal = _sentinel,
    Object? flipVertical = _sentinel,
    Object? targetMaxSizeBytes = _sentinel,
  }) {
    return ProcessingConfig(
      quality: quality == _sentinel ? this.quality : quality as int,
      targetFormat: targetFormat == _sentinel
          ? this.targetFormat
          : targetFormat as ImageOutputFormat,
      resizeWidth: resizeWidth == _sentinel
          ? this.resizeWidth
          : resizeWidth as int?,
      resizeHeight: resizeHeight == _sentinel
          ? this.resizeHeight
          : resizeHeight as int?,
      keepAspectRatio: keepAspectRatio == _sentinel
          ? this.keepAspectRatio
          : keepAspectRatio as bool,
      cropRatio: cropRatio == _sentinel
          ? this.cropRatio
          : cropRatio as CropAspectRatio,
      customCropRect: customCropRect == _sentinel
          ? this.customCropRect
          : customCropRect as Rect?,
      rotationAngle: rotationAngle == _sentinel
          ? this.rotationAngle
          : rotationAngle as int,
      flipHorizontal: flipHorizontal == _sentinel
          ? this.flipHorizontal
          : flipHorizontal as bool,
      flipVertical: flipVertical == _sentinel
          ? this.flipVertical
          : flipVertical as bool,
      targetMaxSizeBytes: targetMaxSizeBytes == _sentinel
          ? this.targetMaxSizeBytes
          : targetMaxSizeBytes as int?,
    );
  }
}

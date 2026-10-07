import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'processing_config.dart';

/// Primitive-only message sent to the worker isolate.
@immutable
class ImageProcessingRequest {
  const ImageProcessingRequest({
    required this.sourcePath,
    required this.outputPath,
    required this.quality,
    required this.targetFormat,
    required this.resizeWidth,
    required this.resizeHeight,
    required this.keepAspectRatio,
    required this.cropRatio,
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
    required this.rotationAngle,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.targetMaxSizeBytes,
  });

  final String sourcePath;
  final String outputPath;
  final int quality;
  final String targetFormat;
  final int? resizeWidth;
  final int? resizeHeight;
  final bool keepAspectRatio;
  final String cropRatio;
  final double? cropLeft;
  final double? cropTop;
  final double? cropRight;
  final double? cropBottom;
  final int rotationAngle;
  final bool flipHorizontal;
  final bool flipVertical;
  final int? targetMaxSizeBytes;

  factory ImageProcessingRequest.fromConfig({
    required String sourcePath,
    required String outputPath,
    required ProcessingConfig config,
  }) {
    final rect = config.customCropRect;
    return ImageProcessingRequest(
      sourcePath: sourcePath,
      outputPath: outputPath,
      quality: config.quality,
      targetFormat: config.targetFormat.name,
      resizeWidth: config.resizeWidth,
      resizeHeight: config.resizeHeight,
      keepAspectRatio: config.keepAspectRatio,
      cropRatio: config.cropRatio.name,
      cropLeft: rect?.left,
      cropTop: rect?.top,
      cropRight: rect?.right,
      cropBottom: rect?.bottom,
      rotationAngle: config.rotationAngle,
      flipHorizontal: config.flipHorizontal,
      flipVertical: config.flipVertical,
      targetMaxSizeBytes: config.targetMaxSizeBytes,
    );
  }

  Map<String, Object?> toMap() => {
    'sourcePath': sourcePath,
    'outputPath': outputPath,
    'quality': quality,
    'targetFormat': targetFormat,
    'resizeWidth': resizeWidth,
    'resizeHeight': resizeHeight,
    'keepAspectRatio': keepAspectRatio,
    'cropRatio': cropRatio,
    'cropLeft': cropLeft,
    'cropTop': cropTop,
    'cropRight': cropRight,
    'cropBottom': cropBottom,
    'rotationAngle': rotationAngle,
    'flipHorizontal': flipHorizontal,
    'flipVertical': flipVertical,
    'targetMaxSizeBytes': targetMaxSizeBytes,
  };

  factory ImageProcessingRequest.fromMap(Map<String, Object?> map) =>
      ImageProcessingRequest(
        sourcePath: map['sourcePath']! as String,
        outputPath: map['outputPath']! as String,
        quality: map['quality']! as int,
        targetFormat: map['targetFormat']! as String,
        resizeWidth: map['resizeWidth'] as int?,
        resizeHeight: map['resizeHeight'] as int?,
        keepAspectRatio: map['keepAspectRatio']! as bool,
        cropRatio: map['cropRatio']! as String,
        cropLeft: (map['cropLeft'] as num?)?.toDouble(),
        cropTop: (map['cropTop'] as num?)?.toDouble(),
        cropRight: (map['cropRight'] as num?)?.toDouble(),
        cropBottom: (map['cropBottom'] as num?)?.toDouble(),
        rotationAngle: map['rotationAngle']! as int,
        flipHorizontal: map['flipHorizontal']! as bool,
        flipVertical: map['flipVertical']! as bool,
        targetMaxSizeBytes: map['targetMaxSizeBytes'] as int?,
      );

  ProcessingConfig toConfig() => ProcessingConfig(
    quality: quality,
    targetFormat: ImageOutputFormat.values.byName(targetFormat),
    resizeWidth: resizeWidth,
    resizeHeight: resizeHeight,
    keepAspectRatio: keepAspectRatio,
    cropRatio: CropAspectRatio.values.byName(cropRatio),
    customCropRect:
        cropLeft == null ||
            cropTop == null ||
            cropRight == null ||
            cropBottom == null
        ? null
        : Rect.fromLTRB(cropLeft!, cropTop!, cropRight!, cropBottom!),
    rotationAngle: rotationAngle,
    flipHorizontal: flipHorizontal,
    flipVertical: flipVertical,
    targetMaxSizeBytes: targetMaxSizeBytes,
  );
}

@immutable
class ImageProcessingResponse {
  const ImageProcessingResponse({
    required this.success,
    required this.outputPath,
    this.originalSizeBytes,
    this.outputSizeBytes,
    this.originalWidth,
    this.originalHeight,
    this.outputWidth,
    this.outputHeight,
    this.format,
    this.error,
    this.technicalError,
  });

  final bool success;
  final String outputPath;
  final int? originalSizeBytes;
  final int? outputSizeBytes;
  final int? originalWidth;
  final int? originalHeight;
  final int? outputWidth;
  final int? outputHeight;
  final String? format;
  final String? error;
  final String? technicalError;

  factory ImageProcessingResponse.fromMap(Map<String, Object?> map) =>
      ImageProcessingResponse(
        success: map['success']! as bool,
        outputPath: map['outputPath']! as String,
        originalSizeBytes: map['originalSizeBytes'] as int?,
        outputSizeBytes: map['outputSizeBytes'] as int?,
        originalWidth: map['originalWidth'] as int?,
        originalHeight: map['originalHeight'] as int?,
        outputWidth: map['outputWidth'] as int?,
        outputHeight: map['outputHeight'] as int?,
        format: map['format'] as String?,
        error: map['error'] as String?,
        technicalError: map['technicalError'] as String?,
      );

  Map<String, Object?> toMap() => {
    'success': success,
    'outputPath': outputPath,
    'originalSizeBytes': originalSizeBytes,
    'outputSizeBytes': outputSizeBytes,
    'originalWidth': originalWidth,
    'originalHeight': originalHeight,
    'outputWidth': outputWidth,
    'outputHeight': outputHeight,
    'format': format,
    'error': error,
    'technicalError': technicalError,
  };
}

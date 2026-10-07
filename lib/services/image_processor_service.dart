import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/processing_config.dart';
import '../models/processed_image_result.dart';
import '../models/image_processing_transfer.dart';

class ImageProcessorService {
  /// Memproses single image file berdasarkan ProcessingConfig
  static Future<ProcessedImageResult> processImage({
    required File inputFile,
    required ProcessingConfig config,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(path.join(appDir.path, 'processed_images'));
    await outputDir.create(recursive: true);
    final fileName =
        'proc_${DateTime.now().microsecondsSinceEpoch}.${config.targetFormat.extension}';
    final outputPath = path.join(outputDir.path, fileName);
    final request = ImageProcessingRequest.fromConfig(
      sourcePath: inputFile.path,
      outputPath: outputPath,
      config: config,
    );
    final response = ImageProcessingResponse.fromMap(
      await compute(processImageInBackground, request.toMap()),
    );
    if (!response.success) {
      throw ImageProcessingException(
        response.error ?? 'Image processing failed.',
        response.technicalError,
      );
    }
    return ProcessedImageResult(
      originalPath: inputFile.path,
      outputPath: response.outputPath,
      originalSizeBytes: response.originalSizeBytes!,
      outputSizeBytes: response.outputSizeBytes!,
      originalWidth: response.originalWidth!,
      originalHeight: response.originalHeight!,
      outputWidth: response.outputWidth!,
      outputHeight: response.outputHeight!,
      format: ImageOutputFormat.values.byName(response.format!),
    );
  }

  /// Runs only in the worker isolate. File paths cross the isolate boundary,
  /// so large source image buffers are never copied between isolates.
  @visibleForTesting
  static Future<Map<String, Object?>> processImageInBackground(
    Map<String, Object?> requestMap,
  ) async {
    var outputPath = requestMap['outputPath'] as String? ?? '';
    try {
      final request = ImageProcessingRequest.fromMap(requestMap);
      outputPath = request.outputPath;
      final source = File(request.sourcePath);
      final originalBytes = await source.readAsBytes();
      img.Image? decodedImage = img.decodeImage(originalBytes);
      if (decodedImage == null) {
        throw const FormatException('Could not decode the selected image.');
      }
      decodedImage = img.bakeOrientation(decodedImage);
      final originalWidth = decodedImage.width;
      final originalHeight = decodedImage.height;
      final config = request.toConfig();
      decodedImage = applyCrop(decodedImage, config);
      decodedImage = _applyRotationAndFlip(decodedImage, config);
      decodedImage = _applyResize(decodedImage, config);
      final outputBytes = _encodeImage(decodedImage, config);
      await File(request.outputPath).writeAsBytes(outputBytes, flush: true);
      return ImageProcessingResponse(
        success: true,
        outputPath: outputPath,
        originalSizeBytes: originalBytes.length,
        outputSizeBytes: outputBytes.length,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        outputWidth: decodedImage.width,
        outputHeight: decodedImage.height,
        format: config.targetFormat.name,
      ).toMap();
    } catch (error, stackTrace) {
      return ImageProcessingResponse(
        success: false,
        outputPath: outputPath,
        error: 'Image processing failed. Try another image or adjust settings.',
        technicalError: '$error\n$stackTrace',
      ).toMap();
    }
  }

  /// Applies the crop selection used by both the crop editor and the pipeline.
  static img.Image applyCrop(img.Image image, ProcessingConfig config) {
    if (config.customCropRect != null) {
      final rect = config.customCropRect!;
      final left = rect.left.clamp(0.0, 1.0);
      final top = rect.top.clamp(0.0, 1.0);
      final right = rect.right.clamp(left, 1.0);
      final bottom = rect.bottom.clamp(top, 1.0);
      final x = (left * image.width).round();
      final y = (top * image.height).round();
      final w = ((right - left) * image.width).round();
      final h = ((bottom - top) * image.height).round();
      return img.copyCrop(
        image,
        x: x.clamp(0, image.width - 1),
        y: y.clamp(0, image.height - 1),
        width: w.clamp(1, image.width - x),
        height: h.clamp(1, image.height - y),
      );
    } else if (config.cropRatio.ratio != null) {
      final double targetRatio = config.cropRatio.ratio!;
      final int currentWidth = image.width;
      final int currentHeight = image.height;
      final double currentRatio = currentWidth / currentHeight;

      int cropW = currentWidth;
      int cropH = currentHeight;
      int x = 0;
      int y = 0;

      if (currentRatio > targetRatio) {
        // Gambar lebih lebar dari rasio target -> potong lebar
        cropW = (currentHeight * targetRatio).round();
        x = ((currentWidth - cropW) / 2).round();
      } else {
        // Gambar lebih tinggi dari rasio target -> potong tinggi
        cropH = (currentWidth / targetRatio).round();
        y = ((currentHeight - cropH) / 2).round();
      }

      return img.copyCrop(
        image,
        x: x.clamp(0, currentWidth),
        y: y.clamp(0, currentHeight),
        width: cropW.clamp(1, currentWidth),
        height: cropH.clamp(1, currentHeight),
      );
    }
    return image;
  }

  static img.Image _applyRotationAndFlip(
    img.Image image,
    ProcessingConfig config,
  ) {
    img.Image result = image;
    if (config.rotationAngle != 0) {
      result = img.copyRotate(result, angle: config.rotationAngle);
    }
    if (config.flipHorizontal) {
      result = img.flipHorizontal(result);
    }
    if (config.flipVertical) {
      result = img.flipVertical(result);
    }
    return result;
  }

  static img.Image _applyResize(img.Image image, ProcessingConfig config) {
    if (config.resizeWidth == null && config.resizeHeight == null) {
      return image;
    }

    int? targetW = config.resizeWidth;
    int? targetH = config.resizeHeight;

    // Jika keepAspectRatio dan hanya salah satu dimensi diisi
    if (config.keepAspectRatio) {
      if (targetW != null && targetH == null) {
        targetH = (targetW * (image.height / image.width)).round();
      } else if (targetH != null && targetW == null) {
        targetW = (targetH * (image.width / image.height)).round();
      }
    }

    // Cegah ukuran di luar batas wajar
    targetW = targetW?.clamp(10, 8000);
    targetH = targetH?.clamp(10, 8000);

    return img.copyResize(
      image,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.cubic,
    );
  }

  static Uint8List _encodeImage(img.Image image, ProcessingConfig config) {
    int currentQuality = config.quality;
    Uint8List encoded;

    // Adaptive encoding jika targetMaxSizeBytes disetel
    while (true) {
      switch (config.targetFormat) {
        case ImageOutputFormat.jpg:
          encoded = Uint8List.fromList(
            img.encodeJpg(image, quality: currentQuality),
          );
          break;
        case ImageOutputFormat.png:
          // Level kompresi PNG 0-9
          int level = ((100 - currentQuality) / 10).round().clamp(0, 9);
          encoded = Uint8List.fromList(img.encodePng(image, level: level));
          break;
      }

      if (config.targetMaxSizeBytes != null &&
          encoded.length > config.targetMaxSizeBytes! &&
          currentQuality > 20 &&
          config.targetFormat != ImageOutputFormat.png) {
        // Turunkan kualitas secara bertahap jika melebihi batas ukuran
        currentQuality -= 10;
      } else {
        break;
      }
    }

    return encoded;
  }
}

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.userMessage, this.technicalError);
  final String userMessage;
  final String? technicalError;

  @override
  String toString() => userMessage;
}

Future<Map<String, Object?>> processImageInBackground(
  Map<String, Object?> request,
) => ImageProcessorService.processImageInBackground(request);

import 'processing_config.dart';

class ProcessedImageResult {
  final String originalPath;
  final String outputPath;
  final int originalSizeBytes;
  final int outputSizeBytes;
  final int originalWidth;
  final int originalHeight;
  final int outputWidth;
  final int outputHeight;
  final ImageOutputFormat format;
  final DateTime processedAt;

  ProcessedImageResult({
    required this.originalPath,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.outputSizeBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.format,
    DateTime? processedAt,
  }) : processedAt = processedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'originalPath': originalPath,
      'outputPath': outputPath,
      'originalSizeBytes': originalSizeBytes,
      'outputSizeBytes': outputSizeBytes,
      'originalWidth': originalWidth,
      'originalHeight': originalHeight,
      'outputWidth': outputWidth,
      'outputHeight': outputHeight,
      'format': format.name,
      'processedAt': processedAt.toIso8601String(),
    };
  }

  factory ProcessedImageResult.fromJson(Map<String, dynamic> json) {
    final formatName = json['format'] as String?;
    final format = ImageOutputFormat.values.firstWhere(
      (item) => item.name == formatName,
      orElse: () => ImageOutputFormat.jpg,
    );

    return ProcessedImageResult(
      originalPath: json['originalPath'] as String,
      outputPath: json['outputPath'] as String,
      originalSizeBytes: (json['originalSizeBytes'] as num).toInt(),
      outputSizeBytes: (json['outputSizeBytes'] as num).toInt(),
      originalWidth: (json['originalWidth'] as num).toInt(),
      originalHeight: (json['originalHeight'] as num).toInt(),
      outputWidth: (json['outputWidth'] as num).toInt(),
      outputHeight: (json['outputHeight'] as num).toInt(),
      format: format,
      processedAt: DateTime.parse(json['processedAt'] as String),
    );
  }

  int get bytesSaved => originalSizeBytes - outputSizeBytes;
  double get compressionPercentage {
    if (originalSizeBytes == 0) return 0;
    return ((originalSizeBytes - outputSizeBytes) / originalSizeBytes) * 100;
  }
}

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/image_job.dart';
import '../models/processing_config.dart';
import '../utils/format_utils.dart';

extension ImageOperationLabel on ImageOperation {
  String get label => switch (this) {
    ImageOperation.compress => 'Compress',
    ImageOperation.resize => 'Resize',
    ImageOperation.convert => 'Convert',
    ImageOperation.cropTransform => 'Crop & Transform',
    ImageOperation.batch => 'Batch',
  };
}

Future<Size> loadPreviewImageSize(File file) async {
  final completer = Completer<Size>();
  final provider = ResizeImage(FileImage(file), width: 1024);
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        completer.complete(
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
      }
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

class WorkflowStepHeader extends StatelessWidget {
  const WorkflowStepHeader({
    super.key,
    required this.operation,
    required this.step,
    required this.title,
    this.subtitle,
  });

  final ImageOperation operation;
  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            operation.label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (index) {
              final active = index < step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class SelectedImageCard extends StatelessWidget {
  const SelectedImageCard({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                file,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                cacheWidth: 256,
                cacheHeight: 256,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 64,
                  height: 64,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: file.length(),
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? 'Original ${FormatUtils.formatBytes(snapshot.data!)}'
                          : 'Reading image…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkflowActionBar extends StatelessWidget {
  const WorkflowActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      final primaryButton = FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label),
      );

      if (!compact) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                if (secondaryLabel != null) ...[
                  OutlinedButton(
                    onPressed: onSecondaryPressed,
                    child: Text(secondaryLabel!),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: primaryButton),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (secondaryLabel != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSecondaryPressed,
                    child: Text(secondaryLabel!),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(width: double.infinity, child: primaryButton),
            ],
          ),
        ),
      );
    },
  );
}

class ConfigSection extends StatelessWidget {
  const ConfigSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

String formatRatio(Size size) {
  if (size.width <= 0 || size.height <= 0) return '—';
  final ratio = size.width / size.height;
  if ((ratio - 1).abs() < 0.03) return '1:1';
  if ((ratio - 4 / 3).abs() < 0.03) return '4:3';
  if ((ratio - 16 / 9).abs() < 0.03) return '16:9';
  if ((ratio - 9 / 16).abs() < 0.03) return '9:16';
  return '${ratio.toStringAsFixed(2)}:1';
}

Rect centeredRectForRatio(Size sourceSize, CropAspectRatio cropRatio) {
  final target = cropRatio.ratio;
  if (target == null || sourceSize.height == 0) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
  final normalizedRatio = target / (sourceSize.width / sourceSize.height);
  final width = normalizedRatio >= 1 ? 1.0 : normalizedRatio;
  final height = normalizedRatio >= 1 ? 1 / normalizedRatio : 1.0;
  return Rect.fromLTWH((1 - width) / 2, (1 - height) / 2, width, height);
}

Rect rectFromDrag(
  Offset start,
  Offset current,
  Size sourceSize,
  CropAspectRatio cropRatio,
) {
  final left = start.dx < current.dx ? start.dx : current.dx;
  final top = start.dy < current.dy ? start.dy : current.dy;
  var width = (current.dx - start.dx).abs();
  var height = (current.dy - start.dy).abs();
  final ratio = cropRatio.ratio;
  if (ratio != null && sourceSize.height > 0 && height > 0) {
    final normalizedRatio = ratio / (sourceSize.width / sourceSize.height);
    if (width / height > normalizedRatio) {
      width = height * normalizedRatio;
    } else {
      height = width / normalizedRatio;
    }
  }
  width = width.clamp(0.02, 1.0 - left);
  height = height.clamp(0.02, 1.0 - top);
  final safeLeft = left.clamp(0.0, 1.0 - width);
  final safeTop = top.clamp(0.0, 1.0 - height);
  return Rect.fromLTWH(safeLeft, safeTop, width, height);
}

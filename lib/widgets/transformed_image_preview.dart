import 'dart:io';

import 'package:flutter/material.dart';

/// Mirrors the quarter-turn and flip settings used by image processing.
class TransformedImagePreview extends StatelessWidget {
  const TransformedImagePreview({
    super.key,
    required this.file,
    required this.rotationAngle,
    required this.flipHorizontal,
    required this.flipVertical,
  });
  final File file;
  final int rotationAngle;
  final bool flipHorizontal;
  final bool flipVertical;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: RotatedBox(
          quarterTurns: (rotationAngle ~/ 90) % 4,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              flipHorizontal ? -1 : 1,
              flipVertical ? -1 : 1,
              1,
            ),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              cacheWidth: 1024,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/processing_config.dart';
import '../screens/single_image_workflow_common.dart';

class CropSelectionCanvas extends StatefulWidget {
  const CropSelectionCanvas({
    super.key,
    required this.file,
    required this.sourceSize,
    required this.cropRect,
    this.cropRatio = CropAspectRatio.free,
    required this.onCropRectChanged,
  });

  final File file;
  final Size sourceSize;
  final Rect cropRect;
  final CropAspectRatio cropRatio;
  final ValueChanged<Rect> onCropRectChanged;

  @override
  State<CropSelectionCanvas> createState() => _CropSelectionCanvasState();
}

class _CropSelectionCanvasState extends State<CropSelectionCanvas> {
  Offset? _dragOrigin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final fitted = applyBoxFit(
          BoxFit.contain,
          widget.sourceSize,
          canvasSize,
        );
        final imageRect = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & canvasSize,
        );

        Offset? normalize(Offset position) {
          if (!imageRect.contains(position)) return null;
          return Offset(
            ((position.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
            ((position.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _dragOrigin = normalize(details.localPosition);
          },
          onPanUpdate: (details) {
            final origin = _dragOrigin;
            final current = normalize(details.localPosition);
            if (origin == null || current == null) return;
            widget.onCropRectChanged(
              rectFromDrag(
                origin,
                current,
                widget.sourceSize,
                widget.cropRatio,
              ),
            );
          },
          onPanEnd: (_) => _dragOrigin = null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: imageRect,
                child: Image.file(
                  widget.file,
                  fit: BoxFit.fill,
                  cacheWidth: 1024,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Text('Could not load this image.')),
                ),
              ),
              CustomPaint(
                painter: _CropOverlayPainter(
                  imageRect: imageRect,
                  cropRect: widget.cropRect,
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      'Drag on image to crop',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.imageRect, required this.cropRect});

  final Rect imageRect;
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final selected = Rect.fromLTRB(
      imageRect.left + cropRect.left * imageRect.width,
      imageRect.top + cropRect.top * imageRect.height,
      imageRect.left + cropRect.right * imageRect.width,
      imageRect.top + cropRect.bottom * imageRect.height,
    );
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.58);
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageRect)
      ..addRect(selected);
    canvas.drawPath(mask, shade);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(selected, border);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final dx = selected.left + selected.width * i / 3;
      final dy = selected.top + selected.height * i / 3;
      canvas.drawLine(
        Offset(dx, selected.top),
        Offset(dx, selected.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(selected.left, dy),
        Offset(selected.right, dy),
        grid,
      );
    }

    final handle = Paint()..color = Colors.white;
    const radius = 4.0;
    for (final point in [
      selected.topLeft,
      selected.topRight,
      selected.bottomLeft,
      selected.bottomRight,
    ]) {
      canvas.drawCircle(point, radius, handle);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.imageRect != imageRect || oldDelegate.cropRect != cropRect;
}

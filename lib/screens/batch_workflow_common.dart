import 'dart:io';

import 'package:flutter/material.dart';

class BatchWorkflowHeader extends StatelessWidget {
  const BatchWorkflowHeader({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
  });
  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!)],
        const SizedBox(height: 12),
        Row(
          children: List.generate(
            5,
            (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                decoration: BoxDecoration(
                  color: i < step
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class BatchFileTile extends StatefulWidget {
  const BatchFileTile({
    super.key,
    required this.file,
    this.onRemove,
    this.trailing,
  });
  final File file;
  final VoidCallback? onRemove;
  final Widget? trailing;
  @override
  State<BatchFileTile> createState() => _BatchFileTileState();
}

class _BatchFileTileState extends State<BatchFileTile> {
  late Future<int?> _length;
  @override
  void initState() {
    super.initState();
    _length = _readLength();
  }

  @override
  void didUpdateWidget(covariant BatchFileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _length = _readLength();
  }

  Future<int?> _readLength() async {
    try {
      return await widget.file.length();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          widget.file,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          cacheWidth: 160,
          errorBuilder: (_, _, _) => Container(
            width: 52,
            height: 52,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
      title: Text(
        widget.file.uri.pathSegments.isEmpty
            ? widget.file.path
            : widget.file.uri.pathSegments.last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: FutureBuilder<int?>(
        future: _length,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return Text(
            bytes == null
                ? 'Image selected'
                : '${(bytes / 1024).toStringAsFixed(1)} KB',
          );
        },
      ),
      trailing:
          widget.trailing ??
          (widget.onRemove == null
              ? null
              : IconButton(
                  tooltip: 'Remove image',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                )),
    ),
  );
}

class BatchActionBar extends StatelessWidget {
  const BatchActionBar({
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
                  const SizedBox(width: 10),
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

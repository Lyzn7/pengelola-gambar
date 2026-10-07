import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_job.dart';
import '../models/processing_config.dart';
import '../providers/image_processor_provider.dart';
import '../utils/format_utils.dart';
import 'batch_processing_screen.dart';
import 'batch_workflow_common.dart';
import 'single_image_workflow_common.dart' show ImageOperationLabel;

class BatchReviewSettingsScreen extends StatelessWidget {
  const BatchReviewSettingsScreen({super.key, required this.job});
  final BatchImageJob job;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ImageProcessorProvider>();
    if (!identical(provider.activeJob, job)) {
      return const Scaffold(
        body: Center(child: Text('This batch session is no longer active.')),
      );
    }
    final config = job.config;
    final operation = operationForConfig(config);
    final resize = config.resizeWidth == null && config.resizeHeight == null
        ? 'Disabled'
        : '${config.resizeWidth ?? 'auto'} × ${config.resizeHeight ?? 'auto'}${config.keepAspectRatio ? ' (ratio preserved)' : ''}';
    final target = config.targetMaxSizeBytes == null
        ? 'Disabled'
        : FormatUtils.formatBytes(config.targetMaxSizeBytes!);
    final crop =
        config.customCropRect != null ||
            config.cropRatio != CropAspectRatio.free
        ? '${config.cropRatio.label}${config.customCropRect == null ? ' (centered)' : ' (custom crop)'}'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BatchWorkflowHeader(
            step: 4,
            title: 'Confirm batch settings',
            subtitle: 'Review the operation before processing.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingRow(label: 'Images', value: '${job.inputs.length}'),
                  _SettingRow(label: 'Operation', value: operation.label),
                  _SettingRow(
                    label: 'Output',
                    value: config.targetFormat.label,
                  ),
                  _SettingRow(label: 'Quality', value: '${config.quality}%'),
                  _SettingRow(label: 'Resize', value: resize),
                  _SettingRow(label: 'Target size', value: target),
                  if (crop != null) _SettingRow(label: 'Crop', value: crop),
                  if (config.rotationAngle != 0)
                    _SettingRow(
                      label: 'Rotation',
                      value: '${config.rotationAngle}°',
                    ),
                  if (config.flipHorizontal || config.flipVertical)
                    _SettingRow(
                      label: 'Flip',
                      value: [
                        if (config.flipHorizontal) 'Horizontal',
                        if (config.flipVertical) 'Vertical',
                      ].join(', '),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BatchActionBar(
        label: 'Start processing',
        enabled: job.inputs.isNotEmpty,
        onPressed: () {
          if (job.inputs.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select at least one image.')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BatchProcessingScreen(job: job)),
          );
        },
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

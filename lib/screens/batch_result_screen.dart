import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_job.dart';
import '../providers/image_processor_provider.dart';
import '../utils/format_utils.dart';
import 'batch_review_input_screen.dart';
import 'batch_select_screen.dart';
import 'batch_workflow_common.dart';

class BatchResultScreen extends StatelessWidget {
  const BatchResultScreen({super.key, required this.job});
  final BatchImageJob job;

  String get _title => switch (job.status) {
    ImageJobStatus.completed => 'Batch Complete',
    ImageJobStatus.partialSuccess => 'Batch Partially Completed',
    ImageJobStatus.failed => 'Batch Failed',
    _ => 'Batch Result',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ImageProcessorProvider>();
    if (!identical(provider.activeJob, job)) {
      return const Scaffold(
        body: Center(child: Text('This batch result is no longer active.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BatchWorkflowHeader(
            step: 5,
            title: _title,
            subtitle: 'Review each image result below.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryCount(label: 'Total', value: '${job.inputs.length}'),
                  _SummaryCount(
                    label: 'Successful',
                    value: '${job.successCount}',
                  ),
                  _SummaryCount(label: 'Failed', value: '${job.failedCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in job.items) _BatchResultItem(item: item),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (job.inputs.isNotEmpty && job.failedCount > 0) ...[
                OutlinedButton(
                  onPressed: () {
                    final retry = provider.createBatchJobAgain(job);
                    if (retry == null) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchReviewInputScreen(job: retry),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text('Retry all'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (!provider.startNewBatchJob()) return;
                    final next = provider.activeJob as BatchImageJob;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchSelectScreen(job: next),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text('New Batch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchResultItem extends StatelessWidget {
  const _BatchResultItem({required this.item});
  final BatchImageItem item;

  @override
  Widget build(BuildContext context) {
    final result = item.result;
    final success = item.status == BatchItemStatus.success && result != null;
    final file = success ? File(result.outputPath) : item.input;
    final filename = item.input.uri.pathSegments.isEmpty
        ? item.input.path
        : item.input.uri.pathSegments.last;
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            cacheWidth: 160,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: success
            ? Text(
                '${result.outputWidth} × ${result.outputHeight} · ${FormatUtils.formatBytes(result.outputSizeBytes)} · ${result.format.label}',
              )
            : const Text(
                'Failed to process image. Try another file or output format.',
              ),
        trailing: Icon(
          success ? Icons.check_circle : Icons.error_outline,
          color: success ? Colors.green : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      Text(label),
    ],
  );
}

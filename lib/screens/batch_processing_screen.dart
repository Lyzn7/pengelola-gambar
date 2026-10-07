import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_job.dart';
import '../providers/image_processor_provider.dart';
import 'batch_result_screen.dart';

class BatchProcessingScreen extends StatefulWidget {
  const BatchProcessingScreen({super.key, required this.job});
  final BatchImageJob job;
  @override
  State<BatchProcessingScreen> createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends State<BatchProcessingScreen> {
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ImageProcessorProvider>();
      final accepted = await provider.processBatchImages(
        expectedJobId: widget.job.id,
      );
      if (!mounted) return;
      final active = provider.activeJob;
      final completed =
          active is BatchImageJob &&
          active.id == widget.job.id &&
          active.hasProcessingSnapshot &&
          active.processingInputs.isNotEmpty &&
          active.processedCount == active.processingInputs.length &&
          active.status != ImageJobStatus.processing;
      if (completed) {
        setState(() {});
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BatchResultScreen(job: active)),
          (route) => route.isFirst,
        );
      } else {
        setState(
          () => _error = accepted ? null : 'Batch processing could not be completed. Check the selected images and try again.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ImageProcessorProvider>();
    final job = widget.job;
    if (!identical(provider.activeJob, job)) {
      return const Scaffold(
        body: Center(child: Text('This batch session is no longer active.')),
      );
    }
    final total = job.processingInputs.isEmpty
        ? job.inputs.length
        : job.processingInputs.length;
    final processingCount = job.items
        .where((item) => item.status == BatchItemStatus.processing)
        .length;
    final pending = job.items
        .where((item) => item.status == BatchItemStatus.pending)
        .length;
    final processing = job.status == ImageJobStatus.processing;
    return PopScope(
      canPop: !processing && _error != null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Processing Batch')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (processing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Processing ${job.inputs.length} images…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _CountRow(
                            label: 'Completed',
                            value: '${job.successCount}',
                          ),
                          _CountRow(
                            label: 'Failed',
                            value: '${job.failedCount}',
                          ),
                          _CountRow(
                            label: 'In progress',
                            value: '$processingCount',
                          ),
                          _CountRow(label: 'Pending', value: '$pending'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Processing cannot be cancelled. You can leave this screen after it finishes.',
                    textAlign: TextAlign.center,
                  ),
                ] else if (_error == null &&
                    job.hasProcessingSnapshot &&
                    job.processedCount == total) ...[
                  const Icon(Icons.check_circle_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Batch processing complete.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchResultScreen(job: job),
                      ),
                    ),
                    child: const Text('View results'),
                  ),
                ] else if (_error != null) ...[
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to settings'),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Preparing batch…'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

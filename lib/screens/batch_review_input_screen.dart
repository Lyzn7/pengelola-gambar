import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_job.dart';
import '../providers/image_processor_provider.dart';
import 'batch_configure_screen.dart';
import 'batch_workflow_common.dart';

class BatchReviewInputScreen extends StatefulWidget {
  const BatchReviewInputScreen({super.key, required this.job});
  final BatchImageJob job;
  @override
  State<BatchReviewInputScreen> createState() => _BatchReviewInputScreenState();
}

class _BatchReviewInputScreenState extends State<BatchReviewInputScreen> {
  bool _picking = false;
  Future<void> _addMore() async {
    setState(() => _picking = true);
    await context.read<ImageProcessorProvider>().pickBatchImages(append: true);
    if (mounted) setState(() => _picking = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Review Input')),
      body: Column(
        children: [
          BatchWorkflowHeader(
            step: 2,
            title: 'Review selected images',
            subtitle: 'Confirm the ${job.inputs.length} images to process.',
          ),
          if (job.error != null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Image selection failed. Existing selected images are still available.',
              ),
            ),
          Expanded(
            child: job.items.isEmpty
                ? const Center(
                    child: Text('No images selected. Go back and add images.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: job.items.length,
                    itemBuilder: (_, index) => BatchFileTile(
                      key: ValueKey('${job.id}:review:$index'),
                      file: job.items[index].input,
                      onRemove: () => provider.removeBatchFileAt(index),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: _picking ? null : _addMore,
              icon: const Icon(Icons.add),
              label: Text(_picking ? 'Opening picker…' : 'Add more images'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BatchActionBar(
        label: 'Configure batch',
        enabled: job.inputs.isNotEmpty && !_picking,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BatchConfigureScreen(job: job)),
        ),
      ),
    );
  }
}

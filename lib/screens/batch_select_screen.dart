import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_job.dart';
import '../providers/image_processor_provider.dart';
import 'batch_review_input_screen.dart';
import 'batch_workflow_common.dart';

class BatchSelectScreen extends StatefulWidget {
  const BatchSelectScreen({super.key, required this.job});
  final BatchImageJob job;
  @override
  State<BatchSelectScreen> createState() => _BatchSelectScreenState();
}

class _BatchSelectScreenState extends State<BatchSelectScreen> {
  bool _picking = false;

  Future<void> _addImages() async {
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
      appBar: AppBar(title: const Text('Select Images')),
      body: Column(
        children: [
          BatchWorkflowHeader(
            step: 1,
            title: 'Choose images',
            subtitle: '${job.inputs.length} selected',
          ),
          if (job.error != null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Image selection failed. Try adding the images again.',
              ),
            ),
          if (job.inputs.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Add one or more image files to start a batch.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: job.items.length,
                itemBuilder: (_, index) => BatchFileTile(
                  key: ValueKey('${job.id}:$index'),
                  file: job.items[index].input,
                  onRemove: () => provider.removeBatchFileAt(index),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: _picking ? null : _addImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_picking ? 'Opening picker…' : 'Add images'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BatchActionBar(
        label: 'Review images (${job.inputs.length})',
        enabled: job.inputs.isNotEmpty && !_picking,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BatchReviewInputScreen(job: job)),
        ),
      ),
    );
  }
}

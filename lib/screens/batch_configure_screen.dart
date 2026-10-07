import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_job.dart';
import '../models/preset_model.dart';
import '../models/processing_config.dart';
import '../providers/image_processor_provider.dart';
import 'batch_review_settings_screen.dart';
import 'batch_workflow_common.dart';

class BatchConfigureScreen extends StatefulWidget {
  const BatchConfigureScreen({super.key, required this.job});
  final BatchImageJob job;
  @override
  State<BatchConfigureScreen> createState() => _BatchConfigureScreenState();
}

class _BatchConfigureScreenState extends State<BatchConfigureScreen> {
  late final TextEditingController _width;
  late final TextEditingController _height;
  late bool _resizeEnabled;

  @override
  void initState() {
    super.initState();
    final config = widget.job.config;
    _width = TextEditingController(text: '${config.resizeWidth ?? ''}');
    _height = TextEditingController(text: '${config.resizeHeight ?? ''}');
    _resizeEnabled = config.resizeWidth != null || config.resizeHeight != null;
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _update(ProcessingConfig config) =>
      context.read<ImageProcessorProvider>().updateBatchConfig(config);

  void _updateResize(ProcessingConfig config, {String? edited}) {
    final lock = config.keepAspectRatio;
    int? width = int.tryParse(_width.text);
    int? height = int.tryParse(_height.text);
    if (lock && edited == 'width' && width != null) {
      height = null;
      _height.clear();
    }
    if (lock && edited == 'height' && height != null) {
      width = null;
      _width.clear();
    }
    _update(
      config.copyWith(
        resizeWidth: _resizeEnabled ? width : null,
        resizeHeight: _resizeEnabled ? height : null,
      ),
    );
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
    final config = job.config;
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Batch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BatchWorkflowHeader(
            step: 3,
            title: 'Batch settings',
            subtitle: 'These settings apply to every selected image.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Output format',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ImageOutputFormat.values
                        .map(
                          (format) => ChoiceChip(
                            label: Text(format.label),
                            selected: config.targetFormat == format,
                            onSelected: (_) => _update(
                              config.copyWith(
                                targetFormat: format,
                                targetMaxSizeBytes:
                                    format == ImageOutputFormat.png
                                    ? null
                                    : config.targetMaxSizeBytes,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quality',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: config.quality.toDouble().clamp(10, 100),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${config.quality}%',
                    onChanged: (value) =>
                        _update(config.copyWith(quality: value.round())),
                  ),
                  Text('${config.quality}%'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Resize images'),
                    value: _resizeEnabled,
                    onChanged: (value) {
                      setState(() => _resizeEnabled = value);
                      if (!value) {
                        _width.clear();
                        _height.clear();
                      }
                      _update(
                        config.copyWith(
                          resizeWidth: value ? config.resizeWidth : null,
                          resizeHeight: value ? config.resizeHeight : null,
                        ),
                      );
                    },
                  ),
                  if (_resizeEnabled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _width,
                            enabled: _resizeEnabled,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: config.keepAspectRatio
                                  ? 'Width (max)'
                                  : 'Width',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) =>
                                _updateResize(config, edited: 'width'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _height,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: config.keepAspectRatio
                                  ? 'Height (max)'
                                  : 'Height',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) =>
                                _updateResize(config, edited: 'height'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Maintain each image aspect ratio'),
                      value: config.keepAspectRatio,
                      onChanged: (value) {
                        if (value && _width.text.isNotEmpty) {
                          _height.clear();
                        } else if (value && _height.text.isNotEmpty) {
                          _width.clear();
                        }
                        _update(
                          config.copyWith(
                            keepAspectRatio: value,
                            resizeWidth: int.tryParse(_width.text),
                            resizeHeight: int.tryParse(_height.text),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Presets',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PresetModel.defaultPresets
                        .map(
                          (preset) => ActionChip(
                            label: Text(preset.name),
                            onPressed: () {
                              _width.text =
                                  '${preset.config.resizeWidth ?? ''}';
                              _height.text =
                                  '${preset.config.resizeHeight ?? ''}';
                              setState(
                                () => _resizeEnabled =
                                    preset.config.resizeWidth != null ||
                                    preset.config.resizeHeight != null,
                              );
                              _update(preset.config);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          if (config.targetFormat == ImageOutputFormat.jpg)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<int?>(
                  initialValue: config.targetMaxSizeBytes,
                  decoration: const InputDecoration(
                    labelText: 'Optional JPEG target size',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('No target')),
                    DropdownMenuItem(value: 200 * 1024, child: Text('200 KB')),
                    DropdownMenuItem(value: 500 * 1024, child: Text('500 KB')),
                    DropdownMenuItem(value: 1024 * 1024, child: Text('1 MB')),
                  ],
                  onChanged: (value) =>
                      _update(config.copyWith(targetMaxSizeBytes: value)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BatchActionBar(
        label: 'Review settings',
        enabled: job.inputs.isNotEmpty,
        onPressed: () {
          if (_resizeEnabled) {
            final width = int.tryParse(_width.text);
            final height = int.tryParse(_height.text);
            if (width == null && height == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a width or height for batch resizing.'),
                ),
              );
              return;
            }
            if ([width, height].whereType<int>().any(
              (dimension) => dimension < 10 || dimension > 8000,
            )) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Resize dimensions must be between 10 and 8000 pixels.',
                  ),
                ),
              );
              return;
            }
          }
          if (!job.beginReview()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Select at least one image before continuing.'),
              ),
            );
            return;
          }
          provider.notifyJobChanged();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BatchReviewSettingsScreen(job: job),
            ),
          );
        },
      ),
    );
  }
}

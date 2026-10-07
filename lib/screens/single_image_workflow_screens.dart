import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_job.dart';
import '../models/processing_config.dart';
import '../models/preset_model.dart';
import '../providers/image_processor_provider.dart';
import '../utils/format_utils.dart';
import '../widgets/before_after_viewer.dart';
import '../widgets/crop_selection_canvas.dart';
import '../widgets/transformed_image_preview.dart';
import 'single_image_workflow_common.dart';

class PresetSummaryScreen extends StatelessWidget {
  const PresetSummaryScreen({super.key, required this.preset});
  final PresetModel preset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(preset.name)),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(preset.icon, size: 48, color: preset.color),
          const SizedBox(height: 16),
          Text(preset.description),
          const SizedBox(height: 16),
          Text('Operation: ${operationForConfig(preset.config).label}'),
          if (preset.config.resizeWidth != null)
            Text('Width: ${preset.config.resizeWidth}px'),
          if (preset.config.cropRatio != CropAspectRatio.free)
            Text('Crop: ${preset.config.cropRatio.label}'),
          if (preset.config.targetMaxSizeBytes != null)
            Text(
              'Maximum size: ${FormatUtils.formatBytes(preset.config.targetMaxSizeBytes!)}',
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SingleImageSelectScreen(
                    operation: operationForConfig(preset.config),
                    config: preset.config,
                  ),
                ),
              ),
              child: const Text('Apply to new image'),
            ),
          ),
        ],
      ),
    ),
  );
}

class SingleImageSelectScreen extends StatelessWidget {
  const SingleImageSelectScreen({
    super.key,
    required this.operation,
    this.config,
  });
  final ImageOperation operation;
  final ProcessingConfig? config;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Select ${operation.label} image')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Choose an image for ${operation.label.toLowerCase()}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose image'),
              onPressed: () async {
                final provider = context.read<ImageProcessorProvider>();
                final selected = await provider.startSingleJob(
                  operation: operation,
                  config: config,
                  source: ImageSource.gallery,
                );
                if (!context.mounted || !selected) return;
                final job = provider.activeJob;
                if (job is SingleImageJob) {
                  if (operation == ImageOperation.convert && config == null) {
                    final isPng = job.input!.path.toLowerCase().endsWith(
                      '.png',
                    );
                    provider.updateSingleConfig(
                      job.config.copyWith(
                        targetFormat: isPng
                            ? ImageOutputFormat.jpg
                            : ImageOutputFormat.png,
                      ),
                    );
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SingleImageConfigureScreen(job: job),
                    ),
                  );
                }
              },
            ),
            if (context.watch<ImageProcessorProvider>().selectionErrorMessage !=
                null) ...[
              const SizedBox(height: 12),
              Text(
                'Image selection failed. Try choosing another image.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SingleImageConfigureScreen extends StatefulWidget {
  const SingleImageConfigureScreen({super.key, required this.job});
  final SingleImageJob job;
  @override
  State<SingleImageConfigureScreen> createState() =>
      _SingleImageConfigureScreenState();
}

class _SingleImageConfigureScreenState
    extends State<SingleImageConfigureScreen> {
  late final TextEditingController _width = TextEditingController(
    text: '${widget.job.config.resizeWidth ?? ''}',
  );
  late final TextEditingController _height = TextEditingController(
    text: '${widget.job.config.resizeHeight ?? ''}',
  );
  Size? _sourceSize;
  bool _aspectLock = true;
  @override
  void initState() {
    super.initState();
    _aspectLock = widget.job.config.keepAspectRatio;
    _loadSize();
  }

  Future<void> _loadSize() async {
    final input = widget.job.input;
    if (input == null) return;
    try {
      final size = await loadPreviewImageSize(input);
      if (mounted) setState(() => _sourceSize = size);
    } catch (_) {}
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _update(ProcessingConfig config) =>
      context.read<ImageProcessorProvider>().updateSingleConfig(config);
  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final provider = context.watch<ImageProcessorProvider>();
    if (!identical(provider.activeJob, job) || job.input == null) {
      return const Scaffold(
        body: Center(child: Text('This image workflow is no longer active.')),
      );
    }
    final config = job.config;
    final crop = job.operation == ImageOperation.cropTransform;
    final title = switch (job.operation) {
      ImageOperation.compress => 'Compression settings',
      ImageOperation.resize => 'Resize settings',
      ImageOperation.convert => 'Convert format',
      ImageOperation.cropTransform => 'Crop and transform',
      ImageOperation.batch => 'Settings',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkflowStepHeader(
            operation: job.operation,
            step: 1,
            title: title,
            subtitle: 'Configure this image before previewing.',
          ),
          SelectedImageCard(file: job.input!),
          if (job.operation == ImageOperation.compress) ...[
            ConfigSection(
              title: 'Quality',
              child: Column(
                children: [
                  Slider(
                    value: config.quality.toDouble().clamp(10, 100),
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${config.quality}%',
                    onChanged: (v) =>
                        _update(config.copyWith(quality: v.round())),
                  ),
                  Text('${config.quality}%'),
                ],
              ),
            ),
            _formatChoice(
              config,
              (f) => _update(
                config.copyWith(
                  targetFormat: f,
                  targetMaxSizeBytes: f == ImageOutputFormat.png
                      ? null
                      : config.targetMaxSizeBytes,
                ),
              ),
            ),
            if (config.targetFormat == ImageOutputFormat.jpg)
              ConfigSection(
                title: 'Target size (JPEG)',
                child: DropdownButtonFormField<int?>(
                  initialValue: config.targetMaxSizeBytes,
                  decoration: const InputDecoration(
                    labelText: 'Optional maximum size',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('No target')),
                    DropdownMenuItem(value: 200 * 1024, child: Text('200 KB')),
                    DropdownMenuItem(value: 500 * 1024, child: Text('500 KB')),
                    DropdownMenuItem(value: 1024 * 1024, child: Text('1 MB')),
                  ],
                  onChanged: (v) =>
                      _update(config.copyWith(targetMaxSizeBytes: v)),
                ),
              ),
          ],
          if (job.operation == ImageOperation.resize) ...[
            ConfigSection(
              title: 'Dimensions (pixels)',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _width,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Width',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final w = int.tryParse(v);
                            final h =
                                _aspectLock && w != null && _sourceSize != null
                                ? (w * _sourceSize!.height / _sourceSize!.width)
                                      .round()
                                : int.tryParse(_height.text);
                            _height.text = h?.toString() ?? '';
                            _update(
                              config.copyWith(
                                resizeWidth: w,
                                resizeHeight: h,
                                keepAspectRatio: _aspectLock,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _height,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final h = int.tryParse(v);
                            final w =
                                _aspectLock && h != null && _sourceSize != null
                                ? (h * _sourceSize!.width / _sourceSize!.height)
                                      .round()
                                : int.tryParse(_width.text);
                            _width.text = w?.toString() ?? '';
                            _update(
                              config.copyWith(
                                resizeWidth: w,
                                resizeHeight: h,
                                keepAspectRatio: _aspectLock,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Maintain aspect ratio'),
                    value: _aspectLock,
                    onChanged: (v) {
                      setState(() => _aspectLock = v);
                      _update(config.copyWith(keepAspectRatio: v));
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: PresetModel.defaultPresets
                        .where((p) => p.config.resizeWidth != null)
                        .map(
                          (p) => ActionChip(
                            label: Text(
                              '${p.name} · ${p.config.resizeWidth}px',
                            ),
                            onPressed: () {
                              _width.text = '${p.config.resizeWidth}';
                              final h = _sourceSize == null
                                  ? null
                                  : (p.config.resizeWidth! *
                                            _sourceSize!.height /
                                            _sourceSize!.width)
                                        .round();
                              _height.text = h?.toString() ?? '';
                              _update(
                                config.copyWith(
                                  resizeWidth: p.config.resizeWidth,
                                  resizeHeight: h,
                                  keepAspectRatio: true,
                                ),
                              );
                              setState(() => _aspectLock = true);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
          if (job.operation == ImageOperation.convert) ...[
            Text('Current format: ${_formatFromPath(job.input!.path)}'),
            _formatChoice(
              config,
              (f) => _update(
                config.copyWith(targetFormat: f, targetMaxSizeBytes: null),
              ),
            ),
            if (config.targetFormat == ImageOutputFormat.jpg)
              ConfigSection(
                title: 'JPEG quality',
                child: Slider(
                  value: config.quality.toDouble().clamp(10, 100),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${config.quality}%',
                  onChanged: (v) =>
                      _update(config.copyWith(quality: v.round())),
                ),
              ),
          ],
          if (crop) ...[
            if (_sourceSize == null)
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: 300,
                child: CropSelectionCanvas(
                  file: job.input!,
                  sourceSize: _sourceSize!,
                  cropRatio: config.cropRatio,
                  cropRect:
                      config.customCropRect ??
                      centeredRectForRatio(_sourceSize!, config.cropRatio),
                  onCropRectChanged: (r) =>
                      _update(config.copyWith(customCropRect: r)),
                ),
              ),
            ConfigSection(
              title: 'Aspect ratio',
              child: Wrap(
                spacing: 8,
                children: CropAspectRatio.values
                    .map(
                      (r) => ChoiceChip(
                        label: Text(r.label),
                        selected: config.cropRatio == r,
                        onSelected: (_) => _update(
                          config.copyWith(
                            cropRatio: r,
                            customCropRect: _sourceSize == null
                                ? null
                                : centeredRectForRatio(_sourceSize!, r),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            ConfigSection(
              title: 'Transform',
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: 'Rotate left',
                    onPressed: () => _update(
                      config.copyWith(
                        rotationAngle: (config.rotationAngle + 270) % 360,
                      ),
                    ),
                    icon: const Icon(Icons.rotate_left),
                  ),
                  IconButton(
                    tooltip: 'Rotate right',
                    onPressed: () => _update(
                      config.copyWith(
                        rotationAngle: (config.rotationAngle + 90) % 360,
                      ),
                    ),
                    icon: const Icon(Icons.rotate_right),
                  ),
                  FilterChip(
                    label: const Text('Flip horizontal'),
                    selected: config.flipHorizontal,
                    onSelected: (v) =>
                        _update(config.copyWith(flipHorizontal: v)),
                  ),
                  FilterChip(
                    label: const Text('Flip vertical'),
                    selected: config.flipVertical,
                    onSelected: (v) =>
                        _update(config.copyWith(flipVertical: v)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: WorkflowActionBar(
        label: 'Preview',
        onPressed: () {
          if (job.operation == ImageOperation.resize &&
              (config.resizeWidth == null && config.resizeHeight == null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a valid width or height.')),
            );
            return;
          }
          if (!job.beginReview()) return;
          provider.notifyJobChanged();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SingleImagePreviewScreen(job: job),
            ),
          );
        },
      ),
    );
  }

  Widget _formatChoice(
    ProcessingConfig config,
    ValueChanged<ImageOutputFormat> onSelect,
  ) => ConfigSection(
    title: 'Output format',
    child: Wrap(
      spacing: 8,
      children: ImageOutputFormat.values
          .map(
            (f) => ChoiceChip(
              label: Text(f.label),
              selected: config.targetFormat == f,
              onSelected: (_) => onSelect(f),
            ),
          )
          .toList(),
    ),
  );
  String _formatFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'JPG',
      'png' => 'PNG',
      '' => 'Unknown',
      _ => ext.toUpperCase(),
    };
  }
}

class SingleImagePreviewScreen extends StatelessWidget {
  const SingleImagePreviewScreen({super.key, required this.job});
  final SingleImageJob job;
  @override
  Widget build(BuildContext context) {
    final config = job.config;
    final input = job.input!;
    final dims = switch (job.operation) {
      ImageOperation.resize =>
        '${config.resizeWidth ?? 'auto'} x ${config.resizeHeight ?? 'auto'} px',
      ImageOperation.cropTransform =>
        'Crop ${config.cropRatio.label}; rotate ${config.rotationAngle} degrees${config.flipHorizontal ? '; horizontal flip' : ''}${config.flipVertical ? '; vertical flip' : ''}',
      ImageOperation.compress =>
        '${config.quality}% quality; ${config.targetFormat.label}${config.targetMaxSizeBytes == null ? '' : '; max ${FormatUtils.formatBytes(config.targetMaxSizeBytes!)}'}',
      ImageOperation.convert =>
        '${_sourceFormat(input.path)} to ${config.targetFormat.label}${config.targetFormat == ImageOutputFormat.jpg ? '; ${config.quality}% quality' : ''}',
      ImageOperation.batch => '',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkflowStepHeader(
            operation: job.operation,
            step: 2,
            title: 'Review settings',
          ),
          SelectedImageCard(file: input),
          if (job.operation == ImageOperation.cropTransform) ...[
            const SizedBox(height: 12),
            ConfigSection(
              title: 'Transform preview',
              child: SizedBox(
                height: 240,
                child: TransformedImagePreview(
                  file: input,
                  rotationAngle: config.rotationAngle,
                  flipHorizontal: config.flipHorizontal,
                  flipVertical: config.flipVertical,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ConfigSection(
            title: '${job.operation.label} summary',
            child: Text(dims),
          ),
          if (job.operation == ImageOperation.cropTransform)
            const Text(
              'The crop frame uses the original orientation. Rotation and flips are applied after cropping.',
            ),
        ],
      ),
      bottomNavigationBar: WorkflowActionBar(
        label: 'Process image',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SingleImageProcessingScreen(job: job),
            ),
          );
        },
      ),
    );
  }

  String _sourceFormat(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'JPG',
      'png' => 'PNG',
      _ => ext.isEmpty ? 'Unknown' : ext.toUpperCase(),
    };
  }
}

class SingleImageProcessingScreen extends StatefulWidget {
  const SingleImageProcessingScreen({super.key, required this.job});
  final SingleImageJob job;
  @override
  State<SingleImageProcessingScreen> createState() =>
      _SingleImageProcessingScreenState();
}

class _SingleImageProcessingScreenState
    extends State<SingleImageProcessingScreen> {
  bool _started = false;
  bool? _success;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ok = await context
            .read<ImageProcessorProvider>()
            .processSingleImage(expectedJobId: widget.job.id);
        if (!mounted) return;
        setState(() => _success = ok);
        if (ok) {
          final active = context.read<ImageProcessorProvider>().activeJob;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SingleImageResultScreen(
                job: active is SingleImageJob ? active : widget.job,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _success != null,
    child: Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Center(
        child: _success == null
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing image…'),
                ],
              )
            : _success == true
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Processing complete.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final active = context
                          .read<ImageProcessorProvider>()
                          .activeJob;
                      if (active is SingleImageJob &&
                          active.id == widget.job.id) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SingleImageResultScreen(job: active),
                          ),
                        );
                      }
                    },
                    child: const Text('View result'),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Image could not be processed. Try another image or change the settings.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final next = context
                          .read<ImageProcessorProvider>()
                          .createSingleJobAgain(widget.job);
                      if (next != null) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SingleImageConfigureScreen(job: next),
                          ),
                          (route) => route.isFirst,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Back to settings'),
                  ),
                ],
              ),
      ),
    ),
  );
}

class SingleImageResultScreen extends StatelessWidget {
  const SingleImageResultScreen({super.key, required this.job});
  final SingleImageJob job;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ImageProcessorProvider>();
    final result = job.result;
    if (result == null) {
      return const Scaffold(
        body: Center(child: Text('No result is available.')),
      );
    }
    final stale = job.isResultStale || !identical(provider.activeJob, job);
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (stale)
            const Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('This result is stale'),
                subtitle: Text(
                  'Settings or input changed after processing. Process again to update it.',
                ),
              ),
            ),
          BeforeAfterViewer(result: result),
          const SizedBox(height: 12),
          Text(
            '${job.operation.label} · ${result.format.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${result.originalWidth} × ${result.originalHeight} → ${result.outputWidth} × ${result.outputHeight} px',
          ),
          Text(
            '${FormatUtils.formatBytes(result.originalSizeBytes)} → ${FormatUtils.formatBytes(result.outputSizeBytes)}',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: stale
                    ? null
                    : () async {
                        final ok = await provider.saveToGallery(
                          result.outputPath,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Saved to gallery.' : 'Could not save image. Check gallery access and try again.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.save_alt),
                label: const Text('Save'),
              ),
              OutlinedButton.icon(
                onPressed: stale
                    ? null
                    : () async {
                        final ok = await provider.shareFile(result.outputPath);
                        if (context.mounted && !ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not share image. Try again.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              FilledButton(
                onPressed: () {
                  final next = provider.createSingleJobAgain(job);
                  if (next != null) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SingleImageConfigureScreen(job: next),
                      ),
                      (route) => route.isFirst,
                    );
                  }
                },
                child: const Text('Process Again'),
              ),
              TextButton(
                onPressed: () {
                  provider.resetActiveJob();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SingleImageSelectScreen(operation: job.operation),
                    ),
                    (route) => route.isFirst,
                  );
                },
                child: const Text('New Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

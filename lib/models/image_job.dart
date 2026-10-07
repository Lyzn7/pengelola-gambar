import 'dart:io';

import 'processed_image_result.dart';
import 'processing_config.dart';

enum ImageOperation { compress, resize, convert, cropTransform, batch }

enum ImageJobStatus {
  idle,
  selecting,
  configuring,
  reviewing,
  processing,
  completed,
  partialSuccess,
  failed,
}

enum BatchItemStatus { pending, processing, success, failed }

ImageOperation operationForConfig(ProcessingConfig config) {
  if (config.cropRatio != CropAspectRatio.free ||
      config.customCropRect != null ||
      config.rotationAngle != 0 ||
      config.flipHorizontal ||
      config.flipVertical) {
    return ImageOperation.cropTransform;
  }
  if (config.resizeWidth != null || config.resizeHeight != null) {
    return ImageOperation.resize;
  }
  return ImageOperation.compress;
}

abstract class ImageJob {
  ImageJob({required this.operation, required ProcessingConfig config})
    : id = _newJobId(),
      createdAt = DateTime.now(),
      updatedAt = DateTime.now(),
      _config = config.copyWith();

  final String id;
  final ImageOperation operation;
  final DateTime createdAt;
  DateTime updatedAt;
  ProcessingConfig _config;
  ImageJobStatus _status = ImageJobStatus.idle;
  String? _error;
  ImageJobStatus get status => _status;
  String? get error => _error;

  ProcessingConfig get config => _config.copyWith();

  void updateConfig(ProcessingConfig value) {
    _config = value.copyWith();
    updatedAt = DateTime.now();
  }

  bool beginReview() {
    if (status == ImageJobStatus.reviewing) return true;
    if (status != ImageJobStatus.configuring) return false;
    _status = ImageJobStatus.reviewing;
    updatedAt = DateTime.now();
    return true;
  }

  static int _idSequence = 0;

  static String _newJobId() =>
      'job_${DateTime.now().microsecondsSinceEpoch}_${_idSequence++}';
}

class SingleImageJob extends ImageJob {
  // Operation is validated because batch jobs use a distinct model.
  // ignore: use_super_parameters
  SingleImageJob({
    required ImageOperation operation,
    required ProcessingConfig config,
    File? input,
  }) : assert(operation != ImageOperation.batch),
       _input = input,
       super(operation: operation, config: config) {
    _status = input == null ? ImageJobStatus.idle : ImageJobStatus.configuring;
  }

  File? _input;
  ProcessedImageResult? _result;
  ProcessingConfig? _resultConfigSnapshot;
  String? _resultInputPath;
  bool _resultStale = false;

  File? get input => _input;
  ProcessedImageResult? get result => _result;
  ProcessingConfig? get resultConfigSnapshot =>
      _resultConfigSnapshot?.copyWith();
  bool get hasProcessingSnapshot => _resultConfigSnapshot != null;
  bool get isResultStale => result != null && _resultStale;

  void setInput(File? value) {
    if (status == ImageJobStatus.processing) return;
    if (_input?.path == value?.path) return;
    _input = value;
    _invalidateResult();
    _status = value == null
        ? ImageJobStatus.selecting
        : ImageJobStatus.configuring;
    _error = null;
    updatedAt = DateTime.now();
  }

  @override
  void updateConfig(ProcessingConfig value) {
    if (status == ImageJobStatus.processing) return;
    final changed = !_sameConfig(_config, value);
    super.updateConfig(value);
    if (changed) _refreshStaleness();
    if (status == ImageJobStatus.completed ||
        status == ImageJobStatus.partialSuccess ||
        status == ImageJobStatus.reviewing) {
      _status = ImageJobStatus.configuring;
    }
  }

  bool beginProcessing() {
    if (_input == null ||
        status == ImageJobStatus.processing ||
        (status != ImageJobStatus.configuring &&
            status != ImageJobStatus.reviewing)) {
      return false;
    }
    _resultConfigSnapshot = _config.copyWith();
    _resultInputPath = _input!.path;
    _status = ImageJobStatus.processing;
    _error = null;
    updatedAt = DateTime.now();
    return true;
  }

  SingleImageJob deriveForRetry() =>
      SingleImageJob(operation: operation, config: config, input: input);

  void complete(ProcessedImageResult value) {
    _result = value;
    _status = ImageJobStatus.completed;
    _error = null;
    _refreshStaleness();
    updatedAt = DateTime.now();
  }

  void fail(String message) {
    _error = message;
    _status = ImageJobStatus.failed;
    updatedAt = DateTime.now();
  }

  void setSelectionError(String? message) {
    if (status == ImageJobStatus.processing) return;
    _error = message;
    updatedAt = DateTime.now();
  }

  void _invalidateResult() {
    if (result != null) _resultStale = true;
  }

  void _refreshStaleness() {
    if (result == null || _resultConfigSnapshot == null) return;
    _resultStale =
        _resultInputPath != _input?.path ||
        !_sameConfig(_resultConfigSnapshot!, _config);
  }
}

class BatchImageItem {
  BatchImageItem(this.input);

  final File input;
  BatchItemStatus _status = BatchItemStatus.pending;
  ProcessedImageResult? _result;
  String? _error;
  BatchItemStatus get status => _status;
  ProcessedImageResult? get result => _result;
  String? get error => _error;
}

class BatchImageJob extends ImageJob {
  // The batch operation is fixed by this typed job.
  // ignore: use_super_parameters
  BatchImageJob({
    required ProcessingConfig config,
    List<File> inputs = const [],
  }) : _items = inputs.map(BatchImageItem.new).toList(),
       super(operation: ImageOperation.batch, config: config) {
    _status = inputs.isEmpty ? ImageJobStatus.idle : ImageJobStatus.configuring;
  }

  List<BatchImageItem> _items;
  List<File>? _processingInputs;
  ProcessingConfig? _processingConfigSnapshot;

  List<BatchImageItem> get items => List.unmodifiable(_items);
  List<File> get inputs => List.unmodifiable(_items.map((item) => item.input));
  List<File> get processingInputs =>
      List.unmodifiable(_processingInputs ?? const <File>[]);
  ProcessingConfig? get processingConfigSnapshot =>
      _processingConfigSnapshot?.copyWith();
  bool get hasProcessingSnapshot => _processingConfigSnapshot != null;
  List<ProcessedImageResult> get results => List.unmodifiable(
    _items.map((item) => item.result).whereType<ProcessedImageResult>(),
  );
  int get processedCount => _items
      .where(
        (item) =>
            item.status == BatchItemStatus.success ||
            item.status == BatchItemStatus.failed,
      )
      .length;
  int get successCount =>
      _items.where((item) => item.status == BatchItemStatus.success).length;
  int get failedCount =>
      _items.where((item) => item.status == BatchItemStatus.failed).length;

  bool addInputs(Iterable<File> files) {
    if (!_canMutateInputs) return false;
    _items.addAll(files.map(BatchImageItem.new));
    if (_items.isNotEmpty) _status = ImageJobStatus.configuring;
    _clearItemResults();
    updatedAt = DateTime.now();
    return true;
  }

  bool removeInputAt(int index) {
    if (!_canMutateInputs || index < 0 || index >= _items.length) return false;
    _items.removeAt(index);
    _status = _items.isEmpty
        ? ImageJobStatus.selecting
        : ImageJobStatus.configuring;
    _clearItemResults();
    updatedAt = DateTime.now();
    return true;
  }

  bool clearInputs() {
    if (!_canMutateInputs) return false;
    _items = [];
    _status = ImageJobStatus.selecting;
    _error = null;
    updatedAt = DateTime.now();
    return true;
  }

  BatchImageJob deriveForRetry() =>
      BatchImageJob(config: config, inputs: inputs);

  bool get _canMutateInputs => status != ImageJobStatus.processing;

  @override
  void updateConfig(ProcessingConfig value) {
    if (status == ImageJobStatus.processing) return;
    super.updateConfig(value);
    _clearItemResults();
    _status = _items.isNotEmpty
        ? ImageJobStatus.configuring
        : ImageJobStatus.idle;
  }

  bool beginProcessing() {
    if (status == ImageJobStatus.processing) return false;
    if (_items.isEmpty) {
      _status = ImageJobStatus.failed;
      _error = 'Pilih minimal satu gambar untuk pemrosesan batch.';
      updatedAt = DateTime.now();
      return false;
    }
    if (status != ImageJobStatus.configuring &&
        status != ImageJobStatus.reviewing) {
      return false;
    }
    _processingInputs = List<File>.unmodifiable(
      _items.map((item) => item.input),
    );
    _processingConfigSnapshot = _config.copyWith();
    for (final item in _items) {
      item
        .._status = BatchItemStatus.pending
        .._result = null
        .._error = null;
    }
    _status = ImageJobStatus.processing;
    _error = null;
    updatedAt = DateTime.now();
    return true;
  }

  @override
  bool beginReview() {
    if (status == ImageJobStatus.reviewing) return true;
    if (status != ImageJobStatus.configuring || _items.isEmpty) return false;
    _status = ImageJobStatus.reviewing;
    updatedAt = DateTime.now();
    return true;
  }

  void markItemProcessing(int index) {
    if (status != ImageJobStatus.processing ||
        index < 0 ||
        index >= _items.length ||
        _items[index].status != BatchItemStatus.pending) {
      return;
    }
    _items[index]._status = BatchItemStatus.processing;
    updatedAt = DateTime.now();
  }

  void completeItem(int index, ProcessedImageResult result) {
    if (status != ImageJobStatus.processing ||
        index < 0 ||
        index >= _items.length ||
        _items[index].status != BatchItemStatus.processing) {
      return;
    }
    _items[index]
      .._status = BatchItemStatus.success
      .._result = result
      .._error = null;
    updatedAt = DateTime.now();
  }

  void failItem(int index, String message) {
    if (status != ImageJobStatus.processing ||
        index < 0 ||
        index >= _items.length ||
        _items[index].status != BatchItemStatus.processing) {
      return;
    }
    _items[index]
      .._status = BatchItemStatus.failed
      .._error = message;
    updatedAt = DateTime.now();
  }

  bool finishProcessing() {
    if (status != ImageJobStatus.processing ||
        processedCount != _processingInputs?.length) {
      return false;
    }
    _status = failedCount == 0
        ? ImageJobStatus.completed
        : successCount == 0
        ? ImageJobStatus.failed
        : ImageJobStatus.partialSuccess;
    _error = failedCount == 0
        ? null
        : '$failedCount dari ${_items.length} gambar gagal diproses.';
    updatedAt = DateTime.now();
    return true;
  }

  void setSelectionError(String? message) {
    if (status == ImageJobStatus.processing) return;
    _error = message;
    updatedAt = DateTime.now();
  }

  void _clearItemResults() {
    for (final item in _items) {
      item
        .._status = BatchItemStatus.pending
        .._result = null
        .._error = null;
    }
    _error = null;
  }
}

bool _sameConfig(ProcessingConfig a, ProcessingConfig b) {
  final aRect = a.customCropRect;
  final bRect = b.customCropRect;
  return a.quality == b.quality &&
      a.targetFormat == b.targetFormat &&
      a.resizeWidth == b.resizeWidth &&
      a.resizeHeight == b.resizeHeight &&
      a.keepAspectRatio == b.keepAspectRatio &&
      a.cropRatio == b.cropRatio &&
      aRect?.left == bRect?.left &&
      aRect?.top == bRect?.top &&
      aRect?.width == bRect?.width &&
      aRect?.height == bRect?.height &&
      a.rotationAngle == b.rotationAngle &&
      a.flipHorizontal == b.flipHorizontal &&
      a.flipVertical == b.flipVertical &&
      a.targetMaxSizeBytes == b.targetMaxSizeBytes;
}

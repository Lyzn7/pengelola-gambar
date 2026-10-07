import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../models/image_job.dart';
import '../models/processing_config.dart';
import '../models/processed_image_result.dart';
import '../services/history_storage_service.dart';
import '../services/image_processor_service.dart';

typedef ImageFileProcessor = Future<ProcessedImageResult> Function({
  required File inputFile,
  required ProcessingConfig config,
});
typedef BatchFileSelector = Future<List<File>?> Function({
  required bool append,
});

class ImageProcessorProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  final ImageFileProcessor _imageProcessor;
  late final Future<File?> Function(ImageSource source) _singleFileSelector;
  late final BatchFileSelector _batchFileSelector;
  final Future<List<ProcessedImageResult>> Function() _historyLoader;
  final Future<void> Function(List<ProcessedImageResult>) _historySaver;

  ImageProcessorProvider({
    ImageFileProcessor? imageProcessor,
    Future<File?> Function(ImageSource source)? singleFileSelector,
    BatchFileSelector? batchFileSelector,
    Future<List<ProcessedImageResult>> Function()? historyLoader,
    Future<void> Function(List<ProcessedImageResult>)? historySaver,
  }) : _imageProcessor = imageProcessor ?? ImageProcessorService.processImage,
       _historyLoader = historyLoader ?? HistoryStorageService.load,
       _historySaver = historySaver ?? HistoryStorageService.save {
    _singleFileSelector = singleFileSelector ?? _defaultSingleFileSelector;
    _batchFileSelector = batchFileSelector ?? _defaultBatchFileSelector;
    _loadHistory();
  }

  // Active job is the single source of truth for transient processing state.
  ImageJob? _activeJob;
  ImageJob? get activeJob => _activeJob;

  // App-level persistent/history state.
  final List<ProcessedImageResult> _history = [];
  int _totalOriginalBytesAllTime = 0;
  int _totalOutputBytesAllTime = 0;
  String _geminiApiKey = '';
  String? _selectionErrorMessage;

  List<ProcessedImageResult> get history => List.unmodifiable(_history);
  int get totalOriginalBytes => _totalOriginalBytesAllTime;
  int get totalOutputBytes => _totalOutputBytesAllTime;
  int get totalBytesSaved =>
      _totalOriginalBytesAllTime - _totalOutputBytesAllTime;
  double get totalSavingsPercentage => _totalOriginalBytesAllTime == 0
      ? 0.0
      : ((_totalOriginalBytesAllTime - _totalOutputBytesAllTime) /
                _totalOriginalBytesAllTime) *
            100;

  String get geminiApiKey => _geminiApiKey;
  void setGeminiApiKey(String key) {
    _geminiApiKey = key.trim();
    notifyListeners();
  }

  SingleImageJob? get _singleJob =>
      _activeJob is SingleImageJob ? _activeJob as SingleImageJob : null;
  BatchImageJob? get _batchJob =>
      _activeJob is BatchImageJob ? _activeJob as BatchImageJob : null;
  String? get selectionErrorMessage => _selectionErrorMessage;

  bool get _activeJobIsProcessing =>
      _activeJob?.status == ImageJobStatus.processing;

  /// Selects an input first; only a successful selection replaces the active job.
  /// Cancelling the picker leaves the previous job untouched.
  Future<bool> startSingleJob({
    required ImageOperation operation,
    ProcessingConfig? config,
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_activeJobIsProcessing || operation == ImageOperation.batch) {
      return false;
    }
    final jobAtPickerStart = _activeJob;
    _selectionErrorMessage = null;
    try {
      final picked = await _singleFileSelector(source);
      if (picked == null) return false;
      if (_activeJobIsProcessing || !identical(_activeJob, jobAtPickerStart)) {
        return false;
      }
      _activeJob = SingleImageJob(
        operation: operation,
        config: config ?? ProcessingConfig(),
        input: picked,
      );
      notifyListeners();
      return true;
    } catch (error) {
      _selectionErrorMessage = 'Gagal memilih gambar: $error';
      notifyListeners();
      return false;
    }
  }

  /// Creates a fresh empty batch session. Processing jobs cannot be replaced.
  bool startNewBatchJob({ProcessingConfig? config}) {
    if (_activeJobIsProcessing) return false;
    _activeJob = BatchImageJob(config: config ?? ProcessingConfig());
    _selectionErrorMessage = null;
    notifyListeners();
    return true;
  }

  /// Creates a derived session for an explicit Process Again action.
  SingleImageJob? createSingleJobAgain(SingleImageJob source) {
    if (_activeJobIsProcessing || source.input == null) return null;
    final job = source.deriveForRetry();
    _activeJob = job;
    notifyListeners();
    return job;
  }

  BatchImageJob? createBatchJobAgain(BatchImageJob source) {
    if (_activeJobIsProcessing || source.inputs.isEmpty) return null;
    final job = source.deriveForRetry();
    _activeJob = job;
    notifyListeners();
    return job;
  }

  void resetActiveJob() {
    if (_activeJobIsProcessing) return;
    _activeJob = null;
    _selectionErrorMessage = null;
    notifyListeners();
  }

  Future<bool> pickBatchImages({bool append = false}) async {
    if (_activeJobIsProcessing) return false;
    final jobAtPickerStart = _activeJob;
    _selectionErrorMessage = null;
    try {
      final files = await _batchFileSelector(append: append);
      if (files == null || files.isEmpty) return false;
      if (_activeJobIsProcessing || !identical(_activeJob, jobAtPickerStart)) {
        return false;
      }
      if (append && _batchJob != null) {
        _batchJob!.addInputs(files);
      } else {
        _activeJob = BatchImageJob(config: ProcessingConfig(), inputs: files);
      }
      notifyListeners();
      return true;
    } catch (error) {
      final job = _batchJob;
      if (job != null) {
        job.setSelectionError('Gagal memilih banyak gambar: $error');
      } else {
        _selectionErrorMessage = 'Gagal memilih banyak gambar: $error';
      }
      notifyListeners();
      return false;
    }
  }

  void addBatchFiles(List<File> files) {
    _batchJob?.addInputs(files);
    notifyListeners();
  }

  void removeBatchFileAt(int index) {
    _batchJob?.removeInputAt(index);
    notifyListeners();
  }

  void clearBatch() {
    _batchJob?.clearInputs();
    notifyListeners();
  }

  void updateSingleConfig(ProcessingConfig newConfig) {
    _singleJob?.updateConfig(newConfig);
    notifyListeners();
  }

  void notifyJobChanged() => notifyListeners();

  void updateBatchConfig(ProcessingConfig newConfig) {
    _batchJob?.updateConfig(newConfig);
    notifyListeners();
  }

  Future<bool> processSingleImage({String? expectedJobId}) async {
    var job = _singleJob;
    if (job == null || (expectedJobId != null && job.id != expectedJobId)) {
      return false;
    }
    if (job.hasProcessingSnapshot) {
      final nextJob = createSingleJobAgain(job);
      if (nextJob == null) return false;
      job = nextJob;
    }
    if (!job.beginProcessing()) return false;
    final input = job.input!;
    final configSnapshot = job.config;
    notifyListeners();
    try {
      final result = await _imageProcessor(
        inputFile: input,
        config: configSnapshot,
      );
      if (!_ownsActiveJob(job)) return false;
      job.complete(result);
      await _recordToHistory(result);
      notifyListeners();
      return true;
    } catch (error) {
      if (!_ownsActiveJob(job)) return false;
      job.fail(_processingErrorMessage(error));
      notifyListeners();
      return false;
    }
  }

  Future<bool> processBatchImages({String? expectedJobId}) async {
    var job = _batchJob;
    if (job == null || (expectedJobId != null && job.id != expectedJobId)) {
      return false;
    }
    if (job.hasProcessingSnapshot) {
      final nextJob = createBatchJobAgain(job);
      if (nextJob == null) return false;
      job = nextJob;
    }
    if (!job.beginProcessing()) {
      notifyListeners();
      return false;
    }
    final inputs = job.processingInputs;
    final configSnapshot = job.processingConfigSnapshot!;
    notifyListeners();

    for (var index = 0; index < inputs.length; index++) {
      job.markItemProcessing(index);
      notifyListeners();
      try {
        final result = await _imageProcessor(
          inputFile: inputs[index],
          config: configSnapshot,
        );
        if (_ownsActiveJob(job)) {
          job.completeItem(index, result);
        }
        await _recordToHistory(result);
      } catch (error) {
        if (_ownsActiveJob(job)) {
          job.failItem(index, _processingErrorMessage(error));
        }
      }
      if (_ownsActiveJob(job)) notifyListeners();
    }

    final stillActive = _ownsActiveJob(job);
    final finished = stillActive && job.finishProcessing();
    if (stillActive) notifyListeners();
    return finished &&
        (job.status == ImageJobStatus.completed ||
            job.status == ImageJobStatus.partialSuccess);
  }

  bool _ownsActiveJob(ImageJob job) =>
      identical(_activeJob, job) && _activeJob?.id == job.id;

  String _processingErrorMessage(Object error) {
    if (error is ImageProcessingException) {
      debugPrint('Image processing failed: ${error.technicalError}');
      return 'Gagal memproses gambar: ${error.userMessage}';
    }
    debugPrint('Image processing failed: $error');
    return 'Gagal memproses gambar: $error';
  }

  Future<File?> _defaultSingleFileSelector(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    return picked == null ? null : File(picked.path);
  }

  Future<List<File>?> _defaultBatchFileSelector({required bool append}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.paths.isEmpty) return null;
    return result.paths.whereType<String>().map(File.new).toList();
  }

  Future<bool> saveToGallery(String filePath) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();
      await Gal.putImage(filePath);
      return true;
    } catch (error) {
      debugPrint('Error saving to gallery: $error');
      return false;
    }
  }

  Future<bool> shareFile(String filePath, {String? text}) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: text ?? 'Diproses dengan Image Processor App');
      return true;
    } catch (error) {
      debugPrint('Error sharing file: $error');
      return false;
    }
  }

  Future<void> _loadHistory() async {
    final savedHistory = await _historyLoader();
    _history
      ..clear()
      ..addAll(savedHistory);
    _totalOriginalBytesAllTime = savedHistory.fold(
      0,
      (sum, result) => sum + result.originalSizeBytes,
    );
    _totalOutputBytesAllTime = savedHistory.fold(
      0,
      (sum, result) => sum + result.outputSizeBytes,
    );
    notifyListeners();
  }

  Future<void> _recordToHistory(ProcessedImageResult result) async {
    _history.insert(0, result);
    _totalOriginalBytesAllTime += result.originalSizeBytes;
    _totalOutputBytesAllTime += result.outputSizeBytes;
    await _historySaver(List.unmodifiable(_history));
  }
}

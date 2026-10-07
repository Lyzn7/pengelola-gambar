import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/processed_image_result.dart';

class HistoryStorageService {
  static const _fileName = 'processing_history.json';

  static Future<File> _historyFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(path.join(appDir.path, _fileName));
  }

  static Future<List<ProcessedImageResult>> load() async {
    try {
      final file = await _historyFile();
      if (!await file.exists()) return [];

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ProcessedImageResult.fromJson)
          .where((result) => File(result.outputPath).existsSync())
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ProcessedImageResult> history) async {
    final file = await _historyFile();
    await file.writeAsString(
      jsonEncode(history.map((result) => result.toJson()).toList()),
    );
  }
}

import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/processing_config.dart';

class AIRecommendation {
  final ImageOutputFormat format;
  final int quality;
  final int? width;
  final int? height;
  final String explanation;
  final int? targetSizeBytes;

  AIRecommendation({
    required this.format,
    required this.quality,
    this.width,
    this.height,
    required this.explanation,
    this.targetSizeBytes,
  });

  ProcessingConfig toProcessingConfig() {
    return ProcessingConfig(
      targetFormat: format,
      quality: quality,
      resizeWidth: width,
      resizeHeight: height,
      targetMaxSizeBytes: targetSizeBytes,
      keepAspectRatio: true,
    );
  }
}

class AIAssistantService {
  /// Mengirim prompt pengguna ke Gemini AI untuk mendapatkan rekomendasi parameter
  static Future<AIRecommendation> getRecommendation({
    required String userPrompt,
    String? apiKey,
  }) async {
    // 1. Jika API Key tidak diisi, gunakan Smart Rule Fallback (offline mode)
    if (apiKey == null || apiKey.trim().isEmpty) {
      return _generateOfflineRecommendation(userPrompt);
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey.trim(),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );

      final systemPrompt = '''
Anda adalah Asisten Pakar Pengolahan Gambar (Image Processor AI Assistant).
Tugas Anda: Analisis kebutuhan pengolahan gambar pengguna dan berikan rekomendasi parameter teknis terbaik dalam format JSON murni.

Format JSON yang HARUS Anda hasilkan:
{
  "format": "JPG", // Pilihan: "JPG" atau "PNG"
  "quality": 80, // Angka 10 - 100
  "width": 1600, // Angka integer resolusi lebar piksel, atau null jika tidak perlu di-resize
  "height": null, // Angka integer resolusi tinggi piksel, atau null
  "targetSizeBytes": 512000, // Angka batas ukuran file dalam bytes (contoh 500 KB = 512000), atau null
  "explanation": "Penjelasan singkat 1-2 kalimat mengapa setting ini direkomendasikan."
}
''';

      final response = await model.generateContent([
        Content.text('$systemPrompt\n\nKebutuhan pengguna: "$userPrompt"'),
      ]);

      final jsonText = response.text;
      if (jsonText != null && jsonText.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonText);

        ImageOutputFormat outputFormat = ImageOutputFormat.jpg;
        final fmtStr = (data['format'] as String? ?? 'JPG').toUpperCase();
        if (fmtStr == 'PNG') {
          outputFormat = ImageOutputFormat.png;
        } else {
          outputFormat = ImageOutputFormat.jpg;
        }

        return AIRecommendation(
          format: outputFormat,
          quality: (data['quality'] as num? ?? 80).toInt().clamp(10, 100),
          width: data['width'] != null ? (data['width'] as num).toInt() : null,
          height: data['height'] != null
              ? (data['height'] as num).toInt()
              : null,
          targetSizeBytes: data['targetSizeBytes'] != null
              ? (data['targetSizeBytes'] as num).toInt()
              : null,
          explanation:
              data['explanation'] as String? ??
              'Rekomendasi dioptimalkan berdasarkan kebutuhan Anda.',
        );
      }
    } catch (e) {
      // Fallback jika API error / quota limit
      return _generateOfflineRecommendation(
        userPrompt,
        errorMessage:
            'Koneksi Gemini AI mengalami kendala ($e). Menggunakan rekomendasi pintar offline.',
      );
    }

    return _generateOfflineRecommendation(userPrompt);
  }

  /// Rule-based Smart Fallback jika offline atau tanpa API Key
  static AIRecommendation _generateOfflineRecommendation(
    String prompt, {
    String? errorMessage,
  }) {
    final lower = prompt.toLowerCase();

    if (lower.contains('wa') || lower.contains('whatsapp')) {
      return AIRecommendation(
        format: ImageOutputFormat.jpg,
        quality: 80,
        width: 1600,
        explanation: errorMessage ?? 'Format JPG 1600px dengan kualitas 80% sangat pas untuk pengiriman cepat di WhatsApp tanpa mengurangi ketajaman.',
      );
    } else if (lower.contains('web') ||
        lower.contains('website') ||
        lower.contains('blog')) {
      return AIRecommendation(
        format: ImageOutputFormat.jpg,
        quality: 75,
        width: 1600,
        explanation: errorMessage ?? 'Format JPG 1600px kualitas 75% memaksimalkan kecepatan loading halaman web Anda.',
      );
    } else if (lower.contains('ig') || lower.contains('instagram')) {
      return AIRecommendation(
        format: ImageOutputFormat.jpg,
        quality: 85,
        explanation: errorMessage ?? 'Format JPG kualitas 85% mempertahankan warna cerah khas feed Instagram.',
      );
    } else if (lower.contains('tokopedia') ||
        lower.contains('shopee') ||
        lower.contains('jual') ||
        lower.contains('market')) {
      return AIRecommendation(
        format: ImageOutputFormat.jpg,
        quality: 85,
        width: 1200,
        explanation: errorMessage ?? 'Format JPG 1200px memenuhi standar foto produk di e-commerce & marketplace.',
      );
    } else if (lower.contains('kecil') ||
        lower.contains('kompres') ||
        lower.contains('hemat') ||
        lower.contains('email')) {
      return AIRecommendation(
        format: ImageOutputFormat.jpg,
        quality: 60,
        width: 1280,
        targetSizeBytes: 500 * 1024,
        explanation: errorMessage ?? 'Mengompres ke JPG 1280px kualitas 60% dengan batasan target file < 500 KB.',
      );
    }

    return AIRecommendation(
      format: ImageOutputFormat.jpg,
      quality: 80,
      width: 1600,
      explanation: errorMessage ?? 'Pengaturan seimbang JPG kualitas 80% dan lebar 1600px untuk hasil optimal.',
    );
  }
}

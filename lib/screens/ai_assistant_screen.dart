import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/image_processor_provider.dart';
import '../models/image_job.dart';
import '../models/processing_config.dart';
import '../services/ai_assistant_service.dart';
import 'single_image_workflow_screens.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _promptController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  AIRecommendation? _recommendation;

  final List<String> _samplePrompts = [
    'Saya mau upload gambar ini ke website supaya loading cepat.',
    'Optimalkan untuk pengiriman gambar di WhatsApp.',
    'Buat foto ini hemat memori di bawah 500 KB.',
    'Optimalkan foto produk untuk Tokopedia / Marketplace.',
    'Optimalkan untuk feed Instagram dengan warna tajam.',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendation(String promptText) async {
    if (promptText.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _recommendation = null;
    });

    final provider = Provider.of<ImageProcessorProvider>(
      context,
      listen: false,
    );
    final rec = await AIAssistantService.getRecommendation(
      userPrompt: promptText,
      apiKey: provider.geminiApiKey,
    );

    if (mounted) {
      setState(() {
        _recommendation = rec;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ImageProcessorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Gemini AI Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            tooltip: 'Pengaturan API Key',
            onPressed: () => _showApiKeyDialog(context, provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Card(
              color: Colors.deepPurple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.deepPurple.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.deepPurple.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.geminiApiKey.isEmpty
                            ? 'Mode AI Pintar Offline aktif. Masukkan API Key Gemini di pojok kanan atas untuk analisis online yang lebih cerdas.'
                            : 'Gemini AI Online aktif. Masukkan kebutuhan Anda dalam bahasa sehari-hari.',
                        style: TextStyle(
                          color: Colors.deepPurple.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Prompt Input Card
            Text(
              'Apa kebutuhan pengolahan foto Anda?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: "Bikin foto ini kecil di bawah 500 KB tapi jangan buram untuk diupload ke website..."',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: 12),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () => _fetchRecommendation(_promptController.text),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'MENGANALISIS...' : 'MINTA REKOMENDASI AI',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sample Prompts Chips
            Text(
              'Contoh Pertanyaan / Prompt Cepat:',
              style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _samplePrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  onPressed: () {
                    _promptController.text = prompt;
                    _fetchRecommendation(prompt);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // AI Recommendation Result Display
            if (_recommendation != null) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.deepPurple, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.deepPurple,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Rekomendasi dari Gemini AI',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _recommendation!.explanation,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const Divider(height: 24),

                      // Technical Parameter Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildParamBadge(
                            'Format',
                            _recommendation!.format.label,
                            Colors.blue,
                          ),
                          _buildParamBadge(
                            'Kualitas',
                            '${_recommendation!.quality}%',
                            Colors.orange,
                          ),
                          if (_recommendation!.width != null)
                            _buildParamBadge(
                              'Resolusi',
                              '${_recommendation!.width} px',
                              Colors.purple,
                            ),
                          if (_recommendation!.targetSizeBytes != null)
                            _buildParamBadge(
                              'Target',
                              '< 500 KB',
                              Colors.green,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Apply Recommendation Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final config = _recommendation!
                                .toProcessingConfig();
                            final operation =
                                config.cropRatio != CropAspectRatio.free ||
                                    config.rotationAngle != 0 ||
                                    config.flipHorizontal ||
                                    config.flipVertical
                                ? ImageOperation.cropTransform
                                : config.resizeWidth != null ||
                                      config.resizeHeight != null
                                ? ImageOperation.resize
                                : ImageOperation.compress;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SingleImageSelectScreen(
                                  operation: operation,
                                  config: config,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text(
                            'TERAPKAN SETTING INI & PILIH FOTO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParamBadge(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
    BuildContext context,
    ImageProcessorProvider provider,
  ) {
    _apiKeyController.text = provider.geminiApiKey;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.key, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('API Key Gemini AI'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan API Key Gemini Anda dari Google AI Studio untuk mengaktifkan analisis AI secara online.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  border: OutlineInputBorder(),
                  hintText: 'AIzaSy...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.setGeminiApiKey(_apiKeyController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API Key Gemini berhasil disimpan!'),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/processed_image_result.dart';
import '../utils/format_utils.dart';

class BeforeAfterViewer extends StatefulWidget {
  final ProcessedImageResult result;

  const BeforeAfterViewer({super.key, required this.result});

  @override
  State<BeforeAfterViewer> createState() => _BeforeAfterViewerState();
}

class _BeforeAfterViewerState extends State<BeforeAfterViewer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = widget.result;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          // Storage Saved Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.tertiaryContainer,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hemat Tempat Penyimpanan',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          FormatUtils.formatBytes(res.bytesSaved),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '-${FormatUtils.formatPercentage(res.compressionPercentage)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar Before / After
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'SEBELUM (ASLI)'),
              Tab(text: 'SESUDAH (HASIL)'),
            ],
          ),

          // Image Viewport
          SizedBox(
            height: 240,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImageStack(
                  filePath: res.originalPath,
                  sizeBytes: res.originalSizeBytes,
                  dimensions: '${res.originalWidth}×${res.originalHeight}',
                  format: 'ASLI',
                  color: Colors.blueGrey,
                ),
                _buildImageStack(
                  filePath: res.outputPath,
                  sizeBytes: res.outputSizeBytes,
                  dimensions: '${res.outputWidth}×${res.outputHeight}',
                  format: res.format.label,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStack({
    required String filePath,
    required int sizeBytes,
    required String dimensions,
    required String format,
    required Color color,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(filePath),
          fit: BoxFit.contain,
          cacheWidth: 1200,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Text('Gagal memuat pratinjau gambar'));
          },
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.crop_original_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dimensions,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${FormatUtils.formatBytes(sizeBytes)} • $format',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

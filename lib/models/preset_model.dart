import 'package:flutter/material.dart';

import 'processing_config.dart';

class PresetModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final ProcessingConfig config;

  const PresetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.config,
  });

  static List<PresetModel> get defaultPresets => [
    PresetModel(
      id: 'whatsapp',
      name: 'WhatsApp',
      description: 'Dioptimalkan untuk pengiriman gambar cepat dan hemat kuota di WhatsApp',
      icon: Icons.chat_bubble_outline_rounded,
      color: const Color(0xFF25D366),
      config: ProcessingConfig(
        targetFormat: ImageOutputFormat.jpg,
        resizeWidth: 1600,
        quality: 80,
        keepAspectRatio: true,
      ),
    ),
    PresetModel(
      id: 'website',
      name: 'Website / Blog',
      description: 'Format JPG ringan untuk loading web cepat tanpa mengorbankan ketajaman',
      icon: Icons.language_rounded,
      color: const Color(0xFF0288D1),
      config: ProcessingConfig(
        targetFormat: ImageOutputFormat.jpg,
        resizeWidth: 1600,
        quality: 75,
        keepAspectRatio: true,
      ),
    ),
    PresetModel(
      id: 'instagram',
      name: 'Instagram Post',
      description:
          'Format JPG kualitas tinggi dengan rasio 1:1 persegi untuk feed',
      icon: Icons.camera_alt_outlined,
      color: const Color(0xFFE1306C),
      config: ProcessingConfig(
        targetFormat: ImageOutputFormat.jpg,
        cropRatio: CropAspectRatio.square,
        quality: 85,
        keepAspectRatio: true,
      ),
    ),
    PresetModel(
      id: 'tiktok',
      name: 'TikTok / Story',
      description: 'Resolusi 1080px dengan rasio 9:16 cocok untuk foto portrait vertical',
      icon: Icons.video_library_outlined,
      color: const Color(0xFF00F2FE),
      config: ProcessingConfig(
        targetFormat: ImageOutputFormat.jpg,
        resizeWidth: 1080,
        cropRatio: CropAspectRatio.ratio9_16,
        quality: 85,
        keepAspectRatio: true,
      ),
    ),
    PresetModel(
      id: 'marketplace',
      name: 'Marketplace',
      description:
          'Standar foto produk marketplace (Tokopedia/Shopee) 1200px ratio 1:1',
      icon: Icons.storefront_outlined,
      color: const Color(0xFFFF5722),
      config: ProcessingConfig(
        targetFormat: ImageOutputFormat.jpg,
        resizeWidth: 1200,
        cropRatio: CropAspectRatio.square,
        quality: 85,
        keepAspectRatio: true,
      ),
    ),
    PresetModel(
      id: 'max_compress',
      name: 'Kompres Maksimal',
      description: 'Paling hemat memori, cocok untuk upload dokumen atau email bertarget < 500 KB',
      icon: Icons.compress_rounded,
      color: const Color(0xFF7C4DFF),
      config: ProcessingConfig(
        targetFormat: ImageOutputFormat.jpg,
        resizeWidth: 1280,
        quality: 60,
        targetMaxSizeBytes: 500 * 1024,
        keepAspectRatio: true,
      ),
    ),
  ];
}

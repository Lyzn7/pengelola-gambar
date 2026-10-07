import 'package:flutter/material.dart';

import '../models/preset_model.dart';
import '../widgets/preset_card.dart';
import 'single_image_workflow_screens.dart';

class PresetsScreen extends StatelessWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preset Platform')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: PresetModel.defaultPresets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final preset = PresetModel.defaultPresets[index];
          return PresetCard(
            preset: preset,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PresetSummaryScreen(preset: preset),
              ),
            ),
          );
        },
      ),
    );
  }
}

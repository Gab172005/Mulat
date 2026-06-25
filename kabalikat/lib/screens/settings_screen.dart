import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/student_profile.dart';
import '../services/local_model_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _key = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Language
        const Text('Language'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final l in AppLanguage.values)
              ChoiceChip(
                label: Text(l.label),
                selected: state.profile.language == l,
                onSelected: (_) => state.updateSettings(lang: l),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Grade
        const Text('Grade level'),
        const SizedBox(height: 8),
        DropdownButton<int>(
          value: state.profile.grade,
          isExpanded: true,
          items: [
            for (var g = 1; g <= 12; g++)
              DropdownMenuItem(value: g, child: Text('Grade $g'))
          ],
          onChanged: (v) => state.updateSettings(grade: v),
        ),
        const Divider(height: 40),

        // Demo: simulate offline
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Demo: simulate offline'),
          subtitle: const Text('Force cached mode without airplane mode'),
          value: !state.isOnline,
          onChanged: (v) => state.toggleDemoOffline(v),
        ),
        const Divider(height: 40),

        // Live AI key
        const Text('Live AI (optional)'),
        const SizedBox(height: 4),
        Text(
          state.hasApiKey
              ? 'API key saved — live AI active when online.'
              : 'No key set — app uses cached content only.',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Paste API key'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                state.setApiKey(_key.text.trim());
                _key.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key saved')),
                );
              },
              child: const Text('Save key'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => state.setApiKey(null),
              child: const Text('Clear'),
            ),
          ],
        ),
        const Divider(height: 40),

        // On-device AI model (Tier 2)
        const Text('On-device AI (offline)'),
        const SizedBox(height: 4),
        Text(
          '${state.localModel.modelName} · ${state.localModel.downloadSize}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _ModelStatusRow(model: state.localModel),
      ],
    );
  }
}

/// Shows the on-device model status and a download/enable control.
class _ModelStatusRow extends StatelessWidget {
  final LocalModelService model;
  const _ModelStatusRow({required this.model});

  @override
  Widget build(BuildContext context) {
    if (!model.isEnabled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Real offline AI tutor (no signal needed). Not wired into this build '
          'yet — follow ON_DEVICE_MODEL.md to drop in the flutter_gemma engine, '
          'then download the model here.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }
    switch (model.status) {
      case LocalModelStatus.unsupported:
        return const Text('This device can’t run the on-device model.',
            style: TextStyle(color: Colors.white54, fontSize: 12));
      case LocalModelStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: model.downloadProgress),
            const SizedBox(height: 6),
            Text('Downloading… ${(model.downloadProgress * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        );
      case LocalModelStatus.ready:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF3DDC97), size: 18),
            const SizedBox(width: 6),
            const Expanded(
                child: Text('Ready — works fully offline.',
                    style: TextStyle(color: Colors.white70, fontSize: 13))),
            TextButton(
                onPressed: model.remove, child: const Text('Remove')),
          ],
        );
      case LocalModelStatus.notInstalled:
        return ElevatedButton.icon(
          onPressed: model.downloadAndLoad,
          icon: const Icon(Icons.download),
          label: const Text('Download model'),
        );
    }
  }
}

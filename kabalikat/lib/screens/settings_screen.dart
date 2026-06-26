import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/student_profile.dart';
import '../services/local_model_service.dart';
import '../strings.dart';

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
    final s = S(state.isFilipino);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.settings,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Language
        Text(s.language),
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
        Text(s.gradeLevel),
        const SizedBox(height: 8),
        DropdownButton<int>(
          value: state.profile.grade,
          isExpanded: true,
          items: [
            for (var g = 1; g <= 12; g++)
              DropdownMenuItem(value: g, child: Text(s.grade(g)))
          ],
          onChanged: (v) => state.updateSettings(grade: v),
        ),
        const Divider(height: 40),

        // Demo: simulate offline
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.demoOffline),
          subtitle: Text(s.demoOfflineSub),
          value: !state.isOnline,
          onChanged: (v) => state.toggleDemoOffline(v),
        ),
        const Divider(height: 40),

        // Live AI key
        Text(s.liveAiOptional),
        const SizedBox(height: 4),
        Text(
          state.hasApiKey ? s.apiKeySaved : s.apiKeyNone,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: InputDecoration(hintText: s.pasteKey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                state.setApiKey(_key.text.trim());
                _key.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.keySavedSnack)),
                );
              },
              child: Text(s.saveKey),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => state.setApiKey(null),
              child: Text(s.clear),
            ),
          ],
        ),
        const Divider(height: 40),

        // On-device AI model (Tier 2)
        Text(s.onDeviceAI),
        const SizedBox(height: 4),
        Text(
          '${state.localModel.modelName} · ${state.localModel.downloadSize}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _ModelStatusRow(model: state.localModel, s: s),
      ],
    );
  }
}

/// Shows the on-device model status and a download/enable control.
class _ModelStatusRow extends StatelessWidget {
  final LocalModelService model;
  final S s;
  const _ModelStatusRow({required this.model, required this.s});

  @override
  Widget build(BuildContext context) {
    if (!model.isEnabled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          s.onDeviceNotWired,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }
    switch (model.status) {
      case LocalModelStatus.unsupported:
        return Text(s.modelUnsupported,
            style: const TextStyle(color: Colors.white54, fontSize: 12));
      case LocalModelStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: model.downloadProgress),
            const SizedBox(height: 6),
            Text(s.downloading((model.downloadProgress * 100).round()),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        );
      case LocalModelStatus.ready:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF3DDC97), size: 18),
            const SizedBox(width: 6),
            Expanded(
                child: Text(s.modelReady,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))),
            TextButton(onPressed: model.remove, child: Text(s.remove)),
          ],
        );
      case LocalModelStatus.notInstalled:
        return ElevatedButton.icon(
          onPressed: model.downloadAndLoad,
          icon: const Icon(Icons.download),
          label: Text(s.downloadModel),
        );
    }
  }
}

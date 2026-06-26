import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/l10n_service.dart';

import '../state/app_state.dart';
import '../models/student_profile.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _key = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  String _aiStatus(AppState state) {
    if (!state.isOnline) return 'Offline · using cached lessons';
    return state.hasApiKey
        ? 'Online · Live AI tutor'
        : 'Online · add API key for live AI';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_name.text.isEmpty) _name.text = state.profile.name;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings'.tr(context),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // AI status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Icon(state.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 18, color: state.isOnline ? kPrimary : kAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${'AI status'.tr(context)}: '
                    '${_aiStatus(state).tr(context)}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Name
        Text('Your name'.tr(context)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Juan'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                state.updateSettings(name: _name.text.trim());
                FocusScope.of(context).unfocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Name updated'.tr(context))),
                );
              },
              child: Text('Update'.tr(context)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Language
        Text('Language'.tr(context)),
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
        Text('Grade level'.tr(context)),
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
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: SwitchListTile(
            title: Text('Demo: simulate offline'.tr(context)),
            subtitle:
                Text('Force cached mode without airplane mode'.tr(context)),
            value: !state.isOnline,
            onChanged: (v) => state.toggleDemoOffline(v),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const Divider(height: 40),

        // Live AI key (cloud tier)
        Text('Live AI (optional)'.tr(context)),
        const SizedBox(height: 4),
        Text(
          state.hasApiKey
              ? 'API key saved — live AI active when online.'.tr(context)
              : 'No key set — app uses cached content only.'.tr(context),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: InputDecoration(hintText: 'Paste API key'.tr(context)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                state.setApiKey(_key.text.trim());
                _key.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API key saved'.tr(context))),
                );
              },
              child: Text('Save key'.tr(context)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => state.setApiKey(null),
              child: Text('Clear'.tr(context)),
            ),
          ],
        ),
        const Divider(height: 40),

        // On-device AI (offline tier) — informational
        Text('On-device AI (Ollama)'.tr(context)),
        const SizedBox(height: 4),
        Text(
          'Runs offline on a local Ollama server using the custom "kabalikat" model. No internet or API key needed.'
              .tr(context),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const Divider(height: 40),

        // Reset progress / clear chat (handy for demos)
        Text('Reset progress'.tr(context)),
        const SizedBox(height: 4),
        Text(
          'Clears practice mastery, review schedule, and chat history.'
              .tr(context),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await state.resetProgress();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Progress reset'.tr(context))),
                  );
                }
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text('Reset'.tr(context)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => state.clearChat(),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text('Clear chat'.tr(context)),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

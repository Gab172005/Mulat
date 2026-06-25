import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/student_profile.dart';

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
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: SwitchListTile(
            title: const Text('Demo: simulate offline'),
            subtitle: const Text('Force cached mode without airplane mode'),
            value: !state.isOnline,
            onChanged: (v) => state.toggleDemoOffline(v),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
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
      ],
    );
  }
}

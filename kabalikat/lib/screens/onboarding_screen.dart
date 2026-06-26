import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/l10n_service.dart';

import '../state/app_state.dart';
import '../models/student_profile.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  int _grade = 7;
  AppLanguage _lang = AppLanguage.taglish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [kPrimary, kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text('Kabalikat',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Your AI study buddy — kahit walang signal.'.tr(context),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              Text('Ano ang pangalan mo? / Your name'.tr(context)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Juan'),
              ),
              const SizedBox(height: 24),
              Text('Grade level'.tr(context)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _grade,
                items: [
                  for (var g = 1; g <= 12; g++)
                    DropdownMenuItem(value: g, child: Text('Grade $g'))
                ],
                onChanged: (v) => setState(() => _grade = v ?? 7),
              ),
              const SizedBox(height: 24),
              Text('Wikang gagamitin / Language'.tr(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in AppLanguage.values)
                    ChoiceChip(
                      label: Text(l.label),
                      selected: _lang == l,
                      onSelected: (_) => setState(() => _lang = l),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  context.read<AppState>().completeOnboarding(
                        _name.text.trim().isEmpty ? 'Estudyante' : _name.text.trim(),
                        _grade,
                        _lang,
                      );
                },
                child: Text('Simulan / Start'.tr(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

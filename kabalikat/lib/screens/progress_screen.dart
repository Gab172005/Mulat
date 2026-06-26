import 'package:flutter/material.dart';
import 'package:kabalikat/models/student_profile.dart';
import 'package:provider/provider.dart';
import '../services/l10n_service.dart';

import '../state/app_state.dart';
import '../theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.mastery.entries.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hi, ${state.profile.name} 👋',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Grade ${state.profile.grade} · ${state.profile.language.label}',
              style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall mastery'.tr(context)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: state.overallMastery,
                    minHeight: 12,
                    backgroundColor: kBg,
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  Text('${(state.overallMastery * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('By topic'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Text(
                'Wala pang practice. Pumunta sa Practice tab para magsimula.',
                style: TextStyle(color: Colors.white54))
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Text('${(e.value * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: e.value,
                      backgroundColor: kSurface,
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

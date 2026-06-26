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
          if (state.dueDeckTitles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: kAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${state.dueDeckTitles.length} ${'Due for review'.tr(context).toLowerCase()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('By topic'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
                'Wala pang practice. Pumunta sa Practice tab para magsimula.'
                    .tr(context),
                style: const TextStyle(color: Colors.white54))
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

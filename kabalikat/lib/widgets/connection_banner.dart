import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Small status strip showing online/offline + whether live AI is active.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final online = state.isOnline;
    final live = online && state.hasApiKey;
    final color = online ? const Color(0xFF1F7A4D) : const Color(0xFF7A3B1F);
    final label = live
        ? 'Online · Live AI tutor'
        : online
            ? 'Online · add API key for live AI'
            : 'Offline · using cached lessons';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(51),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(128)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(online ? Icons.wifi : Icons.wifi_off,
                size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

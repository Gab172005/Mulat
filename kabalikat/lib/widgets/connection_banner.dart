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
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(online ? Icons.wifi : Icons.wifi_off,
              size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

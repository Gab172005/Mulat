import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../strings.dart';
import '../widgets/connection_banner.dart';
import 'chat_screen.dart';
import 'practice_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [
    ChatScreen(),
    PracticeScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().isFilipino);
    return Scaffold(
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(child: _pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline), label: s.tabTutor),
          NavigationDestination(
              icon: const Icon(Icons.quiz_outlined), label: s.tabPractice),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined), label: s.tabProgress),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined), label: s.tabSettings),
        ],
      ),
    );
  }
}

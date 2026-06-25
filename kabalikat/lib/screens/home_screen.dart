import 'package:flutter/material.dart';

import '../widgets/connection_banner.dart';
import 'chat_screen.dart';
import 'practice_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'decks_screen.dart';

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
    DecksScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ConnectionBanner(),
            Expanded(child: _pages[_index]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Tutor'),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.library_books), label: 'Decks'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

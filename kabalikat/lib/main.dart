import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'services/storage_service.dart';
import 'theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();

  final appState = AppState(storage);
  await appState.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        // ChatController is owned by AppState but registered separately so
        // ChatScreen can call context.watch<ChatController>() without
        // rebuilding the entire widget tree on every typing keystroke.
        ChangeNotifierProvider.value(value: appState.chat),
      ],
      child: const KabalikatApp(),
    ),
  );
}

class KabalikatApp extends StatelessWidget {
  const KabalikatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kabalikat',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.profile.onboarded) {
            return const OnboardingScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}

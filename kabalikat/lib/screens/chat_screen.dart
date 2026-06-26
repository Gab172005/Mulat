import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/l10n_service.dart';

import '../state/app_state.dart';
import '../models/chat_message.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  Future<void> _send() async {
    final q = _input.text.trim();
    final state = context.read<AppState>();
    if (q.isEmpty || state.tutorThinking) return;
    _input.clear();
    _jump();
    await state.askTutor(q); // adds turn to memory + persists + calls AI
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Greeting is rendered live (never stored), so it always matches the
  /// learner's current language and name — and is never sent to the model.
  String _greeting(BuildContext context, AppState state) {
    final base = '__tutor_greeting__'.tr(context);
    final name = state.profile.name.trim();
    if (name.isEmpty) return base;
    return base
        .replaceFirst('Hi!', 'Hi, $name!')
        .replaceFirst('Kumusta!', 'Kumusta, $name!');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = <ChatMessage>[
      ChatMessage(text: _greeting(context, state), fromUser: false),
      ...state.chat,
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length + (state.tutorThinking ? 1 : 0),
            itemBuilder: (context, i) {
              if (state.tutorThinking && i == messages.length) {
                return _Bubble(
                    fromUser: false,
                    child: Text('...nag-iisip si Kabalikat'.tr(context)));
              }
              final m = messages[i];
              return _Bubble(
                fromUser: m.fromUser,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text),
                    if (m.offline)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('cached · offline'.tr(context),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white54)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask a question...'.tr(context),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: kPrimary),
                      onPressed: _send,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool fromUser;
  final Widget child;
  const _Bubble({required this.fromUser, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fromUser)
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 4),
              child: Icon(Icons.auto_awesome, color: kPrimary, size: 20),
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: fromUser ? kSurface : Colors.transparent,
                border: fromUser ? null : Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

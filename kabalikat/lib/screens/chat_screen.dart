import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/chat_message.dart';
import '../models/student_profile.dart';
import '../services/ai_service.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    final lang = context.read<AppState>().profile.language;
    final greeting = lang == AppLanguage.english
        ? 'Hi! I\'m Kabalikat. Ask me anything — Math, Science, English. '
            'Try: "Explain photosynthesis" or "How do I add fractions?"'
        : 'Kumusta! Ako si Kabalikat. Magtanong ka lang — Math, Science, English, kahit ano. '
            'Try: "Explain photosynthesis" o "Paano mag-add ng fractions?"';
    _messages.add(ChatMessage(text: greeting, fromUser: false));
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.isEmpty || _thinking) return;
    final state = context.read<AppState>();
    setState(() {
      _messages.add(ChatMessage(text: q, fromUser: true));
      _input.clear();
      _thinking = true;
    });
    _jump();

    final reply = await state.ai.tutor(q, state.profile);
    setState(() {
      _messages.add(ChatMessage(
          text: reply.text, fromUser: false, badge: _badgeFor(reply.source)));
      _thinking = false;
    });
    _jump();
  }

  String? _badgeFor(AnswerSource s) {
    switch (s) {
      case AnswerSource.cloud:
        return null;
      case AnswerSource.onDevice:
        return 'on-device AI · offline';
      case AnswerSource.cached:
        return 'cached · offline';
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_thinking ? 1 : 0),
            itemBuilder: (context, i) {
              if (_thinking && i == _messages.length) {
                return const _Bubble(
                    fromUser: false, child: Text('...nag-iisip si Kabalikat'));
              }
              final m = _messages[i];
              return _Bubble(
                fromUser: m.fromUser,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text),
                    if (m.badge != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(m.badge!,
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _send(),
                  decoration:
                      const InputDecoration(hintText: 'Magtanong ka...'),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _send,
                backgroundColor: kPrimary,
                child: const Icon(Icons.send),
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: fromUser ? kPrimary : kSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

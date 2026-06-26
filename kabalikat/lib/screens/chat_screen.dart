import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../services/chat_controller.dart';
import '../services/l10n_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(ChatController chat, AppState state) {
    final text = _input.text.trim();
    if (text.isEmpty || chat.isThinking) return;
    _input.clear();
    chat.sendMessage(text, state.profile);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // Watch ChatController for reactive rebuilds on new messages / thinking state.
    // AppState is read-only here — we only need the student profile.
    final chat = context.watch<ChatController>();
    final state = context.read<AppState>();

    // Auto-scroll when the message list grows.
    _scrollToBottom();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: chat.messages.length + (chat.isThinking ? 1 : 0),
            itemBuilder: (context, i) {
              if (chat.isThinking && i == chat.messages.length) {
                return _Bubble(
                  fromUser: false,
                  child: Text('...nag-iisip si Kabalikat'.tr(context)),
                );
              }
              final m = chat.messages[i];
              return _Bubble(
                fromUser: m.fromUser,
                child: _MessageContent(message: m),
              );
            },
          ),
        ),
        _InputBar(
          controller: _input,
          onSend: () => _send(chat, state),
          disabled: chat.isThinking,
        ),
      ],
    );
  }
}

class _MessageContent extends StatelessWidget {
  final ChatMessage message;
  const _MessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message.text),
        if (message.offline)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'cached · offline'.tr(context),
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool disabled;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !disabled,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ask a question...'.tr(context),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.send,
                    color: disabled ? Colors.grey : kPrimary,
                  ),
                  onPressed: disabled ? null : onSend,
                ),
              ),
            ),
          ),
        ],
      ),
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
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
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

class ChatMessage {
  final String text;
  final bool fromUser;
  final bool offline; // answered from cache (no connection)
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.fromUser,
    this.offline = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

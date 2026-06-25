class ChatMessage {
  final String text;
  final bool fromUser;
  final String? badge; // e.g. "on-device" / "cached · offline"; null = cloud
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.fromUser,
    this.badge,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

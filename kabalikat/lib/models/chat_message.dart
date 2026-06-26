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

  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'offline': offline,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        fromUser: j['fromUser'] as bool,
        offline: j['offline'] as bool? ?? false,
        time: DateTime.parse(j['time'] as String),
      );
}

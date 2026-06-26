class ChatMessage {
  final String text;
  final bool fromUser;
  final bool offline; // answered from cache (no connection)
  final DateTime time;
  // System messages (welcome, error banners) are displayed but excluded from
  // AI history so they cannot anchor the model to the wrong language.
  final bool isSystem;

  ChatMessage({
    required this.text,
    required this.fromUser,
    this.offline = false,
    this.isSystem = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'offline': offline,
        'isSystem': isSystem,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        fromUser: j['fromUser'] as bool,
        offline: j['offline'] as bool? ?? false,
        isSystem: j['isSystem'] as bool? ?? false,
        time: DateTime.parse(j['time'] as String),
      );
}

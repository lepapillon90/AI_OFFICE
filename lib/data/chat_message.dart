/// One message in a company's shared space chat.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  Map<String, dynamic> toBroadcastJson() => {
        'id': id,
        'userId': userId,
        'senderName': senderName,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  static ChatMessage? fromBroadcastJson(Map<String, dynamic> json) {
    try {
      return ChatMessage(
        id: json['id'] as String,
        userId: json['userId'] as String,
        senderName: json['senderName'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        senderName: row['sender_name'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

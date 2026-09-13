/// One message in a company's shared space chat.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.toUserId,
    this.toName,
    this.isNpc = false,
  });

  final String id;
  final String userId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  /// Set for a whisper (`@username ...`): only [toUserId] and the sender
  /// should see this message. Null for a normal, company-wide message.
  final String? toUserId;

  /// The whisper target's display name, kept alongside [toUserId] so the
  /// sender's own chat can show who they whispered to without a lookup.
  final String? toName;

  /// True when this message is an AI employee's reply to an `@employee
  /// command` rather than something a human typed.
  final bool isNpc;

  Map<String, dynamic> toBroadcastJson() => {
        'id': id,
        'userId': userId,
        'senderName': senderName,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'toUserId': toUserId,
        'toName': toName,
        'isNpc': isNpc,
      };

  static ChatMessage? fromBroadcastJson(Map<String, dynamic> json) {
    try {
      return ChatMessage(
        id: json['id'] as String,
        userId: json['userId'] as String,
        senderName: json['senderName'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        toUserId: json['toUserId'] as String?,
        toName: json['toName'] as String?,
        isNpc: json['isNpc'] as bool? ?? false,
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
        toUserId: row['to_user_id'] as String?,
        toName: row['to_name'] as String?,
        isNpc: row['is_npc'] as bool? ?? false,
      );
}

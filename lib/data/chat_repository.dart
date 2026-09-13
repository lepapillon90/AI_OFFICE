import 'package:ai_office/data/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and loads a company's shared space chat history.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  static const _historyLimit = 50;

  /// The most recent messages for [companyId], oldest first.
  Future<List<ChatMessage>> fetchRecentMessages(String companyId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(_historyLimit);
    return rows.map(ChatMessage.fromRow).toList().reversed.toList();
  }

  /// Saves [message] to the company's chat history.
  Future<void> sendMessage(String companyId, ChatMessage message) async {
    await _client.from('messages').insert({
      'id': message.id,
      'company_id': companyId,
      'user_id': message.userId,
      'sender_name': message.senderName,
      'body': message.body,
      'to_user_id': message.toUserId,
      'to_name': message.toName,
      'is_npc': message.isNpc,
    });
  }
}

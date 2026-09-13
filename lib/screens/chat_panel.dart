import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// A company-wide space chat panel, anchored to the bottom-right of the
/// screen. Messages are shared live with everyone in the same office via
/// [OfficeGame.sendChatMessage] / the multiplayer channel.
class ChatPanel extends StatefulWidget {
  const ChatPanel({required this.game, super.key});

  final OfficeGame game;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    widget.game.sendChatMessage(_controller.text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selfUserId = widget.game.selfUserId;
    final messages = widget.game.chatMessages.where((message) {
      final toUserId = message.toUserId;
      return toUserId == null ||
          toUserId == selfUserId ||
          message.userId == selfUserId;
    }).toList();
    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          height: 420,
          decoration: BoxDecoration(
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5DE0E6)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '공간 채팅',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: widget.game.closeChat,
                      color: Colors.white70,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 메시지가 없습니다.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isWhisper = message.toUserId != null;
                          final nameColor = message.isNpc
                              ? const Color(0xFF8BC34A)
                              : isWhisper
                                  ? const Color(0xFFCE93D8)
                                  : const Color(0xFF5DE0E6);
                          final label = message.isNpc
                              ? '${message.senderName} · AI'
                              : isWhisper
                                  ? '${message.senderName} → ${message.toName} (귓속말)'
                                  : message.senderName;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: nameColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: isWhisper
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                                Text(
                                  message.body,
                                  style: TextStyle(
                                    color: isWhisper
                                        ? Colors.white70
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '메시지 입력... (@이름으로 귓속말/AI 직원 명령)',
                          hintStyle: TextStyle(color: Colors.white38),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _send,
                      color: const Color(0xFF5DE0E6),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

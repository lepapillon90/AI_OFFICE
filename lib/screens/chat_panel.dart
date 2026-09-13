import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// A company-wide chat panel, anchored to the bottom-right of the screen,
/// split into two tabs: 공간 채팅 (public messages everyone sees) and
/// 귓속말/AI (private messages — user whispers and AI employee command
/// exchanges — visible only to the two parties involved). Messages are
/// shared live via [OfficeGame.sendChatMessage] / the multiplayer channel.
class ChatPanel extends StatefulWidget {
  const ChatPanel({required this.game, super.key});

  final OfficeGame game;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _publicScrollController = ScrollController();
  final _privateScrollController = ScrollController();
  int _tabIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    _publicScrollController.dispose();
    _privateScrollController.dispose();
    super.dispose();
  }

  void _send() {
    widget.game.sendChatMessage(_controller.text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller =
          _tabIndex == 0 ? _publicScrollController : _privateScrollController;
      if (controller.hasClients) {
        controller.jumpTo(controller.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selfUserId = widget.game.selfUserId;
    final allMessages = widget.game.chatMessages;
    final publicMessages =
        allMessages.where((m) => m.toUserId == null).toList();
    final privateMessages = allMessages
        .where((m) =>
            m.toUserId != null &&
            (m.toUserId == selfUserId || m.userId == selfUserId))
        .toList();

    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          height: 460,
          decoration: BoxDecoration(
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5DE0E6)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _TabButton(
                            label: '공간 채팅',
                            selected: _tabIndex == 0,
                            onTap: () => setState(() => _tabIndex = 0),
                          ),
                          const SizedBox(width: 6),
                          _TabButton(
                            label: '귓속말 · AI',
                            selected: _tabIndex == 1,
                            onTap: () => setState(() => _tabIndex = 1),
                          ),
                        ],
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
              const Divider(color: Colors.white24, height: 12),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _MessageList(
                      messages: publicMessages,
                      scrollController: _publicScrollController,
                      emptyText: '아직 메시지가 없습니다.',
                    ),
                    _MessageList(
                      messages: privateMessages,
                      scrollController: _privateScrollController,
                      emptyText: '귓속말이나 AI 직원과 나눈 대화가 없습니다.',
                    ),
                  ],
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF5DE0E6) : Colors.white54,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.emptyText,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      controller: scrollController,
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
                  fontStyle: isWhisper ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              Text(
                message.body,
                style: TextStyle(
                  color: isWhisper ? Colors.white70 : Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

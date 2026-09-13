import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// A company-wide chat panel, anchored to the bottom-right of the screen,
/// split into two tabs: 공간 채팅 (public messages everyone sees) and
/// 귓속말 · AI (private messages — user whispers and AI employee command
/// exchanges). The private tab is further split into per-partner rooms,
/// KakaoTalk-style — one for each other user you've whispered with, and
/// one for each AI employee you've sent a command to. Messages are shared
/// live via [OfficeGame.sendChatMessage] / the multiplayer channel.
class ChatPanel extends StatefulWidget {
  const ChatPanel({required this.game, super.key});

  final OfficeGame game;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

/// One private conversation, identified by [key] (`user:<id>` or
/// `npc:<name>`) so a whisper thread and an AI employee thread never
/// collide even if a username happened to match an employee's name.
class _PrivateRoom {
  _PrivateRoom({required this.key, required this.name, required this.isNpc});

  final String key;
  final String name;
  final bool isNpc;
  ChatMessage? lastMessage;
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode(debugLabel: 'ChatPanel input');
  final _publicScrollController = ScrollController();
  final _roomScrollController = ScrollController();
  int _tabIndex = 0;
  String? _selectedRoomKey;
  String? _selectedRoomName;

  @override
  void initState() {
    super.initState();
    final pendingPeer = widget.game.pendingChatPeerName;
    if (pendingPeer != null) {
      widget.game.consumePendingChatPeer();
      _tabIndex = 1;
      _selectedRoomKey = 'npc:$pendingPeer';
      _selectedRoomName = pendingPeer;
    }
    // Explicit request (rather than TextField's own `autofocus`) so this
    // reliably wins even if OfficeScreen's game-focus-reclaim callback is
    // scheduled in the same frame this panel first mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _publicScrollController.dispose();
    _roomScrollController.dispose();
    super.dispose();
  }

  /// Which private room [message] belongs to, from the current user's
  /// point of view — grouping by the *other* party regardless of which of
  /// us sent which message in the exchange.
  ({String key, String name, bool isNpc}) _roomOf(
    ChatMessage message,
    String selfUserId,
  ) {
    if (message.isNpc) {
      return (
        key: 'npc:${message.senderName}',
        name: message.senderName,
        isNpc: true
      );
    }
    if (message.userId == selfUserId) {
      if (message.toUserId == selfUserId) {
        // My own command to an NPC (self-directed placeholder toUserId).
        final name = message.toName ?? '?';
        return (key: 'npc:$name', name: name, isNpc: true);
      }
      final name = message.toName ?? '?';
      return (key: 'user:${message.toUserId}', name: name, isNpc: false);
    }
    return (
      key: 'user:${message.userId}',
      name: message.senderName,
      isNpc: false
    );
  }

  void _send() {
    var text = _controller.text;
    final roomName = _selectedRoomName;
    if (roomName != null && !text.trimLeft().startsWith('@')) {
      text = '@$roomName $text';
    }
    widget.game.sendChatMessage(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller =
          _tabIndex == 0 ? _publicScrollController : _roomScrollController;
      if (controller.hasClients) {
        controller.jumpTo(controller.position.maxScrollExtent);
      }
    });
  }

  /// The TextField's Enter/submit handler: sends if there's something to
  /// send, otherwise treats an empty Enter as "close the chat" — pairs
  /// with OfficeGame.handleInteractionKey opening it on Enter when closed.
  void _onSubmitted(String value) {
    if (value.trim().isEmpty) {
      widget.game.closeChat();
      return;
    }
    _send();
  }

  /// Switches between 공간 채팅 and 귓속말 · AI. The input's text and focus
  /// both carry over — the same TextField/controller is shared by both
  /// tabs (only the message list above it swaps), so there's nothing to
  /// explicitly preserve; this just makes sure the tab button click itself
  /// (which briefly focuses the button's own InkWell) doesn't leave the
  /// input feeling like it lost focus.
  void _switchTab(int index) {
    setState(() => _tabIndex = index);
    _inputFocusNode.requestFocus();
  }

  void _openRoom(String key, String name) {
    setState(() {
      _selectedRoomKey = key;
      _selectedRoomName = name;
    });
    _inputFocusNode.requestFocus();
  }

  void _backToRoomList() {
    setState(() {
      _selectedRoomKey = null;
      _selectedRoomName = null;
    });
    _inputFocusNode.requestFocus();
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

    final rooms = <String, _PrivateRoom>{};
    for (final message in privateMessages) {
      final info = _roomOf(message, selfUserId);
      final room = rooms.putIfAbsent(
        info.key,
        () => _PrivateRoom(key: info.key, name: info.name, isNpc: info.isNpc),
      );
      final last = room.lastMessage;
      if (last == null || message.createdAt.isAfter(last.createdAt)) {
        room.lastMessage = message;
      }
    }
    final roomList = rooms.values.toList()
      ..sort((a, b) =>
          b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt));

    final selectedRoomMessages = _selectedRoomKey == null
        ? const <ChatMessage>[]
        : privateMessages
            .where((m) => _roomOf(m, selfUserId).key == _selectedRoomKey)
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
              _buildHeader(),
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
                    _selectedRoomKey == null
                        ? _RoomList(
                            rooms: roomList,
                            onTap: (room) => _openRoom(room.key, room.name),
                          )
                        : _MessageList(
                            messages: selectedRoomMessages,
                            scrollController: _roomScrollController,
                            emptyText: '아직 나눈 대화가 없습니다.',
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
                        focusNode: _inputFocusNode,
                        style: const TextStyle(color: Colors.white),
                        // A UX nicety, not the real limit — the ask-employee
                        // Edge Function truncates independently server-side
                        // (docs/PHASE7_OPS_REVIEW.md), since a raw API call
                        // could otherwise ignore whatever the client sends.
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: _selectedRoomName != null
                              ? '$_selectedRoomName에게 메시지 보내기...'
                              : '메시지 입력... (@이름으로 귓속말/AI 직원 명령)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: _onSubmitted,
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

  Widget _buildHeader() {
    if (_tabIndex == 1 && _selectedRoomKey != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: '목록으로',
              onPressed: _backToRoomList,
              color: Colors.white70,
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            Expanded(
              child: Text(
                _selectedRoomName ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
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
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _TabButton(
                  label: '공간 채팅',
                  selected: _tabIndex == 0,
                  onTap: () => _switchTab(0),
                ),
                const SizedBox(width: 6),
                _TabButton(
                  label: '귓속말 · AI',
                  selected: _tabIndex == 1,
                  onTap: () => _switchTab(1),
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

class _RoomList extends StatelessWidget {
  const _RoomList({required this.rooms, required this.onTap});

  final List<_PrivateRoom> rooms;
  final void Function(_PrivateRoom room) onTap;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(
        child: Text(
          '귓속말이나 AI 직원과 나눈 대화가 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: rooms.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Colors.white12, height: 1),
        itemBuilder: (context, index) {
          final room = rooms[index];
          final last = room.lastMessage!;
          return ListTile(
            onTap: () => onTap(room),
            leading: CircleAvatar(
              backgroundColor: room.isNpc
                  ? const Color(0xFF8BC34A)
                  : const Color(0xFFCE93D8),
              child: Text(
                room.name.isNotEmpty ? room.name.substring(0, 1) : '?',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.isNpc) ...[
                  const SizedBox(width: 4),
                  const Text(
                    '· AI',
                    style: TextStyle(color: Color(0xFF8BC34A), fontSize: 12),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              last.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54),
            ),
          );
        },
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

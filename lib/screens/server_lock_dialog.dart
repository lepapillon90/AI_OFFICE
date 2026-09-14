import 'dart:async';

import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// The server machine's password prompt (2F, [ServerMachineInteraction]) —
/// a game-world flavor gate on `@서버` remote commands specifically, layered
/// on top of the real security boundary (the command whitelist and
/// per-employee opt-in — see docs/PHASE8_REMOTE_AGENT.md), not a
/// replacement for it.
///
/// Once unlocked, also shows the server's "실행"/"종료" power switch — the
/// local agent may already be running in the background the whole time
/// (e.g. via a Windows scheduled task), but only actually processes
/// commands while this is on.
class ServerLockDialog extends StatefulWidget {
  const ServerLockDialog({required this.game, required this.onClose, super.key});

  final OfficeGame game;
  final VoidCallback onClose;

  @override
  State<ServerLockDialog> createState() => _ServerLockDialogState();
}

class _ServerLockDialogState extends State<ServerLockDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _status;
  bool _statusIsError = false;

  bool? _running;
  bool _runningLoading = false;
  bool _runningToggling = false;

  @override
  void initState() {
    super.initState();
    if (widget.game.isServerUnlocked) {
      _loadRunning();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRunning() async {
    setState(() => _runningLoading = true);
    final running = await widget.game.fetchServerRunning();
    if (!mounted) {
      return;
    }
    setState(() {
      _running = running;
      _runningLoading = false;
    });
  }

  Future<void> _toggleRunning() async {
    final next = !(_running ?? false);
    setState(() {
      _runningToggling = true;
      _status = null;
    });
    final result = await widget.game.updateServerRunning(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _runningToggling = false;
      _running = next;
      _status = result;
      _statusIsError = false;
    });
  }

  Future<void> _submit() async {
    final attempt = _controller.text;
    if (attempt.isEmpty || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _status = null;
    });
    final result = await widget.game.submitServerPassword(attempt);
    if (!mounted) {
      return;
    }
    final unlocked = widget.game.isServerUnlocked;
    setState(() {
      _submitting = false;
      _status = result;
      _statusIsError = !unlocked;
    });
    if (unlocked) {
      _controller.clear();
      unawaited(_loadRunning());
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.game.isServerUnlocked;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5DE0E6)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.dns_outlined, color: Color(0xFF5DE0E6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unlocked ? '서버기계' : '서버 잠금 해제',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: widget.onClose,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (unlocked) ..._buildPowerSwitch() else ..._buildPasswordForm(),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(
                  _status!,
                  style: TextStyle(
                    color: _statusIsError
                        ? const Color(0xFFF44336)
                        : const Color(0xFF66BB6A),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPasswordForm() => [
        const Text(
          '비밀번호를 맞추면 이 세션 동안 "@서버 ..." 원격 명령을 보낼 수 있게 됩니다.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          obscureText: true,
          enabled: !_submitting,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '비밀번호',
            hintStyle: TextStyle(color: Colors.white38),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('확인'),
          ),
        ),
      ];

  List<Widget> _buildPowerSwitch() {
    final running = _running ?? false;
    return [
      Text(
        '잠금이 해제되어 있습니다 — "@서버 ..." 명령을 보낼 수 있어요.',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 4),
      const Text(
        '단, 실제로 명령이 처리되려면 아래 서버가 "실행" 상태여야 합니다 — 꺼져 있으면 명령을 보내도 '
        '바로 실패로 안내돼요.',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E161D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: _runningLoading
                  ? Colors.white24
                  : (running ? const Color(0xFF66BB6A) : const Color(0xFFF44336)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _runningLoading
                    ? '상태 확인 중...'
                    : (running ? '서버 실행 중' : '서버 정지됨'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            SizedBox(
              height: 32,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      running ? const Color(0xFFF44336) : const Color(0xFF66BB6A),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed:
                    (_runningLoading || _runningToggling) ? null : _toggleRunning,
                child: _runningToggling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(running ? '서버 종료' : '서버 실행'),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

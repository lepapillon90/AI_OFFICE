import 'dart:async';

import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// The meeting room's panel: pick participants and start a meeting, or —
/// while one is running — see who's in it and how long it's gone, with a
/// button to end it. Opened via `[E]` near [MeetingRoomInteraction].
class MeetingPanel extends StatefulWidget {
  const MeetingPanel({required this.game, required this.onClose, super.key});

  final OfficeGame game;
  final VoidCallback onClose;

  @override
  State<MeetingPanel> createState() => _MeetingPanelState();
}

class _MeetingPanelState extends State<MeetingPanel> {
  final Set<String> _selectedIds = {};
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    if (widget.game.isMeetingActive && _ticker == null) {
      // Just for the "N분 진행 중" label — doesn't need to be exact to the
      // second, so a light interval is enough.
      _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startMeeting() {
    final participants = widget.game.employees
        .where((e) => _selectedIds.contains(e.id))
        .toList();
    widget.game.startMeeting(participants);
    setState(_startTickerIfNeeded);
  }

  void _endMeeting() {
    widget.game.endMeeting();
    _ticker?.cancel();
    _ticker = null;
    setState(_selectedIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 480),
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
                  const Expanded(
                    child: Text(
                      '회의실',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
              const SizedBox(height: 8),
              Flexible(
                child: game.isMeetingActive
                    ? _ActiveMeeting(game: game, onEnd: _endMeeting)
                    : _StartMeetingForm(
                        game: game,
                        selectedIds: _selectedIds,
                        onToggle: (id, selected) => setState(() {
                          if (selected) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        }),
                        onStart: _startMeeting,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartMeetingForm extends StatelessWidget {
  const _StartMeetingForm({
    required this.game,
    required this.selectedIds,
    required this.onToggle,
    required this.onStart,
  });

  final OfficeGame game;
  final Set<String> selectedIds;
  final void Function(String employeeId, bool selected) onToggle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('참석자 선택', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final employee in game.employees)
                  CheckboxListTile(
                    dense: true,
                    activeColor: const Color(0xFF5DE0E6),
                    checkColor: const Color(0xFF17212B),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selectedIds.contains(employee.id),
                    onChanged: (value) => onToggle(employee.id, value ?? false),
                    title: Text(
                      '${employee.name} · ${employee.role}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedIds.isEmpty ? null : onStart,
              child: const Text('회의 시작'),
            ),
          ),
        ],
      );
}

class _ActiveMeeting extends StatelessWidget {
  const _ActiveMeeting({required this.game, required this.onEnd});

  final OfficeGame game;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final startedAt = game.meetingStartedAt!;
    final minutes = DateTime.now().difference(startedAt).inMinutes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '진행 중 · $minutes분',
          style: const TextStyle(
            color: Color(0xFF5DE0E6),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text('참석자', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final AiEmployee employee in game.meetingParticipants)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${employee.name} · ${employee.role}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: onEnd, child: const Text('회의 종료')),
        ),
      ],
    );
  }
}

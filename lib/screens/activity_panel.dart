import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// Shows the company's recent activity (roster edits, AI command results,
/// ...) — opened from the office screen's "알림" bell, which also clears
/// its unread badge on open.
class ActivityPanel extends StatelessWidget {
  const ActivityPanel({required this.game, required this.onClose, super.key});

  final OfficeGame game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final events = game.activityLog;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
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
                      '활동 기록',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: onClose,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: events.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '아직 활동 기록이 없습니다.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (_, index) => _ActivityTile(event: events[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.event});

  final ActivityEvent event;

  IconData get _icon => switch (event.type) {
        ActivityType.employee => Icons.badge_outlined,
        ActivityType.aiCommand => Icons.smart_toy_outlined,
        ActivityType.member => Icons.people_outline,
        ActivityType.board => Icons.view_kanban_outlined,
        ActivityType.meeting => Icons.groups_outlined,
      };

  String get _timeLabel {
    final now = DateTime.now();
    final diff = now.difference(event.createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  /// "OOO · 방금 전" when the actor is known (the audit-log "who"), else
  /// just the time (older entries logged before actorName existed).
  String get _metaLabel {
    final actor = event.actorName;
    return actor == null ? _timeLabel : '$actor · $_timeLabel';
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 18, color: const Color(0xFF5DE0E6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.message, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  _metaLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
}

import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// Shows the company's recent activity (roster edits, AI command results,
/// ...) — opened from the office screen's "알림" bell, which also clears
/// its unread badge on open. Filterable by type and searchable by text
/// (both client-side, over the already-loaded recent history — see
/// [OfficeGame.activityLog]'s own cap).
class ActivityPanel extends StatefulWidget {
  const ActivityPanel({required this.game, required this.onClose, super.key});

  final OfficeGame game;
  final VoidCallback onClose;

  @override
  State<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<ActivityPanel> {
  final _searchController = TextEditingController();
  ActivityType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ActivityEvent> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    return widget.game.activityLog.where((event) {
      if (_typeFilter != null && event.type != _typeFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return event.message.toLowerCase().contains(query) ||
          (event.actorName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = widget.game.activityLog;
    final events = _filteredEvents;
    final isFiltered = _typeFilter != null || _searchController.text.trim().isNotEmpty;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          height: 560,
          decoration: BoxDecoration(
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5DE0E6)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
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
                    onPressed: widget.onClose,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '메시지·행위자로 검색',
                  hintStyle: const TextStyle(color: Colors.white38),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '지우기',
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () => setState(_searchController.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TypeChip(
                      label: '전체',
                      selected: _typeFilter == null,
                      onTap: () => setState(() => _typeFilter = null),
                    ),
                    for (final type in ActivityType.values) ...[
                      const SizedBox(width: 6),
                      _TypeChip(
                        label: type.displayLabel,
                        selected: _typeFilter == type,
                        onTap: () => setState(() => _typeFilter = type),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: allEvents.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 활동 기록이 없습니다.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : events.isEmpty
                        ? const Center(
                            child: Text(
                              '조건에 맞는 활동 기록이 없습니다.',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (_, index) => _ActivityTile(event: events[index]),
                          ),
              ),
              if (isFiltered) ...[
                const SizedBox(height: 4),
                Text(
                  '최근 ${allEvents.length}건 중 ${events.length}건 표시',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF5DE0E6) : const Color(0xFF23303C),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
}

/// A label for each [ActivityType], used by the filter chips — separate
/// from [ActivityTypeName] (the wire-format `name`, e.g. `'ai_command'`),
/// which isn't meant for display.
extension _ActivityTypeDisplayLabel on ActivityType {
  String get displayLabel => switch (this) {
        ActivityType.employee => '직원',
        ActivityType.aiCommand => 'AI 명령',
        ActivityType.member => '구성원',
        ActivityType.board => '보드',
        ActivityType.meeting => '회의',
      };
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

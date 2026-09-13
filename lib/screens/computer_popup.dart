import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// A workstation's AI employee: status at a glance, "대화하기" to open a
/// chat with them (same `@employee` pipeline as the space chat), and
/// "작업 확인" to see their most recent reply without leaving the popup.
class ComputerPopup extends StatelessWidget {
  const ComputerPopup({
    required this.employee,
    required this.game,
    required this.onClose,
    super.key,
  });

  final AiEmployee employee;
  final OfficeGame game;
  final VoidCallback onClose;

  void _showLastReply(BuildContext context) {
    final reply = game.lastReplyFrom(employee);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${employee.name}의 최근 작업'),
        content: Text(
          reply?.body ?? '아직 대화한 내역이 없습니다. "대화하기"로 업무를 지시해보세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF17212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5DE0E6)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
                Text(
                  employee.role,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  employee.displayStatus,
                  style: TextStyle(
                    color: employee.status.displayColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '업무 지시',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => game.openChatWithEmployee(employee),
                        child: const Text('대화하기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showLastReply(context),
                        child: const Text('작업 확인'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

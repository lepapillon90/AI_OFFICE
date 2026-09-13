import 'package:flutter/material.dart';

/// Local-only demonstration controls for the development AI workstation.
class ComputerPopup extends StatelessWidget {
  const ComputerPopup({required this.onClose, super.key});

  final VoidCallback onClose;

  void _showUnavailableMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('데모 기능은 현재 준비 중입니다.')),
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
                    const Expanded(
                      child: Text(
                        '개발 AI',
                        style: TextStyle(
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
                const SizedBox(height: 8),
                const Text(
                  '대기 중',
                  style: TextStyle(color: Color(0xFF81F495)),
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
                        onPressed: () => _showUnavailableMessage(context),
                        child: const Text('대화하기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showUnavailableMessage(context),
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

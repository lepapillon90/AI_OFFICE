import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// Floor-select popup opened by using the elevator.
class ElevatorPopup extends StatelessWidget {
  const ElevatorPopup({required this.game, super.key});

  final OfficeGame game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
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
                      '층 선택',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: game.closeElevatorPopup,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final floor in FloorInfo.ordered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: floor == game.currentFloor
                            ? const Color(0xFF5DE0E6).withValues(alpha: 0.15)
                            : null,
                      ),
                      onPressed: () => game.changeFloor(floor),
                      child: Row(
                        children: [
                          Text(
                            '${floor.level}층',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Text(floor.displayName),
                          if (floor == game.currentFloor) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

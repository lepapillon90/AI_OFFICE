import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _testEmployee = AiEmployee(
  id: 'ai-test',
  name: '테스트 직원',
  role: '개발자',
  provider: 'anthropic',
  workstationId: 'desk-1',
  status: NpcStatus.idle,
);

void main() {
  test('marks a player near only inside the computer interaction radius', () {
    final interaction = ComputerInteraction(
      position: Vector2(400, 350),
      employee: _testEmployee,
    );

    expect(interaction.isPlayerNearby(Vector2(430, 350)), isTrue);
    expect(interaction.isPlayerNearby(Vector2(600, 350)), isFalse);
  });

  test('E opens and escape closes the computer popup', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));

    game.handleInteractionKey(LogicalKeyboardKey.keyE);
    expect(game.isComputerPopupOpen, isTrue);
    game.handleInteractionKey(LogicalKeyboardKey.escape);
    expect(game.isComputerPopupOpen, isFalse);
  });

  test('blocks player movement while the computer popup is open', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(400, 420));

    game.handleInteractionKey(LogicalKeyboardKey.keyE);
    game.player.tryMove(Vector2(10, 0));

    expect(game.player.position, Vector2(400, 420));
  });
}

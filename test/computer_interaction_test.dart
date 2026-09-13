import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks a player near only inside the computer interaction radius', () {
    final interaction = ComputerInteraction(position: Vector2(400, 350));

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

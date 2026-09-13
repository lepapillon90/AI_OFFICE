import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts on the workspace floor', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));

    expect(game.currentFloor, Floor.workspace);
  });

  test('E near the elevator opens the elevator popup', () {
    final game = OfficeGame.forTest(
      playerPosition: FloorLayouts.elevatorPosition.clone(),
    );

    expect(game.isElevatorNearby, isTrue);
    game.handleInteractionKey(LogicalKeyboardKey.keyE);
    expect(game.isElevatorPopupOpen, isTrue);
  });

  testWidgets('changeFloor switches floors, repositions the player, and '
      'clears workspace-only state', (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();
    expect(game.isComputerNearby, isTrue);

    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    await tester.pump();

    expect(game.currentFloor, Floor.lobby);
    expect(game.player.position, FloorLayouts.lobby.arrivalPosition);
    expect(game.isComputerNearby, isFalse);

    game.openElevatorPopup();
    expect(game.isElevatorPopupOpen, isTrue);

    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    await tester.pump();

    expect(game.currentFloor, Floor.lobby, reason: 'no-op when already there');
    expect(game.isElevatorPopupOpen, isFalse, reason: 'popup still closes');
  });
}

import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lobby registry uses the isometric lobby layout', () {
    expect(
      FloorLayouts.lobby.worldSize,
      IsoLobbyLayout.floorLayout.worldSize,
    );
    expect(
      FloorLayouts.lobby.elevatorPosition,
      IsoLobbyLayout.floorLayout.elevatorPosition,
    );
  });

  test('lobby elevator arrival is walkable for the player hitbox', () {
    final arrival = FloorLayouts.lobby.arrivalPosition;
    final hitbox = Rect.fromCenter(
      center: Offset(arrival.x, arrival.y),
      width: OfficeLayout.characterSize.x,
      height: OfficeLayout.characterSize.y,
    );

    expect(FloorLayouts.lobby.blockers, isNot(contains(predicate((Rect blocker) => blocker.overlaps(hitbox)))));
  });

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

  testWidgets(
      'changeFloor switches floors, repositions the player, and '
      'clears workspace-only state', (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();
    expect(game.isComputerNearby, isTrue);

    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    await tester.pump();

    expect(game.currentFloor, Floor.lobby);
    expect(game.player.position, FloorLayouts.lobby.arrivalPosition);
    expect(game.elevator.position, FloorLayouts.lobby.elevatorPosition);
    expect(game.isElevatorNearby, isTrue);
    expect(game.isComputerNearby, isFalse);
    expect(
      game.player.priority,
      IsoProjection.priorityFor(game.player.position),
    );
    expect(
      game.elevator.priority,
      IsoProjection.priorityFor(game.elevator.position),
    );
    expect(
      game.world.children.whereType<IsoFloorTilesComponent>(),
      hasLength(1),
    );
    expect(game.world.children.whereType<NpcComponent>(), isEmpty);

    game.openElevatorPopup();
    expect(game.isElevatorPopupOpen, isTrue);

    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    await tester.pump();

    expect(game.currentFloor, Floor.lobby, reason: 'no-op when already there');
    expect(game.isElevatorPopupOpen, isFalse, reason: 'popup still closes');

    await tester.runAsync(() => game.changeFloor(Floor.workspace));
    await tester.pump();

    expect(game.currentFloor, Floor.workspace);
    expect(game.player.position, FloorLayouts.workspace.arrivalPosition);
    expect(game.elevator.position, FloorLayouts.workspace.elevatorPosition);
    expect(game.isElevatorNearby, isTrue);
    expect(game.isComputerNearby, isFalse);
    expect(game.world.children.whereType<IsoFloorTilesComponent>(), isEmpty);
    expect(game.world.children.whereType<NpcComponent>(), isNotEmpty);
  });
}

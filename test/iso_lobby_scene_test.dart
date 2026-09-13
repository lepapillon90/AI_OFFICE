import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a sprite component for every lobby placement', () {
    final components = IsoLobbyScene().createComponents();

    expect(components, hasLength(IsoLobbyLayout.placements.length));
  });

  test('maps every lobby placement to its configured sprite component', () {
    final components = IsoLobbyScene().createComponents();

    expect(
      components.first.placement.assetPath,
      IsoLobbyLayout.placements.first.assetPath,
    );
    expect(
      components.last.placement.assetPath,
      IsoLobbyLayout.placements.last.assetPath,
    );

    for (var index = 0; index < components.length; index++) {
      final component = components[index];
      final placement = IsoLobbyLayout.placements[index];

      expect(component.position, placement.worldFootPoint);
      expect(component.size, placement.screenSize);
      expect(component.anchor, Anchor.bottomCenter);
      expect(
        component.priority,
        IsoProjection.priorityFor(
          placement.worldFootPoint,
          layerOffset: placement.layerOffset,
        ),
      );
    }
  });

  test('player and NPC accept dynamic render priorities', () {
    final player = OfficePlayer.forTest(position: Vector2(100, 100));
    final npc = NpcComponent(
      employee: const AiEmployee(
        id: 'npc-1',
        name: 'Test NPC',
        role: 'Developer',
        provider: 'test',
        workstationId: 'desk-1',
        status: NpcStatus.working,
      ),
      position: Vector2(200, 200),
    );

    player.setRenderPriority(320);
    npc.setRenderPriority(640);

    expect(player.priority, 320);
    expect(npc.priority, 640);
  });
}

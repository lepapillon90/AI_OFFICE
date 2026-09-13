import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
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

  test('maps lobby assets to depth-sorted sprite components', () {
    final components = IsoLobbyScene().createComponents();
    final byAsset = {
      for (final component in components) component.placement.assetPath: component,
    };

    final ground = byAsset['office_1f/isometric/lobby_ground.png']!;
    final reception = byAsset['office_1f/isometric/reception.png']!;
    final planters = byAsset['office_1f/isometric/planters.png']!;
    final foreground = byAsset['office_1f/isometric/foreground.png']!;

    expect(ground.priority, lessThan(reception.priority));
    expect(foreground.priority, greaterThan(planters.priority));
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

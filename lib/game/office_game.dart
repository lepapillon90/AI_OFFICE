import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:ai_office/game/npc/workstation.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';

/// The interactive office world and its camera configuration.
class OfficeGame extends FlameGame
    with HasKeyboardHandlerComponents, ScrollDetector {
  late final OfficePlayer player;

  static const _minZoom = 0.5;
  static const _maxZoom = 2.5;
  static const _zoomStep = 0.1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    player = OfficePlayer();
    await world.addAll([OfficeMap(), player, ..._buildNpcs()]);
    camera.setBounds(
      Rectangle.fromLTWH(
        0,
        0,
        OfficeLayout.worldSize.x,
        OfficeLayout.worldSize.y,
      ),
      considerViewport: true,
    );
    camera.follow(player, snap: true);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final direction = info.scrollDelta.global.y.sign;
    final zoom = camera.viewfinder.zoom - direction * _zoomStep;
    camera.viewfinder.zoom = zoom.clamp(_minZoom, _maxZoom);
  }

  List<NpcComponent> _buildNpcs() {
    final workstationsById = {for (final w in Workstation.all) w.id: w};
    return sampleEmployees
        .map((employee) => NpcComponent(
              employee: employee,
              position: workstationsById[employee.workstationId]!
                  .seatPosition,
            ))
        .toList();
  }
}

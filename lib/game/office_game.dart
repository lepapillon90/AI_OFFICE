import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';

/// The interactive office world and its camera configuration.
class OfficeGame extends FlameGame with HasKeyboardHandlerComponents {
  late final OfficePlayer player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    player = OfficePlayer();
    await world.addAll([OfficeMap(), player]);
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
}

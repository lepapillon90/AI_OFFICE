import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:flame/components.dart';

/// Builds the visual layers for the isometric lobby world.
///
/// The current foundation intentionally mounts only the batched floor tiles.
class IsoLobbyScene {
  List<Component> createComponents() => [
        IsoFloorTilesComponent(IsoLobbyLayout.placements),
      ];
}

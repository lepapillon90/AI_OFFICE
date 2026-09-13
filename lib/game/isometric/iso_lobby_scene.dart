import 'package:ai_office/game/isometric/first_floor_asset_component.dart';
import 'package:ai_office/game/isometric/first_floor_asset_layout.dart';
import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:flame/components.dart';

/// Builds the visual layers for the isometric lobby world.
///
/// Both layers reuse sprites so repeated tiles and furniture load once.
class IsoLobbyScene {
  List<Component> createComponents() => [
        IsoFloorTilesComponent(IsoLobbyLayout.placements),
        FirstFloorAssetComponent(FirstFloorAssetLayout.placements),
      ];
}

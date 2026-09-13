import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';

/// Builds the visual layers for the isometric lobby world.
///
/// Floor tiles (the `office_1f/v3/floor/` placements) are batched into one
/// [IsoFloorTilesComponent] rather than mounted individually — see that
/// class's doc comment for why. Everything else (reception, cafe, store,
/// lounge, planters, foreground) still gets its own [IsoLobbySpriteComponent]
/// since those need individual depth-sorting against the player/NPCs.
class IsoLobbyScene {
  List<Component> createComponents() {
    final floorPlacements = <IsoLobbyPlacement>[];
    final overlayPlacements = <IsoLobbyPlacement>[];
    for (final placement in IsoLobbyLayout.placements) {
      if (placement.assetPath.startsWith('office_1f/v3/floor/')) {
        floorPlacements.add(placement);
      } else {
        overlayPlacements.add(placement);
      }
    }
    return [
      IsoFloorTilesComponent(floorPlacements),
      ...overlayPlacements.map(IsoLobbySpriteComponent.new),
    ];
  }
}

/// A lobby artwork layer positioned and depth-sorted by its foot point.
class IsoLobbySpriteComponent extends SpriteComponent {
  IsoLobbySpriteComponent(this.placement)
      : super(
          position: placement.worldFootPoint.clone(),
          size: placement.screenSize.clone(),
          anchor: Anchor.bottomCenter,
          priority: IsoProjection.priorityFor(
            placement.worldFootPoint,
            layerOffset: placement.layerOffset,
          ),
        );

  final IsoLobbyPlacement placement;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(placement.assetPath);
  }
}

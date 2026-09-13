import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';

/// Builds the visual layers for the isometric lobby world.
class IsoLobbyScene {
  List<IsoLobbySpriteComponent> createComponents() => IsoLobbyLayout.placements
      .map(IsoLobbySpriteComponent.new)
      .toList();
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

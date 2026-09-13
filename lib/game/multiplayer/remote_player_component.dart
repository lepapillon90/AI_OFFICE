import 'package:ai_office/data/remote_player_state.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/name_tag_component.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders another signed-in user's character: their position, name, role,
/// and status, kept in sync with [RemotePlayerState] updates. Not
/// interactive — this user's own client drives their movement.
class RemotePlayerComponent extends SpriteComponent {
  RemotePlayerComponent({required RemotePlayerState state})
      : _state = state,
        super(
          position: Vector2(state.x, state.y),
          size: OfficeLayout.characterSize.clone(),
          anchor: Anchor.center,
        );

  RemotePlayerState _state;
  late final NameTagComponent _nameTag;

  int get floorLevel => _state.floorLevel;
  RemotePlayerState get state => _state;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(
      'characters/office_worker.png',
      srcSize: Vector2.all(64),
    );

    _nameTag = NameTagComponent(
      badgeLabel: _state.statusLabel,
      badgeColor: Color(_state.statusColorValue),
      name: _state.name,
      role: _state.role,
      characterWidth: size.x,
    );
    await add(_nameTag);
  }

  /// Updates position and profile display from a newer broadcast state.
  void applyState(RemotePlayerState state) {
    _state = state;
    position = Vector2(state.x, state.y);
    if (isLoaded) {
      _nameTag.applyChanges(
        badgeLabel: state.statusLabel,
        badgeColor: Color(state.statusColorValue),
        name: state.name,
        role: state.role,
      );
    }
  }
}

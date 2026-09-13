import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/name_tag_component.dart';
import 'package:ai_office/game/player/player_profile.dart';
import 'package:ai_office/game/player/player_status.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

typedef PositionChanged = void Function(Vector2 position);

/// A keyboard-controlled office worker that remains inside the walkable map.
class OfficePlayer extends SpriteComponent with KeyboardHandler {
  OfficePlayer({
    Vector2? position,
    this.onPositionChanged,
    PlayerProfile profile = PlayerProfile.initial,
  })  : _profile = profile,
        super(
          position: position ?? OfficeLayout.worldSize.clone() / 2,
          size: _hitboxSize.clone(),
          anchor: Anchor.center,
        );

  OfficePlayer.forTest({
    required Vector2 position,
    PositionChanged? onPositionChanged,
  }) : this(position: position, onPositionChanged: onPositionChanged);

  final PositionChanged? onPositionChanged;

  static final _hitboxSize = OfficeLayout.characterSize;
  static const _speed = 180.0;

  PlayerProfile _profile;
  late final NameTagComponent _nameTag;

  /// The player's current name, role, and presence status.
  PlayerProfile get profile => _profile;

  Vector2 _direction = Vector2.zero();
  bool _movementEnabled = true;

  set movementEnabled(bool value) {
    _movementEnabled = value;
    if (!value) {
      _direction = Vector2.zero();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(
      'characters/office_worker.png',
      srcSize: Vector2.all(64),
    );

    _nameTag = NameTagComponent(
      badgeLabel: _profile.status.displayLabel,
      badgeColor: _profile.status.displayColor,
      name: _profile.name,
      role: _profile.role,
      characterWidth: size.x,
    );
    await add(_nameTag);
  }

  /// Applies edited profile data (name, role, status) to the player.
  void updateProfile(PlayerProfile updated) {
    _profile = updated;
    _nameTag.applyChanges(
      badgeLabel: updated.status.displayLabel,
      badgeColor: updated.status.displayColor,
      name: updated.name,
      role: updated.role,
    );
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (!_movementEnabled) {
      return true;
    }
    _direction = Vector2(
      _axis(
        keysPressed,
        [LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight],
        [LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft],
      ),
      _axis(
        keysPressed,
        [LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown],
        [LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp],
      ),
    );
    _selectDirectionFrame();
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_movementEnabled || _direction.isZero()) {
      return;
    }

    final movement = _direction.normalized() * (_speed * dt);
    tryMove(movement);
  }

  /// Moves horizontally then vertically, retaining each axis only if walkable.
  Vector2 tryMove(Vector2 delta) {
    if (!_movementEnabled) {
      return position;
    }
    final previousPosition = position.clone();
    final horizontal = position.clone()..x += delta.x;
    if (_canTraverse(position, horizontal)) {
      position.x = horizontal.x;
    }

    final vertical = position.clone()..y += delta.y;
    if (_canTraverse(position, vertical)) {
      position.y = vertical.y;
    }
    if (position != previousPosition) {
      onPositionChanged?.call(position);
    }
    return position;
  }

  double _axis(
    Set<LogicalKeyboardKey> keysPressed,
    List<LogicalKeyboardKey> positiveKeys,
    List<LogicalKeyboardKey> negativeKeys,
  ) =>
      (positiveKeys.any(keysPressed.contains) ? 1 : 0) -
      (negativeKeys.any(keysPressed.contains) ? 1 : 0);

  bool _canTraverse(Vector2 start, Vector2 end) {
    if (!_canOccupy(end)) {
      return false;
    }

    final sweptHitbox = Rect.fromLTRB(
      (start.x < end.x ? start.x : end.x) - _hitboxSize.x / 2,
      (start.y < end.y ? start.y : end.y) - _hitboxSize.y / 2,
      (start.x > end.x ? start.x : end.x) + _hitboxSize.x / 2,
      (start.y > end.y ? start.y : end.y) + _hitboxSize.y / 2,
    );
    return OfficeLayout.blockers.every(
      (blocker) => !sweptHitbox.overlaps(blocker),
    );
  }

  bool _canOccupy(Vector2 candidate) {
    final hitbox = Rect.fromCenter(
      center: Offset(candidate.x, candidate.y),
      width: _hitboxSize.x,
      height: _hitboxSize.y,
    );
    final isInsideWorld = hitbox.left >= 0 &&
        hitbox.top >= 0 &&
        hitbox.right <= OfficeLayout.worldSize.x &&
        hitbox.bottom <= OfficeLayout.worldSize.y;
    return isInsideWorld &&
        OfficeLayout.blockers.every((blocker) => !hitbox.overlaps(blocker));
  }

  void _selectDirectionFrame() {
    if (sprite == null || _direction.isZero()) {
      return;
    }
    final frame = _direction.x.abs() > _direction.y.abs()
        ? (_direction.x < 0 ? 1 : 2)
        : (_direction.y < 0 ? 3 : 0);
    sprite = Sprite(
      sprite!.image,
      srcPosition: Vector2(frame * 64, 0),
      srcSize: Vector2.all(64),
    );
  }
}

import 'package:ai_office/game/map/office_layout.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// A keyboard-controlled office worker that remains inside the walkable map.
class OfficePlayer extends SpriteComponent with KeyboardHandler {
  OfficePlayer({Vector2? position})
      : super(
          position: position ?? OfficeLayout.worldSize.clone() / 2,
          size: _hitboxSize.clone(),
          anchor: Anchor.center,
        );

  OfficePlayer.forTest({required Vector2 position}) : this(position: position);

  static final _hitboxSize = Vector2.all(40);
  static const _speed = 180.0;

  Vector2 _direction = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(
      'characters/office_worker.png',
      srcSize: Vector2.all(64),
    );
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _direction = Vector2(
      _axis(keysPressed, LogicalKeyboardKey.keyD,
              LogicalKeyboardKey.arrowRight) -
          _axis(keysPressed, LogicalKeyboardKey.keyA,
              LogicalKeyboardKey.arrowLeft),
      _axis(keysPressed, LogicalKeyboardKey.keyS,
              LogicalKeyboardKey.arrowDown) -
          _axis(
              keysPressed, LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp),
    );
    _selectDirectionFrame();
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_direction.isZero()) {
      return;
    }

    final movement = _direction.normalized() * (_speed * dt);
    tryMove(movement);
  }

  /// Moves horizontally then vertically, retaining each axis only if walkable.
  Vector2 tryMove(Vector2 delta) {
    final horizontal = position.clone()..x += delta.x;
    if (_canOccupy(horizontal)) {
      position.x = horizontal.x;
    }

    final vertical = position.clone()..y += delta.y;
    if (_canOccupy(vertical)) {
      position.y = vertical.y;
    }
    return position;
  }

  double _axis(
    Set<LogicalKeyboardKey> keysPressed,
    LogicalKeyboardKey positive,
    LogicalKeyboardKey negative,
  ) =>
      (keysPressed.contains(positive) ? 1 : 0) -
      (keysPressed.contains(negative) ? 1 : 0);

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

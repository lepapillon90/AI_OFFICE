import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Three-line overhead tag shown above a character: a colored status dot
/// with a label, the character's name, and their role/job title.
///
/// The status dot is a plain vector shape rather than an emoji glyph
/// because CanvasKit has no bundled emoji font and cannot fetch one in
/// this environment, which previously rendered as broken "tofu" boxes.
class NameTagComponent extends PositionComponent {
  NameTagComponent({
    required String badgeLabel,
    required Color badgeColor,
    required String name,
    required String role,
    required double characterWidth,
  }) : super(size: Vector2(characterWidth, 0)) {
    _badgeDot = CircleComponent(
      radius: 4,
      anchor: Anchor.center,
      position: Vector2(characterWidth / 2 - 24, -40),
      paint: Paint()..color = badgeColor,
    );
    _badge = TextComponent(
      text: badgeLabel,
      anchor: Anchor.bottomCenter,
      position: Vector2(characterWidth / 2, -32),
      textRenderer: _badgeStyle(badgeColor),
    );
    _name = TextComponent(
      text: name,
      anchor: Anchor.bottomCenter,
      position: Vector2(characterWidth / 2, -18),
      textRenderer: _nameStyle,
    );
    _role = TextComponent(
      text: role,
      anchor: Anchor.bottomCenter,
      position: Vector2(characterWidth / 2, -4),
      textRenderer: _roleStyle,
    );
  }

  late final CircleComponent _badgeDot;
  late final TextComponent _badge;
  late final TextComponent _name;
  late final TextComponent _role;

  static final _nameStyle = TextPaint(
    style: TextStyle(
      color: Colors.white,
      fontFamily: 'NotoSansKR',
      fontSize: 12,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.black54,
    ),
  );

  static final _roleStyle = TextPaint(
    style: TextStyle(
      color: Colors.white70,
      fontFamily: 'NotoSansKR',
      fontSize: 10,
      backgroundColor: Colors.black54,
    ),
  );

  static TextPaint _badgeStyle(Color color) => TextPaint(
        style: TextStyle(
          color: color,
          fontFamily: 'NotoSansKR',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await addAll([_badgeDot, _badge, _name, _role]);
  }

  /// Updates the badge, name, and role text after a profile edit.
  void applyChanges({
    String? badgeLabel,
    Color? badgeColor,
    String? name,
    String? role,
  }) {
    if (badgeLabel != null) {
      _badge.text = badgeLabel;
    }
    if (badgeColor != null) {
      _badge.textRenderer = _badgeStyle(badgeColor);
      _badgeDot.paint = Paint()..color = badgeColor;
    }
    if (name != null) {
      _name.text = name;
    }
    if (role != null) {
      _role.text = role;
    }
  }
}

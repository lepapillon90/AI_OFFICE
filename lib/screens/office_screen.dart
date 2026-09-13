import 'package:ai_office/game/office_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

/// Hosts the full-screen Flame office experience.
class OfficeScreen extends StatelessWidget {
  const OfficeScreen({super.key});

  @override
  Widget build(BuildContext context) => GameWidget(game: OfficeGame());
}

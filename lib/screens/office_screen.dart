import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/computer_popup.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Hosts the full-screen Flame office experience.
class OfficeScreen extends StatelessWidget {
  const OfficeScreen({this.game, super.key});

  final OfficeGame? game;

  @override
  Widget build(BuildContext context) {
    final officeGame = game ?? OfficeGame();

    return Scaffold(
      body: AnimatedBuilder(
        animation: officeGame,
        builder: (context, _) => Stack(
          children: [
            GameWidget(game: officeGame),
            if (officeGame.isComputerNearby && !officeGame.isComputerPopupOpen)
              const Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xCC000000),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        '[E] 컴퓨터 사용',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            if (officeGame.isComputerPopupOpen)
              ComputerPopup(onClose: officeGame.closeComputerPopup),
          ],
        ),
      ),
    );
  }
}

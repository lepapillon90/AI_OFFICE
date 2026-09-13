import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/game/player/player_status.dart';
import 'package:ai_office/screens/roster_editor_dialog.dart';
import 'package:flutter/material.dart';

/// A compact popover shown when the player clicks their own character:
/// an avatar preview, current name/role/status, and shortcuts to manage
/// their profile or (eventually) customize their avatar.
class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.game, super.key});

  final OfficeGame game;

  @override
  Widget build(BuildContext context) {
    final profile = game.playerProfile;
    return Positioned(
      top: 72,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5DE0E6)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _AvatarPreview(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: '이름·직책·상태 수정',
                              iconSize: 16,
                              visualDensity: VisualDensity.compact,
                              color: Colors.white70,
                              icon: const Icon(Icons.edit),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => RosterEditorDialog(game: game),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          profile.role,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 8, color: profile.status.displayColor),
                            const SizedBox(width: 6),
                            Text(
                              profile.status.displayLabel,
                              style: TextStyle(
                                color: profile.status.displayColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    iconSize: 18,
                    color: Colors.white70,
                    icon: const Icon(Icons.close),
                    onPressed: game.closeProfileCard,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('아바타 꾸미기는 준비 중입니다.')),
                  ),
                  icon: const Icon(Icons.checkroom, size: 16),
                  label: const Text('아바타 꾸미기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crops the player's first walk-cycle frame out of the character sheet to
/// use as a round avatar thumbnail.
class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview();

  static const _frameSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: _frameSize,
        height: _frameSize,
        child: OverflowBox(
          maxWidth: _frameSize * 4,
          maxHeight: _frameSize,
          alignment: Alignment.topLeft,
          child: Image.asset(
            'assets/images/characters/office_worker.png',
            width: _frameSize * 4,
            height: _frameSize,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}

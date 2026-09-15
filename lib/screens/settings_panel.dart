import 'package:ai_office/main.dart' show windowedSize;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The only two window states this app offers — 창모드(windowed, a fixed
/// size) or 전체화면(fullscreen). Free-form resizing is disabled app-wide
/// (see main.dart), so this is the only way to change the window.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool? _isFullScreen;

  @override
  void initState() {
    super.initState();
    windowManager.isFullScreen().then((value) {
      if (mounted) setState(() => _isFullScreen = value);
    });
  }

  Future<void> _setFullScreen(bool fullScreen) async {
    setState(() => _isFullScreen = fullScreen);
    await windowManager.setFullScreen(fullScreen);
    if (!fullScreen) {
      // Leaving fullscreen doesn't restore the pre-fullscreen size on its
      // own — pin it back to the one windowed size this app offers.
      await windowManager.setSize(windowedSize);
      await windowManager.center();
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF17212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5DE0E6)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '설정',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: widget.onClose,
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('화면 모드', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                _ModeOption(
                  icon: Icons.crop_din,
                  label: '창모드',
                  selected: _isFullScreen == false,
                  onTap: () => _setFullScreen(false),
                ),
                const SizedBox(height: 6),
                _ModeOption(
                  icon: Icons.fullscreen,
                  label: '전체화면',
                  selected: _isFullScreen == true,
                  onTap: () => _setFullScreen(true),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF23303C) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? const Color(0xFF5DE0E6) : Colors.white54,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check, size: 18, color: Color(0xFF5DE0E6)),
              ],
            ),
          ),
        ),
      );
}

import 'package:ai_office/screens/auth_gate.dart';
import 'package:ai_office/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

/// The one fixed size 창모드(windowed mode) always uses — see
/// lib/screens/settings_panel.dart, the only place besides here that
/// changes window size/fullscreen state.
const windowedSize = Size(1280, 720);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  // Free-form resizing is what used to force the whole UI to be
  // responsive to arbitrary window sizes; disabling it and offering only
  // two fixed states (창모드 at [windowedSize] / 전체화면) removes the need
  // for that entirely. windowManager calls are Windows/macOS/Linux-only
  // no-ops elsewhere, but this app is Windows desktop only anyway (see
  // pubspec.yaml's description).
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: windowedSize, center: true),
    () async {
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    },
  );
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const OfficeApp());
}

class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'NotoSansKR'),
        home: const AuthGate(),
      );
}

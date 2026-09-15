import 'dart:io';

/// Starts/stops docs/PHASE8_REMOTE_AGENT.md's local agent
/// (bin/remote_agent.dart) as a child process of this desktop app —
/// gated by the in-game server machine's power switch (see
/// OfficeGame.updateServerRunning). Replaces needing a separately
/// installed Windows Scheduled Task (scripts/install_remote_agent_task.ps1)
/// on a computer that just keeps this app open instead; that script still
/// works too, and both ultimately just run the same script against the
/// same `server_control` flag, so running both on one computer would
/// double-execute every command.
///
/// Only usable in a dev checkout right now: it locates bin/remote_agent.dart
/// by walking up from the current working directory / this executable's
/// own folder, which won't exist once the app is packaged for install on
/// another computer. Packaging that up (e.g. `dart compile exe` producing
/// a standalone remote_agent.exe shipped alongside the app) is tracked as
/// follow-up work.
class AgentProcessManager {
  Process? _process;

  bool get isRunning => _process != null;

  /// Whether this computer has a config file (bin/remote_agent.config.json
  /// or [configFileName]) for the agent to run with — i.e. whether this
  /// computer is meant to host an agent at all. See
  /// bin/remote_agent.config.example.json.
  bool hasConfig({String configFileName = 'remote_agent.config.json'}) {
    final root = _findProjectRoot();
    if (root == null) return false;
    return File(_join(root.path, 'bin', configFileName)).existsSync();
  }

  /// Starts the agent process if it isn't already running and this
  /// computer has a config file. Silently does nothing otherwise (no
  /// project root found, or no config — this just isn't an agent
  /// computer).
  Future<void> start({String configFileName = 'remote_agent.config.json'}) async {
    if (_process != null) {
      return;
    }
    final root = _findProjectRoot();
    if (root == null) {
      return;
    }
    final scriptPath = _join(root.path, 'bin', 'remote_agent.dart');
    if (!File(scriptPath).existsSync() ||
        !File(_join(root.path, 'bin', configFileName)).existsSync()) {
      return;
    }
    final dartExecutable = _findDartExecutable();
    if (dartExecutable == null) {
      return;
    }
    _process = await Process.start(
      dartExecutable,
      ['run', scriptPath, '--config', configFileName],
      workingDirectory: root.path,
      // No console window at all (Windows' DETACHED_PROCESS flag) — this
      // runs invisibly in the background rather than popping up a
      // terminal the user would otherwise have to notice and close.
      // Also means [stop] kills the real dart.exe directly rather than a
      // shell wrapper around it (see [_findDartExecutable]'s doc comment
      // on why a shell isn't needed here in the first place).
      mode: ProcessStartMode.detached,
    );
  }

  /// Stops the agent process if this manager started one. A no-op
  /// otherwise (e.g. this computer never had a config, or it's already
  /// stopped).
  void stop() {
    _process?.kill();
    _process = null;
  }

  String _join(String a, String b, String c) =>
      '$a${Platform.pathSeparator}$b${Platform.pathSeparator}$c';

  /// Resolves `dart` to its full path (e.g. `...\dart-sdk\bin\dart.exe`)
  /// by searching PATH manually, since dart:io's Process.start bypasses
  /// the shell and Windows' CreateProcess won't resolve a bare extension-
  /// less name like 'dart' the way cmd.exe would — passing 'dart' as-is
  /// fails with "지정된 파일을 찾을 수 없습니다" even though `dart` works fine
  /// from an interactive terminal. Resolving the full path here avoids
  /// needing `runInShell: true`, which would spawn a visible cmd.exe
  /// wrapper around the real process — one whose child [stop] can't
  /// reliably kill, since terminating a process doesn't cascade to its
  /// children on Windows.
  String? _findDartExecutable() {
    if (!Platform.isWindows) {
      final path = Platform.environment['PATH'] ?? '';
      for (final dir in path.split(':')) {
        if (dir.isEmpty) continue;
        final candidate = '$dir/dart';
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
      return null;
    }

    final path = Platform.environment['PATH'] ?? '';
    final dirs = path.split(';').where((d) => d.isNotEmpty);
    // The common case on Windows: a Flutter install only puts its own
    // <flutter_root>\bin on PATH, which holds dart.bat (a wrapper script,
    // not directly runnable via CreateProcess) rather than the real
    // dart.exe — that lives a few folders down, at
    // <flutter_root>\bin\cache\dart-sdk\bin\dart.exe. Prefer a bare
    // dart.exe already on PATH (e.g. a standalone Dart SDK install) if
    // one exists, then fall back to deriving the path from dart.bat.
    for (final dir in dirs) {
      final candidate = '$dir${Platform.pathSeparator}dart.exe';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    for (final dir in dirs) {
      final batCandidate = '$dir${Platform.pathSeparator}dart.bat';
      if (!File(batCandidate).existsSync()) {
        continue;
      }
      final sep = Platform.pathSeparator;
      final derived = '$dir${sep}cache${sep}dart-sdk${sep}bin${sep}dart.exe';
      if (File(derived).existsSync()) {
        return derived;
      }
    }
    return null;
  }

  /// The project root is wherever bin/remote_agent.dart lives. Checks the
  /// current working directory first (true when running via
  /// `flutter run -d windows` from the project root), then walks up from
  /// this executable's own folder (covers a manually-run built exe still
  /// sitting inside the project tree, e.g. build/windows/x64/runner/Debug).
  Directory? _findProjectRoot() {
    final cwd = Directory.current;
    if (File(_join(cwd.path, 'bin', 'remote_agent.dart')).existsSync()) {
      return cwd;
    }
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 8; i++) {
      if (File(_join(dir.path, 'bin', 'remote_agent.dart')).existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }
    return null;
  }
}

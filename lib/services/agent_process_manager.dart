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
    _process = await Process.start(
      'dart',
      ['run', scriptPath, '--config', configFileName],
      workingDirectory: root.path,
      mode: ProcessStartMode.detachedWithStdio,
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

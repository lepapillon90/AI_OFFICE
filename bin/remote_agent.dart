// Standalone local agent for docs/PHASE8_REMOTE_AGENT.md — runs on the
// company's shared office computer (not inside the Flutter app, which as a
// browser tab can never touch the local filesystem/terminal itself).
//
// Deliberately zero external packages, only dart:io/dart:convert/dart:async
// — pubspec.yaml is owned by a concurrent process in this worktree and
// isn't touched by this session, so this script can't declare a pub
// dependency and still be run with a plain `dart run`.
//
// Usage:
//   dart run bin/remote_agent.dart --company-id <uuid> --service-key <key>
// (or the SUPABASE_SERVICE_ROLE_KEY / AI_OFFICE_COMPANY_ID / SUPABASE_URL
// environment variables, or a bin/remote_agent.config.json file next to
// this script — see docs/PHASE8_REMOTE_AGENT.md. Precedence: CLI args >
// env vars > config file, so a scheduled task can run this with no
// arguments at all once the config file is in place.)
import 'dart:convert';
import 'dart:io';

const _defaultSupabaseUrl = 'https://sybdrgllifzrbwqgkkff.supabase.co';
const _pollInterval = Duration(seconds: 5);

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final config = _readConfigFile();
  final supabaseUrl = options['url'] ??
      Platform.environment['SUPABASE_URL'] ??
      config['supabaseUrl'] as String? ??
      _defaultSupabaseUrl;
  final serviceKey = options['service-key'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      config['serviceKey'] as String?;
  final companyId = options['company-id'] ??
      Platform.environment['AI_OFFICE_COMPANY_ID'] ??
      config['companyId'] as String?;
  // Null = the default agent (this computer handles `@서버` commands, i.e.
  // rows with machine_key IS NULL). Set this to a specific
  // AiEmployee.workstationId (e.g. "desk-1", visible in the roster
  // editor's "실제 컴퓨터와 연결" section) to instead handle only the
  // commands addressed to that one employee — see
  // docs/PHASE8_REMOTE_AGENT.md's multi-computer section. One physical
  // computer runs one agent process with one (or no) --agent-key.
  final agentKey = options['agent-key'] ??
      Platform.environment['AI_OFFICE_AGENT_KEY'] ??
      config['agentKey'] as String?;

  if (serviceKey == null || serviceKey.isEmpty) {
    stderr.writeln(
        '오류: --service-key (또는 SUPABASE_SERVICE_ROLE_KEY 환경 변수)가 필요합니다.');
    exitCode = 64;
    return;
  }
  if (companyId == null || companyId.isEmpty) {
    stderr.writeln(
        '오류: --company-id (또는 AI_OFFICE_COMPANY_ID 환경 변수)가 필요합니다.');
    exitCode = 64;
    return;
  }

  final agent = RemoteAgent(
    supabaseUrl: supabaseUrl,
    serviceKey: serviceKey,
    companyId: companyId,
    agentKey: (agentKey == null || agentKey.isEmpty) ? null : agentKey,
  );

  print('AI Office 원격 에이전트 시작 — company_id=$companyId'
      '${agent.agentKey == null ? " (기본 에이전트, @서버 명령 처리)" : ", agent_key=${agent.agentKey}"}');
  print('$_pollInterval 간격으로 대기 중인 명령을 확인합니다. 종료하려면 Ctrl+C.');

  while (true) {
    try {
      await agent.pollOnce();
    } catch (e) {
      stderr.writeln('폴링 중 오류: $e');
    }
    await Future<void>.delayed(_pollInterval);
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      result[arg.substring(2)] = args[i + 1];
    }
  }
  return result;
}

/// Reads `bin/remote_agent.config.json` (next to this script, resolved via
/// [Platform.script] so it works regardless of the working directory a
/// scheduled task launches from) if present — lets a scheduled task run
/// this agent with no command-line arguments at all, so the service-role
/// key never needs to sit in that task's own stored settings. Never
/// committed (see .gitignore) since it holds that secret in plain text;
/// docs/PHASE8_REMOTE_AGENT.md documents its shape.
Map<String, dynamic> _readConfigFile() {
  final path = Platform.script.resolve('remote_agent.config.json').toFilePath();
  final file = File(path);
  if (!file.existsSync()) {
    return const {};
  }
  try {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('설정 파일($path)을 읽지 못했습니다: $e');
    return const {};
  }
}

class RemoteAgent {
  RemoteAgent({
    required this.supabaseUrl,
    required this.serviceKey,
    required this.companyId,
    this.agentKey,
  });

  final String supabaseUrl;
  final String serviceKey;
  final String companyId;

  /// Null = this agent handles only unaddressed `@서버` commands
  /// (machine_key IS NULL). Non-null = this agent handles only the
  /// commands addressed to the employee with that workstationId.
  final String? agentKey;
  final HttpClient _http = HttpClient();

  Future<void> pollOnce() async {
    final pending = await _fetchPending();
    if (pending.isEmpty) {
      return;
    }
    // Checked once per poll cycle, not per command — the power switch is
    // shared company-wide state a browser tab can flip at any time (see
    // docs/PHASE8_REMOTE_AGENT.md's "서버 실행/종료"), so this agent
    // process itself can stay running via the Windows scheduled task the
    // whole time and just sit idle, only actually executing anything
    // while the switch is on.
    final running = await _isServerRunning();
    for (final command in pending) {
      if (!running) {
        await _updateResult(
          command['id'] as String,
          status: 'failed',
          result: '서버가 꺼져 있습니다. 서버기계에서 "서버 실행"을 눌러주세요.',
        );
        continue;
      }
      await _execute(command);
    }
  }

  Future<bool> _isServerRunning() async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/server_control').replace(
      queryParameters: {
        'company_id': 'eq.$companyId',
        'select': 'running',
      },
    );
    final request = await _http.getUrl(uri);
    _addHeaders(request);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      stderr.writeln('서버 실행 상태 조회 실패 (${response.statusCode}): $body');
      return false;
    }
    final decoded = jsonDecode(body) as List<dynamic>;
    if (decoded.isEmpty) {
      return false;
    }
    return (decoded.first as Map<String, dynamic>)['running'] as bool? ?? false;
  }

  Future<List<Map<String, dynamic>>> _fetchPending() async {
    final key = agentKey;
    final uri = Uri.parse('$supabaseUrl/rest/v1/remote_commands').replace(
      queryParameters: {
        'company_id': 'eq.$companyId',
        'status': 'eq.pending',
        'machine_key': key == null ? 'is.null' : 'eq.$key',
        'select': 'id,command_type,params',
        'order': 'created_at.asc',
      },
    );
    final request = await _http.getUrl(uri);
    _addHeaders(request);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      stderr.writeln('명령 조회 실패 (${response.statusCode}): $body');
      return const [];
    }
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> _execute(Map<String, dynamic> command) async {
    final id = command['id'] as String;
    final type = command['command_type'] as String;
    final params = (command['params'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    print('명령 처리 중: id=$id type=$type params=$params');
    String status;
    String result;
    try {
      switch (type) {
        case 'open_terminal':
          result = await _openTerminal();
          status = 'done';
        case 'open_terminal_claude':
          result = await _openTerminal(runClaude: true);
          status = 'done';
        case 'create_folder':
          result = await _createFolder(params['name'] as String? ?? '');
          status = 'done';
        default:
          result = '지원하지 않는 명령 유형입니다: $type';
          status = 'failed';
      }
    } catch (e) {
      result = '실행 중 오류가 발생했습니다: $e';
      status = 'failed';
    }
    print('처리 결과: id=$id status=$status result=$result');
    await _updateResult(id, status: status, result: result);
  }

  /// Opens a terminal, optionally running the `claude` CLI inside it
  /// (`open_terminal_claude`) — still one specific, named program, not an
  /// arbitrary command string carried in from chat; there is no path from
  /// a chat message to an arbitrary shell command.
  Future<String> _openTerminal({bool runClaude = false}) async {
    if (Platform.isWindows) {
      // `start` is a cmd builtin, not its own executable — has to run
      // through cmd /c. The empty string is the window-title argument
      // `start` expects before the actual command; Dart quotes it as `""`
      // on the generated command line, which is what `start` needs to not
      // mistake `cmd` itself for the title. `/k claude` (rather than /c)
      // keeps the new window open running the CLI instead of closing the
      // instant it launches.
      await Process.start(
        'cmd',
        runClaude
            ? ['/c', 'start', '', 'cmd', '/k', 'claude']
            : ['/c', 'start', '', 'cmd'],
        mode: ProcessStartMode.detached,
      );
      return runClaude ? '터미널을 열고 Claude CLI를 실행했습니다.' : '터미널을 열었습니다.';
    }
    if (Platform.isMacOS) {
      if (runClaude) {
        await Process.start(
          'osascript',
          ['-e', 'tell application "Terminal" to do script "claude"'],
          mode: ProcessStartMode.detached,
        );
        return '터미널을 열고 Claude CLI를 실행했습니다.';
      }
      await Process.start('open', ['-a', 'Terminal'],
          mode: ProcessStartMode.detached);
      return '터미널을 열었습니다.';
    }
    await Process.start(
      'x-terminal-emulator',
      runClaude ? ['-e', 'claude'] : const [],
      mode: ProcessStartMode.detached,
    );
    return runClaude ? '터미널을 열고 Claude CLI를 실행했습니다.' : '터미널을 열었습니다.';
  }

  Future<String> _createFolder(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw StateError('폴더 이름이 비어 있습니다.');
    }
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      throw StateError('폴더 이름에 사용할 수 없는 문자가 포함되어 있습니다: $name');
    }
    final desktop = _desktopPath();
    final dir = Directory('$desktop${Platform.pathSeparator}$name');
    await dir.create(recursive: true);
    return '바탕화면에 "$name" 폴더를 만들었습니다.';
  }

  String _desktopPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '.';
      return '$userProfile${Platform.pathSeparator}Desktop';
    }
    final home = Platform.environment['HOME'] ?? '.';
    return '$home${Platform.pathSeparator}Desktop';
  }

  Future<void> _updateResult(
    String id, {
    required String status,
    required String result,
  }) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/remote_commands').replace(
      queryParameters: {'id': 'eq.$id'},
    );
    final request = await _http.patchUrl(uri);
    _addHeaders(request);
    request.headers.set('Prefer', 'return=minimal');
    // request.write(String) encodes using the request's `encoding`, which
    // HttpClientRequest derives from the Content-Type header's charset —
    // and defaults to Latin-1 when none is given (Content-Type here is
    // just "application/json", no charset), so any non-Latin-1 result
    // text (e.g. the Korean strings every RemoteAgent method here
    // returns) throws "Invalid argument (string): Contains invalid
    // characters." *before* the request ever reaches the network. That
    // silently leaves the row `pending` forever, so it gets re-polled and
    // re-executed on every cycle — encoding to UTF-8 bytes directly
    // sidesteps the request's encoding guess entirely.
    request.add(utf8.encode(jsonEncode({
      'status': status,
      'result': result,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    })));
    final response = await request.close();
    if (response.statusCode >= 300) {
      final body = await response.transform(utf8.decoder).join();
      stderr.writeln('결과 갱신 실패 (${response.statusCode}): $body');
    } else {
      await response.drain<void>();
    }
  }

  void _addHeaders(HttpClientRequest request) {
    request.headers
      ..set('apikey', serviceKey)
      ..set('Authorization', 'Bearer $serviceKey')
      ..set('Content-Type', 'application/json');
  }
}

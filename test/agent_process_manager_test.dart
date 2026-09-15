import 'package:ai_office/services/agent_process_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with the project root as the working directory,
  // which has bin/remote_agent.dart — but a config file under that exact
  // made-up name can never exist (per bin/remote_agent.*.config.json in
  // .gitignore, real ones only ever look like remote_agent*.config.json),
  // so this always exercises the "computer has no agent configured" path
  // regardless of whether this particular dev machine happens to have a
  // real bin/remote_agent.config.json on disk.
  const unconfiguredFileName = 'remote_agent.test-does-not-exist.config.json';

  group('AgentProcessManager', () {
    test('hasConfig() is false for an unconfigured file name', () {
      final manager = AgentProcessManager();
      expect(
        manager.hasConfig(configFileName: unconfiguredFileName),
        isFalse,
      );
    });

    test('start() with no config quietly does nothing', () async {
      final manager = AgentProcessManager();
      await manager.start(configFileName: unconfiguredFileName);
      expect(manager.isRunning, isFalse);
    });

    test('stop() with nothing running is a no-op', () {
      final manager = AgentProcessManager();
      expect(() => manager.stop(), returnsNormally);
      expect(manager.isRunning, isFalse);
    });
  });
}

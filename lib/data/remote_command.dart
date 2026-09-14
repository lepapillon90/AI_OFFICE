/// The whitelisted actions the company's local agent (a small program the
/// company runs on its own shared office computer — see
/// docs/PHASE8_REMOTE_AGENT.md) is allowed to perform there. Deliberately a
/// closed set rather than an arbitrary shell command string, so a chat
/// message can never make the agent do anything beyond what it was
/// explicitly built to do.
enum RemoteCommandType {
  openTerminal('open_terminal'),
  createFolder('create_folder'),
  // Opens a terminal and runs the `claude` CLI inside it — still a fixed,
  // named program (not an arbitrary command string from chat), kept as
  // its own whitelist entry rather than a general "run this program" type
  // so the set of things a chat message can ever launch stays enumerable.
  openTerminalClaude('open_terminal_claude');

  const RemoteCommandType(this.wireName);

  /// The value stored in `remote_commands.command_type` — matches the SQL
  /// check constraint in docs/PHASE8_REMOTE_AGENT.md.
  final String wireName;
}

import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/multiplayer_channel.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/auth/login_screen.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows [LoginScreen] while signed out; once signed in, loads the user's
/// company and AI employee roster from Supabase and shows [OfficeScreen].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repository = CompanyRepository(Supabase.instance.client);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return _CompanyLoader(
          key: ValueKey(session.user.id),
          repository: _repository,
        );
      },
    );
  }
}

class _LoadedSession {
  const _LoadedSession({
    required this.game,
    required this.canManageRoster,
    required this.multiplayer,
  });

  final OfficeGame game;
  final bool canManageRoster;
  final MultiplayerChannel multiplayer;
}

class _CompanyLoader extends StatefulWidget {
  const _CompanyLoader({super.key, required this.repository});

  final CompanyRepository repository;

  @override
  State<_CompanyLoader> createState() => _CompanyLoaderState();
}

class _CompanyLoaderState extends State<_CompanyLoader> {
  late final Future<_LoadedSession> _future = _load();
  MultiplayerChannel? _multiplayerToDispose;

  Future<_LoadedSession> _load() async {
    final companyId = await widget.repository.ensureCompany();
    final role = await widget.repository.fetchRole(companyId);
    final employees = await widget.repository.fetchEmployees(companyId);

    final multiplayer = MultiplayerChannel(
      client: Supabase.instance.client,
      companyId: companyId,
      userId: Supabase.instance.client.auth.currentUser!.id,
    );
    _multiplayerToDispose = multiplayer;

    final game = OfficeGame(
      employees: employees,
      onEmployeeChanged: (employee) =>
          widget.repository.upsertEmployee(companyId, employee),
      multiplayer: multiplayer,
    );

    return _LoadedSession(
      game: game,
      canManageRoster: role.canManageRoster,
      multiplayer: multiplayer,
    );
  }

  @override
  void dispose() {
    _multiplayerToDispose?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedSession>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('회사 데이터를 불러오지 못했습니다.\n${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data!;
        return OfficeScreen(
          game: session.game,
          canManageRoster: session.canManageRoster,
          onLogout: () => Supabase.instance.client.auth.signOut(),
        );
      },
    );
  }
}

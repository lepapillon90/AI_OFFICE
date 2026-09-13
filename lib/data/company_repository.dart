import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads and persists the signed-in user's company and AI employee roster.
///
/// One company per user for now (MVP): a company is created automatically
/// the first time a user signs in, seeded with the sample roster.
class CompanyRepository {
  CompanyRepository(this._client);

  final SupabaseClient _client;

  /// Returns the current user's company id, creating one (seeded with the
  /// sample employee roster) on first sign-in.
  Future<String> ensureCompany() async {
    final userId = _client.auth.currentUser!.id;

    final existing = await _client
        .from('companies')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }

    final created = await _client
        .from('companies')
        .insert({'owner_id': userId, 'name': '내 회사'})
        .select('id')
        .single();
    final companyId = created['id'] as String;

    await _client.from('company_members').insert({
      'company_id': companyId,
      'user_id': userId,
      'role': CompanyRole.owner.dbValue,
    });

    await _client.from('employees').insert([
      for (final employee in sampleEmployees)
        _toSeedRow(companyId, employee),
    ]);

    return companyId;
  }

  /// Returns the current user's role within [companyId] ('member' if they
  /// have no membership row, which shouldn't normally happen).
  Future<CompanyRole> fetchRole(String companyId) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('company_members')
        .select('role')
        .eq('company_id', companyId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return CompanyRole.member;
    }
    return CompanyRole.fromDb(row['role'] as String);
  }

  /// Fetches the AI employee roster for [companyId].
  Future<List<AiEmployee>> fetchEmployees(String companyId) async {
    final rows = await _client
        .from('employees')
        .select()
        .eq('company_id', companyId)
        .order('workstation_id');
    return rows.map(_fromRow).toList();
  }

  /// Saves an edited employee (name, role, status) back to Supabase.
  Future<void> upsertEmployee(String companyId, AiEmployee employee) async {
    await _client
        .from('employees')
        .upsert(_toRow(companyId, employee), onConflict: 'id');
  }

  /// Row for the initial seed insert — omits `id` so Postgres generates a
  /// real UUID rather than reusing the sample data's placeholder ids.
  Map<String, dynamic> _toSeedRow(String companyId, AiEmployee employee) => {
        'company_id': companyId,
        'workstation_id': employee.workstationId,
        'name': employee.name,
        'role': employee.role,
        'provider': employee.provider,
        'status': employee.status.name,
      };

  Map<String, dynamic> _toRow(String companyId, AiEmployee employee) => {
        'id': employee.id,
        ..._toSeedRow(companyId, employee),
      };

  AiEmployee _fromRow(Map<String, dynamic> row) => AiEmployee(
        id: row['id'] as String,
        name: row['name'] as String,
        role: row['role'] as String,
        provider: row['provider'] as String,
        workstationId: row['workstation_id'] as String,
        status: NpcStatus.values.byName(row['status'] as String),
      );
}

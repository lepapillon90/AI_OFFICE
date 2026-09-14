import 'package:ai_office/data/company_member.dart';
import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/data/pending_invite.dart';
import 'package:ai_office/data/username_auth.dart';
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

  /// Returns the current user's company id.
  ///
  /// Resolution order: a company this user owns; a company they're already
  /// a member of; a pending invite addressed to their email (accepted on
  /// the spot); otherwise a brand-new company (seeded with the sample
  /// employee roster) is created for them, as on every first sign-in before
  /// invites existed.
  Future<String> ensureCompany() async {
    final user = _client.auth.currentUser!;
    final userId = user.id;

    final existing = await _client
        .from('companies')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }

    final membership = await _client
        .from('company_members')
        .select('company_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (membership != null) {
      return membership['company_id'] as String;
    }

    final email = user.email;
    if (email != null) {
      final invite = await _client
          .from('invites')
          .select('id, company_id, role')
          .eq('email', email)
          .eq('status', 'pending')
          .maybeSingle();
      if (invite != null) {
        final companyId = invite['company_id'] as String;
        await _client.from('company_members').insert({
          'company_id': companyId,
          'user_id': userId,
          'role': invite['role'] as String,
        });
        await _client
            .from('invites')
            .update({'status': 'accepted'})
            .eq('id', invite['id'] as String);
        return companyId;
      }
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

  /// Invites [username] to join [companyId] with [role]. Takes effect the
  /// next time that username signs up or logs in (see [ensureCompany]).
  Future<void> inviteMember(
    String companyId, {
    required String username,
    required CompanyRole role,
  }) async {
    await _client.from('invites').insert({
      'company_id': companyId,
      'email': UsernameAuth.toEmail(username),
      'role': role.dbValue,
      'invited_by': _client.auth.currentUser!.id,
    });
  }

  /// Lists invites for [companyId] that haven't been accepted yet.
  Future<List<PendingInvite>> fetchPendingInvites(String companyId) async {
    final rows = await _client
        .from('invites')
        .select()
        .eq('company_id', companyId)
        .eq('status', 'pending')
        .order('created_at');
    return rows.map(PendingInvite.fromRow).toList();
  }

  /// Withdraws an invite that hasn't been accepted yet.
  Future<void> cancelInvite(String inviteId) async {
    await _client.from('invites').delete().eq('id', inviteId);
  }

  /// Every signed-in member of [companyId] with their username/role — owner
  /// only (see docs/PHASE7_ADMIN.md's `company_members_with_email`
  /// function; a non-owner caller gets an empty list back, since the
  /// function itself checks ownership).
  Future<List<CompanyMember>> fetchMembers(String companyId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'company_members_with_email',
      params: {'target_company_id': companyId},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map(CompanyMember.fromRow)
        .toList();
  }

  /// Changes [userId]'s role within [companyId] — owner only (enforced by
  /// the existing `owner_manage_members` RLS policy).
  Future<void> updateMemberRole(
    String companyId,
    String userId,
    CompanyRole role,
  ) async {
    await _client
        .from('company_members')
        .update({'role': role.dbValue})
        .eq('company_id', companyId)
        .eq('user_id', userId);
  }

  /// Removes [userId] from [companyId] entirely (not a role change — the
  /// membership row itself is deleted) — owner only, enforced by the same
  /// `owner_manage_members` RLS policy that already covers every write on
  /// this table (it's declared `for all`, so no new policy is needed for
  /// DELETE). The account itself isn't deleted, only its membership; the
  /// caller is responsible for not targeting the owner's own row (see
  /// AdminPanel, which never shows a remove button for the owner).
  Future<void> removeMember(String companyId, String userId) async {
    await _client
        .from('company_members')
        .delete()
        .eq('company_id', companyId)
        .eq('user_id', userId);
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
        'computer_linked': employee.computerLinked,
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
        // Tolerates the column not existing yet (pre-migration): every
        // employee simply starts out not linked to a real computer.
        computerLinked: row['computer_linked'] as bool? ?? false,
      );
}

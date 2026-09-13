import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/data/username_auth.dart';

/// A signed-in member of a company (as opposed to an [AiEmployee], which is
/// a roster entry, not a real account) — backs the admin screen's member
/// list. Only the company owner can fetch this (see
/// `company_members_with_email` in docs/PHASE7_ADMIN.md).
class CompanyMember {
  const CompanyMember({
    required this.userId,
    required this.email,
    required this.role,
  });

  final String userId;
  final String email;
  final CompanyRole role;

  /// The username the account signed up with (see [UsernameAuth]).
  String get username => UsernameAuth.usernameFromEmail(email) ?? email;

  factory CompanyMember.fromRow(Map<String, dynamic> row) => CompanyMember(
        userId: row['user_id'] as String,
        email: row['email'] as String,
        role: CompanyRole.fromDb(row['role'] as String),
      );
}

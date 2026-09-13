import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/data/username_auth.dart';

/// A not-yet-accepted invite for someone to join a company.
class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final CompanyRole role;

  /// The username the invite was created with, when it followed the usual
  /// username-to-mailinator.com mapping (always true for invites created
  /// through the app's own UI).
  String get username => UsernameAuth.usernameFromEmail(email) ?? email;

  factory PendingInvite.fromRow(Map<String, dynamic> row) => PendingInvite(
        id: row['id'] as String,
        email: row['email'] as String,
        role: CompanyRole.fromDb(row['role'] as String),
      );
}

/// Supabase Auth only understands email/phone accounts, so a "username"
/// login is implemented by deterministically mapping the username to a
/// synthetic email — no lookup table needed, and uniqueness is enforced by
/// Supabase's existing unique-email constraint.
///
/// These addresses are never sent real mail, so "Confirm email" must be
/// turned off in the Supabase project's Auth settings.
abstract final class UsernameAuth {
  static const domain = 'ai-office.local';

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static bool isValidUsername(String value) => _usernamePattern.hasMatch(value);

  static String toEmail(String username) => '$username@$domain';
}

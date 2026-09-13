/// Supabase Auth only understands email/phone accounts, so a "username"
/// login is implemented by deterministically mapping the username to a
/// synthetic email — no lookup table needed, and uniqueness is enforced by
/// Supabase's existing unique-email constraint.
///
/// These addresses are never sent real mail, so "Confirm email" must be
/// turned off in the Supabase project's Auth settings.
///
/// Supabase's server-side email validator checks that the domain actually
/// resolves (has an MX record), so neither a reserved special-use TLD
/// (`.local`, `.internal`, `.test` — RFC 6761/6762) nor a made-up `.com`
/// domain passes. [domain] must be a real, existing domain.
///
/// mailinator.com is used because it's a well-known public disposable-inbox
/// domain built exactly for this ("fake signup") purpose. IMPORTANT: mail
/// sent to any @mailinator.com address is publicly readable by anyone — so
/// "Confirm email" and any email-based password reset must stay OFF for as
/// long as this scheme is in use, or auth codes would leak publicly.
abstract final class UsernameAuth {
  static const domain = 'mailinator.com';

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static bool isValidUsername(String value) => _usernamePattern.hasMatch(value);

  static String toEmail(String username) => '$username@$domain';

  /// Reverses [toEmail] for display purposes (e.g. showing an invite's
  /// target as a username instead of the internal synthetic email).
  static String? usernameFromEmail(String email) {
    final suffix = '@$domain';
    if (!email.toLowerCase().endsWith(suffix)) {
      return null;
    }
    return email.substring(0, email.length - suffix.length);
  }
}

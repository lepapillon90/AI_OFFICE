/// Supabase project connection details.
///
/// The publishable (anon) key is safe to ship in client code as long as
/// every table it can reach has Row Level Security enabled with policies
/// scoping access to the signed-in user — see docs/PHASE4_SUPABASE.md.
abstract final class SupabaseConfig {
  static const url = 'https://sybdrgllifzrbwqgkkff.supabase.co';
  static const publishableKey =
      'sb_publishable__nYVNnSvZKNfU6RRpTYG3w_IQKoXXIn';
}

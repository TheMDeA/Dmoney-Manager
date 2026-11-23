/// Supabase project for Dmoney Manager sync (P0, v3.0.0).
///
/// Both values are publishable by design: the anon key ships in the
/// client app, and Row Level Security — `auth.uid() = owner_id` on
/// every table — is what protects the data. Never put the
/// `service_role` key here (or anywhere in the app): it bypasses RLS
/// entirely and must only ever exist in the Supabase dashboard.
class SupabaseConfig {
  SupabaseConfig._();

  /// The existing project in the DMDA organisation (Singapore),
  /// set up 2026-11-23 via the browser (both SQL migrations ran,
  /// Google provider enabled).
  static const projectUrl = 'https://idxdflgonkbzihdlckxu.supabase.co';

  /// Publishable key (see the class doc). Safe to ship in the APK.
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlkeGRmbGdvbmtiemloZGxja3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU0MDIyMjgsImV4cCI6MjExMDk3ODIyOH0.1Rf42YXKJg_YZN6VrGQx86fts_e65fdfgwIG21UZN8Q';
}

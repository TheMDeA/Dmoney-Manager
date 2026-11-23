import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'drive_backup_service.dart';
import 'supabase_config.dart';

/// Thrown when a Supabase sign-in fails.
class SupabaseAuthException implements Exception {
  SupabaseAuthException(this.message);
  final String message;
  @override
  String toString() => 'SupabaseAuthException: $message';
}

/// Supabase Auth with Google (v3.0.0, P2 — minimal, no UI).
///
/// Reuses the existing `google_sign_in` flow: the Google ID token is
/// handed to Supabase (`signInWithIdToken`). No new login screen, no
/// password. The session persists across app closes — `supabase_flutter`
/// restores it from local storage on `init()` — the same expectation
/// as the Drive session. Sign-out is explicit, from Settings (P5 UI).
///
/// The Google ID token's audience is the Web OAuth client
/// ([DriveBackupService.serverClientId]) — the same client Supabase's
/// Google provider is configured with — so the token Supabase
/// receives is one it accepts.
class SupabaseAuthService {
  static Future<void>? _initFuture;

  /// One-time SDK setup: Google sign-in + Supabase client. Also
  /// restores a persisted Supabase session, if one exists. Safe to
  /// call repeatedly; never shows auth UI.
  static Future<void> init() => _initFuture ??= _init();

  static Future<void> _init() async {
    // Same call (same args) as DriveBackupService._init: the platform
    // init is idempotent for identical parameters, and no app code
    // listens to GoogleSignIn.authenticationEvents, so the duplicate
    // subscription this creates is harmless.
    await GoogleSignIn.instance.initialize(
      serverClientId: DriveBackupService.serverClientId,
    );
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  static SupabaseClient get _client => Supabase.instance.client;

  /// True when a Supabase session exists (signed in, possibly
  /// restored from the previous run). False when signed out — and
  /// also when Supabase never initialised (a failed init must
  /// never crash a caller: sync is an add-on, the app works
  /// offline).
  static bool get isSignedIn {
    try {
      return _client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// The Supabase Auth user id — the `owner_id` every synced row
  /// carries. Null when signed out, or when Supabase never
  /// initialised (see [isSignedIn]).
  static String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static String? get currentUserEmail {
    try {
      return _client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Auth state changes (sign-in, sign-out, token refresh), for the
  /// P5 status UI and later phases.
  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  /// Interactive Google sign-in, then hands the ID token to Supabase.
  /// Throws [SupabaseAuthException] when Google returns no ID token
  /// or Supabase rejects the sign-in.
  static Future<void> signInWithGoogle() async {
    await init();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw SupabaseAuthException(
        'Google sign-in did not return an ID token.',
      );
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Explicit sign-out from both Supabase and Google.
  static Future<void> signOut() async {
    await init();
    await _client.auth.signOut();
    await GoogleSignIn.instance.signOut();
  }
}

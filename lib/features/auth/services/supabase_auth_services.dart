import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:socialnova/core/secrets/app_secrets.dart';
import 'package:socialnova/features/auth/data/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_pkg;
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/utilities/supabase_constants.dart';
import '../data/models/user_data.dart';

class SupabaseAuthServices implements AuthRepository {
  final _supabase = SupabaseProvider.client;

  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;

  supabase_pkg.User? get currentUser => _supabase.auth.currentUser;

  supabase_pkg.Session? get currentSession => _supabase.auth.currentSession;

  Future<AuthResponse> refreshSession() => _supabase.auth.refreshSession();

  Future<void> ensureUserExistsInDb(supabase_pkg.User user) async {
    try {
      final existingUser =
          await _supabase
              .from(SupabaseConstants.users)
              .select()
              .eq(UserColumns.id, user.id)
              .maybeSingle();

      if (existingUser == null) {
        final String userName =
            user.userMetadata?[UserColumns.name] ??
            user.userMetadata?['full_name'] ??
            user.userMetadata?['display_name'] ??
            'Social User';

        await setUserData(userName, user.email ?? '', user.id);
      }
    } catch (e) {
      debugPrint('Error ensuring user exists: $e');
      rethrow;
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) throw Exception('User not found');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      if (response.user == null) throw Exception('User not found');
      // Only write to public.users if the JWT session already exists
      // (i.e. email confirmation is OFF). If confirmation is ON, the row
      // will be inserted on the first auto-login after the user clicks
      // the email link — `ensureUserExistsInDb` runs in the auth listener.
      if (_supabase.auth.currentSession != null) {
        await setUserData(name, email, response.user!.id);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthResponse> signInWithGoogle() async {
    try {
      final webClientId =
          AppSecrets.effectiveGoogleWebClientId.isNotEmpty
              ? AppSecrets.effectiveGoogleWebClientId
              : '548020841452-cvtj4vs047g5acgtsmga02990tfagvg4.apps.googleusercontent.com';

      final iosClientId = defaultTargetPlatform == TargetPlatform.iOS
          ? webClientId
          : null;

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        clientId: iosClientId,
      );
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Sign in aborted by user';
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found';
      }

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Returns the redirect URL Supabase should bounce OAuth providers to.
  /// Uses the deployed API origin in production and the custom scheme on
  /// mobile so app_links can deliver the callback back to the app.
  static String _oauthRedirectTo() {
    if (kIsWeb) {
      // On web, OAuth providers must bounce back to a real https URL.
      // We use the deployed backend as a stable origin; the backend
      // forwards the token to whitelisted web SPA routes.
      return AppSecrets.effectiveApiUrl.isNotEmpty
          ? '${AppSecrets.effectiveApiUrl}/auth/callback'
          : 'https://exwvavqkjrnprbyknoih.supabase.co/auth/v1/callback';
    }
    return 'socialapp://login-callback';
  }

  @override
  Future<void> signInWithFacebook() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _oauthRedirectTo(),
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Facebook Sign-In Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signInWithMicrosoft() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.azure,
        redirectTo: _oauthRedirectTo(),
        scopes: 'openid profile email',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Microsoft Sign-In Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {}
      try {
        // Don't call signOut() on the singleton googleSignIn we built
        // for ID-token sign-in (signOut() opens a Chrome Custom Tab
        // which is undesirable when the user is already gone).
        // Just disconnect so the next googleUser is fetched fresh.
        await GoogleSignIn().disconnect();
      } catch (_) {}
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserData?> getUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response =
          await _supabase.from('users').select().eq('id', user.id).single();
      if (response.keys.isEmpty) {
        throw Exception('Failed to fetch user data');
      }
      return UserData.fromMap(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setUserData(String name, String email, String userId) async {
    try {
      await _supabase.from('users').upsert({
        'name': name,
        'email': email,
        'id': userId,
      });
    } catch (e) {
      debugPrint('Error setting user data: $e');
      rethrow;
    }
  }

  User? fetchRawUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return user;
  }
}

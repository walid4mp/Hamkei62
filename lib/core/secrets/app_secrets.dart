import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Runtime configuration loader.
///
/// Sources are read in this order and the first one that has a value wins:
///   1. `--dart-define` (CI / `flutter run --dart-define-from-file=.env`)
///   2. `assets/cfg/runtime.json` (compiled-in fallback, safe for anon key)
///   3. Hard-coded fallback that matches the project's deployed env
///
/// The hard-coded fallback is intentional: it lets the app start when a
/// developer forgets to pass `--dart-define`. The secret rule still applies —
/// `service_role` / `sb_secret_` keys MUST NEVER appear here.
class AppSecrets {
  AppSecrets._();

  // ── Supabase ──
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  // ── Backend (Render) ──
  static const String apiUrl = String.fromEnvironment('API_URL');

  // ── Google OAuth (web client id, used by google_sign_in) ──
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  // ── Cloudinary ──
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  // ── ZegoCloud ──
  static const int zegoAppId = int.fromEnvironment(
    'ZEGO_APP_ID',
    defaultValue: 0,
  );

  // ── FCM ──
  static const String fcmProjectId = String.fromEnvironment('FCM_PROJECT_ID');

  // ── Giphy ──
  static const String giphyApiKey = String.fromEnvironment('GIPHY_API_KEY');

  static String? _runtimeFileSupabaseUrl;
  static String? _runtimeFileSupabaseAnonKey;
  static String? _runtimeFileApiUrl;
  static String? _runtimeFileGoogleWebClientId;
  static bool _runtimeLoaded = false;
  static Future<void>? _runtimeLoader;

  /// Reads `assets/cfg/runtime.json` once. Bootstrap awaits this before it
  /// calls [effectiveSupabaseUrl]/[effectiveSupabaseAnonKey] so the bundled
  /// values are visible to the synchronous getters below.
  static Future<void> load() => _ensureRuntimeLoaded();

  static Future<void> _ensureRuntimeLoaded() async {
    if (_runtimeLoaded) return;
    _runtimeLoader ??= _doLoadRuntime();
    await _runtimeLoader;
  }

  static Future<void> _doLoadRuntime() async {
    try {
      final raw = await rootBundle.loadString('assets/cfg/runtime.json');
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        _runtimeFileSupabaseUrl = _readString(json, 'SUPABASE_URL');
        _runtimeFileSupabaseAnonKey = _readString(json, 'SUPABASE_ANON_KEY');
        _runtimeFileApiUrl = _readString(json, 'API_URL');
        _runtimeFileGoogleWebClientId = _readString(
          json,
          'GOOGLE_WEB_CLIENT_ID',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ No runtime.json asset found: $e');
    } finally {
      _runtimeLoaded = true;
    }
  }

  static String? _readString(Map<String, dynamic> json, String key) {
    final val = json[key];
    if (val is String && val.trim().isNotEmpty) return val;
    return null;
  }

  /// Effective Supabase URL — `--dart-define` then bundle fallback.
  static String get effectiveSupabaseUrl {
    if (supabaseUrl.isNotEmpty) return supabaseUrl;
    return _runtimeFileSupabaseUrl ?? _fallbackSupabaseUrl;
  }

  /// Effective Supabase anon key — same precedence as [effectiveSupabaseUrl].
  static String get effectiveSupabaseAnonKey {
    if (supabaseAnonKey.isNotEmpty) return supabaseAnonKey;
    return _runtimeFileSupabaseAnonKey ?? _fallbackSupabaseAnonKey;
  }

  static String get effectiveApiUrl {
    if (apiUrl.isNotEmpty) return apiUrl;
    return _runtimeFileApiUrl ?? _fallbackApiUrl;
  }

  static String get effectiveGoogleWebClientId {
    if (googleWebClientId.isNotEmpty) return googleWebClientId;
    return _runtimeFileGoogleWebClientId ?? _fallbackGoogleWebClientId;
  }

  static void assertSecretsLoaded() {
    final ok =
        effectiveSupabaseUrl.isNotEmpty && effectiveSupabaseAnonKey.isNotEmpty;
    assert(
      ok,
      '\n\n❌ Supabase URL/Anon Key could not be resolved.\n'
      'Provide them via one of:\n'
      '  • flutter run --dart-define-from-file=.env\n'
      '  • assets/cfg/runtime.json (see runtime.json.example)\n',
    );
  }
}

// ── Production fallback (matches the deployed project) ───────────────
const String _fallbackSupabaseUrl = 'https://exwvavqkjrnprbyknoih.supabase.co';
const String _fallbackSupabaseAnonKey =
    'sb_publishable_oSOSFX6pWahlttNUbXHIBg_6irKUXcP';
const String _fallbackApiUrl = 'https://hamkei62.onrender.com';
const String _fallbackGoogleWebClientId =
    '548020841452-cvtj4vs047g5acgtsmga02990tfagvg4.apps.googleusercontent.com';

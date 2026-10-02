import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/key_lookup.dart';
import '../l10n/source_index.dart';

/// V93: app locales are now driven by the generated ARB localizations
/// (`lib/l10n/app_*.arb` -> `flutter gen-l10n` -> `AppLocalizations`).
/// There is exactly one translation system: this class only keeps the locale
/// preference and the language names/flags for the picker.
class AppLocale {
  AppLocale._();

  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));

  /// The locales the ARB files define.
  static List<Locale> get supported => AppLocalizations.supportedLocales;

  static const names = <String, String>{
    'ar': 'العربية', 'en': 'English', 'fr': 'Français', 'es': 'Español',
    'tr': 'Türkçe', 'de': 'Deutsch', 'ru': 'Русский', 'pt': 'Português',
  };

  static const flags = <String, String>{
    'ar': '🇩🇿', 'en': '🇬🇧', 'fr': '🇫🇷', 'es': '🇪🇸',
    'tr': '🇹🇷', 'de': '🇩🇪', 'ru': '🇷🇺', 'pt': '🇵🇹',
  };

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString('app_language') ?? 'ar';
    final valid = supported.any((l) => l.languageCode == code) ? code : 'ar';
    locale.value = Locale(valid);
  }

  static Future<void> set(String code) async {
    if (!supported.any((l) => l.languageCode == code)) return;
    locale.value = Locale(code);
    final p = await SharedPreferences.getInstance();
    await p.setString('app_language', code);
  }

  static bool get isRtl => locale.value.languageCode == 'ar';
}

/// Translation adapter. Every call site keeps working, but the strings now come
/// from the ARB files instead of a hand-written map, so there is a single
/// source of truth and adding a language is a matter of adding one .arb file.
class L10n {
  static String language(String code) => AppLocale.names[code] ?? code;
  static String flag(String code) => AppLocale.flags[code] ?? '🌐';

  static AppLocalizations _for(String code) =>
      lookupAppLocalizations(Locale(code));

  /// Looks up a string by its ARB key (e.g. `chooseLanguage`).
  static String text(String key, String code) {
    final resolved = kSourceIndex[key] ?? key;
    if (!kSourceIndex.containsKey(key)) return key;
    return lookupLocalizedKey(_for(code), resolved);
  }

  /// Translates a source string (normally Arabic) into [code].
  /// Unknown strings are returned unchanged rather than faked.
  static String t(String source, [String? code]) {
    final c = code ?? AppLocale.locale.value.languageCode;
    final key = kSourceIndex[source];
    if (key == null) return source;
    if (c == 'ar') return source;
    return lookupLocalizedKey(_for(c), key);
  }
}

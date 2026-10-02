import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:socialnova/core/localization.dart';
import 'package:socialnova/core/nova_gifts.dart';
import 'package:socialnova/l10n/key_lookup.dart';
import 'package:socialnova/l10n/source_index.dart';
import 'package:socialnova/screens/call_history.dart';

void main() {
  group('V93 localization (ARB -> AppLocalizations)', () {
    test('all eight target languages are supported', () {
      final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
      for (final c in ['ar', 'en', 'fr', 'es', 'tr', 'de', 'ru', 'pt']) {
        expect(codes, contains(c), reason: 'missing locale $c');
      }
    });

    test('every ARB key resolves to a non-empty string in every language', () {
      final keys = kSourceIndex.values.toSet();
      expect(keys.length, greaterThan(100));
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        for (final key in keys) {
          final value = lookupLocalizedKey(l, key);
          expect(value.trim().isNotEmpty, isTrue, reason: '$key empty in ${locale.languageCode}');
        }
      }
    });

    test('Arabic resolves to the source text and English to a translation', () {
      expect(L10n.t('الإعدادات', 'ar'), 'الإعدادات');
      expect(L10n.t('الإعدادات', 'en'), 'Settings');
      expect(L10n.t('حفظ', 'fr'), 'Enregistrer');
      expect(L10n.t('حفظ', 'pt'), 'Guardar');
    });

    test('unknown strings are returned unchanged instead of faked', () {
      expect(L10n.t('نص غير مترجم', 'en'), 'نص غير مترجم');
    });

    test('legacy ASCII keys still resolve (settings screen)', () {
      expect(L10n.text('chooseLanguage', 'en'), isNotEmpty);
      expect(L10n.text('chooseLanguage', 'en'), isNot('chooseLanguage'));
      expect(L10n.text('save', 'fr'), 'Enregistrer');
    });

    test('RTL is driven by the locale', () {
      AppLocale.locale.value = const Locale('ar');
      expect(AppLocale.isRtl, isTrue);
      AppLocale.locale.value = const Locale('en');
      expect(AppLocale.isRtl, isFalse);
      AppLocale.locale.value = const Locale('ar');
    });
  });

  group('V93 gift artwork', () {
    NovaGift giftWith(Map<String, dynamic> overrides) => NovaGift.fromMap({
          'slug': 'test_gift',
          'name': 'هدية',
          'emoji': '🎁',
          'priceCoins': 100,
          'rarity': 'RARE',
          'category': 'love',
          'effectKey': 'bloom',
          ...overrides,
        });

    test('a gift without artwork keeps the emoji fallback', () {
      final g = giftWith(const {});
      expect(g.hasArtwork, isFalse);
      expect(g.artworkUrl, '');
    });

    test('a root-relative artwork path becomes an absolute URL', () {
      final g = giftWith(const {'imageUrl': '/admin-assets/gifts/love/test_gift.webp'});
      expect(g.hasArtwork, isTrue);
      expect(g.artworkUrl, startsWith('http'));
      expect(g.artworkUrl, endsWith('/admin-assets/gifts/love/test_gift.webp'));
    });

    test('absolute artwork URLs are kept untouched', () {
      final g = giftWith(const {'imageUrl': 'https://cdn.example.com/g.webp'});
      expect(g.artworkUrl, 'https://cdn.example.com/g.webp');
    });

    test('premium flag is read from the server payload', () {
      expect(giftWith(const {'premium': true}).premium, isTrue);
      expect(giftWith(const {}).premium, isFalse);
    });

    test('the artwork widget falls back to the emoji when there is no image', () {
      const gift = NovaGift(
        slug: 'x', name: 'x', emoji: '🎁', price: 1,
        tier: NovaGiftTier.common, effectKey: 'bloom', soundKey: '',
      );
      expect(const NovaGiftArt(gift: gift).gift.hasArtwork, isFalse);
    });
  });

  group('V93 call duration formatting', () {
    test('zero means an unanswered call', () {
      expect(formatCallDuration(0), '—');
    });

    test('minutes and seconds are padded', () {
      expect(formatCallDuration(9), '0:09');
      expect(formatCallDuration(75), '1:15');
      expect(formatCallDuration(599), '9:59');
    });

    test('hours are included only when needed', () {
      expect(formatCallDuration(3600), '1:00:00');
      expect(formatCallDuration(3725), '1:02:05');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialnova/core/nova_gifts.dart';

void main() {
  group('NovaGiftCatalog', () {
    test('has at least 24 gifts across all four tiers', () {
      expect(NovaGiftCatalog.all.length, greaterThanOrEqualTo(24));
      for (final tier in NovaGiftTier.values) {
        expect(NovaGiftCatalog.forTier(tier), isNotEmpty, reason: 'tier ${tier.key} empty');
      }
    });

    test('no two gifts share an emoji, a name or a slug', () {
      final emojis = NovaGiftCatalog.all.map((g) => g.emoji).toSet();
      final names = NovaGiftCatalog.all.map((g) => g.name).toSet();
      final slugs = NovaGiftCatalog.all.map((g) => g.slug).toSet();
      expect(emojis.length, NovaGiftCatalog.all.length);
      expect(names.length, NovaGiftCatalog.all.length);
      expect(slugs.length, NovaGiftCatalog.all.length);
    });

    test('prices ascend and tier follows price', () {
      for (var i = 1; i < NovaGiftCatalog.all.length; i++) {
        expect(NovaGiftCatalog.all[i].price, greaterThan(NovaGiftCatalog.all[i - 1].price));
      }
      for (final g in NovaGiftCatalog.all) {
        expect(g.tier, NovaGiftCatalog.tierForPrice(g.price));
      }
    });

    test('every gift maps to a bundled sound effect', () {
      for (final g in NovaGiftCatalog.all) {
        final key = NovaGiftCatalog.sfxKeyFor(g.soundKey, g.tier);
        expect(NovaAudioKeys.all, contains(key));
      }
    });

    test('resolve() prefers the known catalog entry', () {
      final resolved = NovaGiftCatalog.resolve({'slug': 'throne', 'name': 'x', 'emoji': '?', 'priceCoins': 1});
      expect(resolved.name, 'عرش');
      expect(resolved.tier, NovaGiftTier.exclusive);
    });
  });

  testWidgets('NovaGiftEffect renders a luxury gift without layout errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(children: [
            NovaGiftEffect(
              emoji: '👑',
              name: 'تاج',
              effectKey: 'crown',
              tier: NovaGiftTier.luxury,
              senderName: 'أم بدر',
              coins: 999,
              duration: Duration(milliseconds: 600),
            ),
          ]),
        ),
      ),
    ));
    expect(find.text('تاج'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('NovaGiftEffect renders a flight gift without layout errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(children: [
            NovaGiftEffect(
              emoji: '🚀',
              name: 'صاروخ',
              effectKey: 'rocket',
              tier: NovaGiftTier.luck,
              duration: Duration(milliseconds: 600),
            ),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
  });
}

/// Mirror of NovaAudio's sfx keys, kept local so the test does not depend on
/// the audio plugin initialising on CI.
class NovaAudioKeys {
  static const all = {'tap', 'common', 'luck', 'luxury', 'exclusive', 'combo', 'join', 'go_live', 'live_end'};
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialnova/core/creator_levels.dart';
import 'package:socialnova/core/message_effects.dart';
import 'package:socialnova/core/nova_gifts.dart';

void main() {
  group('Message effects', () {
    test('the six requested effects exist with unique ids', () {
      expect(kMessageEffects.length, 6);
      expect(kMessageEffects.map((e) => e.id).toSet().length, 6);
      for (final id in ['celebration', 'hearts', 'fire', 'stars', 'snow', 'fireworks']) {
        expect(messageEffectById(id)?.id, id);
      }
      expect(messageEffectById('nope'), isNull);
      expect(messageEffectById(''), isNull);
    });

    testWidgets('every message effect renders and finishes cleanly', (tester) async {
      for (final e in kMessageEffects) {
        var done = false;
        await tester.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(children: [
              NovaMessageEffect(effectId: e.id, onDone: () => done = true),
            ]),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 200));
        expect(done, isTrue, reason: '${e.id} should complete');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Gift motion families', () {
    test('engine animation keys map to the six families', () {
      expect(NovaGiftCatalog.motionFor('crown'), NovaMotion.drop);
      expect(NovaGiftCatalog.motionFor('castle'), NovaMotion.drop);
      expect(NovaGiftCatalog.motionFor('rocket'), NovaMotion.rise);
      expect(NovaGiftCatalog.motionFor('car'), NovaMotion.drive);
      expect(NovaGiftCatalog.motionFor('plane'), NovaMotion.fly);
      expect(NovaGiftCatalog.motionFor('lion'), NovaMotion.shake);
      expect(NovaGiftCatalog.motionFor('rose'), NovaMotion.bloom);
      expect(NovaGiftCatalog.motionFor('unknown-thing'), NovaMotion.bloom);
    });

    test('rarity parsing and colours', () {
      expect(NovaGiftCatalog.rarityFor('MYTHIC'), NovaGiftRarity.mythic);
      expect(NovaGiftCatalog.rarityFor('legendary'), NovaGiftRarity.legendary);
      expect(NovaGiftCatalog.rarityFor(''), NovaGiftRarity.common);
      expect(NovaGiftCatalog.rarityColor(NovaGiftRarity.mythic), isNot(equals(NovaGiftCatalog.rarityColor(NovaGiftRarity.common))));
    });

    test('fromMap keeps engine fields', () {
      final g = NovaGift.fromMap({'slug': 'x_001', 'name': 'تاج', 'emoji': '👑', 'priceCoins': 6999, 'rarity': 'LEGENDARY', 'category': 'luxury', 'effectKey': 'crown', 'effectMs': 4200, 'soundKey': 'exclusive'});
      expect(g.rarity, NovaGiftRarity.legendary);
      expect(g.category, 'luxury');
      expect(g.durationMs, 4200);
      expect(g.motion, NovaMotion.drop);
    });
  });

  group('Creator levels', () {
    test('parses a server level row', () {
      final l = CreatorLevel.fromMap({'key': 'creator', 'label': 'مبدع', 'minFollowers': 1000, 'tier': 2, 'color': '#66BB6A'});
      expect(l.key, 'creator');
      expect(l.label, 'مبدع');
      expect(l.minFollowers, 1000);
    });

    test('falls back safely on bad colour', () {
      final l = CreatorLevel.fromMap({'key': 'x', 'label': 'x', 'minFollowers': 0, 'tier': 0, 'color': 'not-a-colour'});
      expect(l.color, isNotNull);
    });
  });
}

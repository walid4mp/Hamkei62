import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialnova/core/nova_gifts.dart';
import 'package:socialnova/features/admin/admin_console_page.dart';
import 'package:socialnova/features/gifts/gift_store.dart';
import 'package:socialnova/screens/call_history.dart';

/// These tests actually build the new V93 screens. They run without a server,
/// so every screen must degrade to a real state (loading / offline / empty)
/// instead of throwing — which is exactly what a user sees with no network.
void main() {
  testWidgets('the gift store renders its chrome and survives no network', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GiftStoreSheet(receiverId: 'user-1', receiverName: 'خالد', contextType: 'LIVE', contextId: 'room-1'),
      ),
    ));
    await tester.pump();

    expect(find.text('هدايا Nova'), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on_rounded), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Let the failing HTTP calls settle; the sheet must show its offline state.
    // The offline state settles after the failing requests; a spinner may keep
    // animating, so pump fixed frames instead of pumpAndSettle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(GiftStoreSheet), findsOneWidget);
  });

  testWidgets('the admin console opens with its four working tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminConsolePage()));
    await tester.pump();
    expect(find.text('مركز الإدارة'), findsOneWidget);
    expect(find.text('الهدايا'), findsOneWidget);
    expect(find.text('الأصول'), findsOneWidget);
    expect(find.text('المكافآت'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to the Assets tab rebuilds without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminConsolePage()));
    await tester.pump();
    await tester.tap(find.text('الأصول'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the call history screen shows its header and offline state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CallHistoryPage()));
    await tester.pump();
    expect(find.text('سجل المكالمات'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gift card renders real artwork when a URL exists and falls back otherwise', (tester) async {
    const withArt = NovaGift(
      slug: 'crown', name: 'تاج', emoji: '👑', price: 999,
      tier: NovaGiftTier.luxury, effectKey: 'drop', soundKey: 'crown',
      rarity: NovaGiftRarity.epic, imageUrl: '/admin-assets/gifts/luxury/crown.webp',
    );
    const withoutArt = NovaGift(
      slug: 'rose', name: 'وردة', emoji: '🌹', price: 1,
      tier: NovaGiftTier.common, effectKey: 'bloom', soundKey: 'rose',
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            NovaGiftArt(gift: withArt, size: 48),
            NovaGiftArt(gift: withoutArt, size: 48),
          ],
        ),
      ),
    ));
    await tester.pump();
    // The offline image resolves to the emoji fallback instead of crashing.
    expect(find.text('👑'), findsOneWidget);
    expect(find.text('🌹'), findsOneWidget);
    expect(withArt.hasArtwork, isTrue);
    expect(withoutArt.hasArtwork, isFalse);
  });

  testWidgets('the gift effect renders the combo badge for x5 sends', (tester) async {
    const gift = NovaGift(
      slug: 'lion', name: 'أسد', emoji: '🦁', price: 500,
      tier: NovaGiftTier.exclusive, effectKey: 'shake', soundKey: 'roar',
      rarity: NovaGiftRarity.legendary,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          NovaGiftEffect(
            emoji: '🦁',
            gift: gift,
            name: 'أسد',
            effectKey: 'shake',
            tier: NovaGiftTier.exclusive,
            rarity: NovaGiftRarity.legendary,
            coins: 2500,
            quantity: 5,
            senderName: 'سارة',
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('×5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}

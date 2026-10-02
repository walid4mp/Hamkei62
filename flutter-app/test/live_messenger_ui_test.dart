import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialnova/core/nova_ui.dart';
import 'package:socialnova/core/theme.dart';

/// Regression net for the V88 Live + Messenger design layer.
/// Every widget is pumped inside a narrow, RTL, Arabic phone-sized surface so
/// overflows and direction bugs fail the test instead of shipping.
Widget harness(Widget child, {double width = 390}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SN.theme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: SN.bg0,
          body: SizedBox(width: width, height: 780, child: child),
        ),
      ),
    );

void main() {
  testWidgets('Live discovery tile renders with host, viewers and LIVE flag', (tester) async {
    await tester.pumpWidget(harness(
      NovaLiveTile(
        title: 'جلسة تصميم مباشرة',
        hostName: 'سارة أحمد',
        viewers: 12400,
        gradientSeed: 2,
        onTap: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('جلسة تصميم مباشرة'), findsOneWidget);
    expect(find.text('سارة أحمد'), findsOneWidget);
    expect(find.text('12.4K'), findsOneWidget);
    expect(find.text('مباشر'), findsOneWidget);
  });

  testWidgets('Live HUD: host chip, badge, viewer pill, stats and comment rail', (tester) async {
    await tester.pumpWidget(harness(
      Stack(children: [
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(children: [
            const NovaLiveBadge(),
            const SizedBox(width: 6),
            const NovaStatPill(icon: Icons.visibility_rounded, text: '327'),
            const Spacer(),
            NovaGlassIcon(icon: Icons.ios_share_rounded, onTap: () {}),
          ]),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 90,
          child: Column(children: const [
            NovaCommentTile(username: 'منى', body: 'الجودة ممتازة اليوم', onReply: null),
            NovaCommentTile(username: 'عمر', body: 'رد على سؤالك السابق', replyToName: 'منى', pinned: true),
          ]),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 12,
          child: Row(children: [
            const Expanded(child: NovaGlass(radius: NovaTokens.rPill, child: SizedBox(height: 44, width: 180))),
            const SizedBox(width: 6),
            const NovaStatPill(icon: Icons.favorite_rounded, text: '1.2K', gradient: SN.gradPink),
            const SizedBox(width: 6),
            const NovaStatPill(icon: Icons.card_giftcard_rounded, text: '24'),
          ]),
        ),
      ]),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('منى'), findsOneWidget);
    expect(find.text('الجودة ممتازة اليوم'), findsOneWidget);
    expect(find.text('رد على منى'), findsOneWidget);
    expect(find.text('327'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
  });

  testWidgets('Rising hearts layer repaints on burst without layout errors', (tester) async {
    final burst = ValueNotifier<int>(0);
    await tester.pumpWidget(harness(NovaHeartsOverlay(burst: burst)));
    await tester.pump();
    burst.value++;
    await tester.pump(const Duration(milliseconds: 400));
    burst.value++;
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    burst.dispose();
  });

  testWidgets('Messenger inbox row shows preview, stamp and unread counter', (tester) async {
    await tester.pumpWidget(harness(Column(children: [
      NovaChatRow(
        name: 'الفريق التقني',
        username: 'team',
        preview: 'باقي مراجعة شاشة الليف',
        timeLabel: '12:04',
        unread: 3,
        typing: true,
        onTap: () {},
      ),
      NovaChatRow(
        name: 'سارة أحمد',
        username: 'sara',
        preview: 'وصلني التحديث، شكرًا!',
        timeLabel: 'أمس',
        unread: 0,
        onTap: () {},
      ),
    ])));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الفريق التقني'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('يكتب الآن…'), findsOneWidget);
    expect(find.text('وصلني التحديث، شكرًا!'), findsOneWidget);
    expect(find.text('أمس'), findsOneWidget);
  });

  testWidgets('Messenger conversation: tail bubbles, voice note, ticks, composer', (tester) async {
    await tester.pumpWidget(harness(Column(children: [
      Expanded(
        child: ListView(children: [
          Align(
            alignment: Alignment.centerRight,
            child: NovaBubble(mine: false, child: const Text('مرحبًا، هل جهزت شاشة الليف؟')),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: NovaBubble(
              mine: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('جهزت المشاهدة والاستكشاف.'),
                Row(mainAxisSize: MainAxisSize.min, children: const [
                  Padding(padding: EdgeInsets.only(left: 4), child: NovaTicks(read: true, delivered: true)),
                ]),
              ]),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: NovaBubble(mine: false, child: const NovaVoiceNote(mine: false, seconds: 12)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: NovaBubble(mine: false, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: const NovaTypingDots()),
          ),
        ]),
      ),
      NovaComposer(
        primaryIcon: Icons.send_rounded,
        onPrimary: () {},
        field: const TextField(decoration: InputDecoration(hintText: 'رسالة…', border: InputBorder.none, isDense: true)),
        leading: [IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline))],
        secondary: IconButton(onPressed: () {}, icon: const Icon(Icons.mic_none_rounded)),
      ),
    ])));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('مرحبًا، هل جهزت شاشة الليف؟'), findsOneWidget);
    expect(find.text('جهزت المشاهدة والاستكشاف.'), findsOneWidget);
    expect(find.text('00:12'), findsOneWidget);
    expect(find.byType(NovaTicks), findsOneWidget);
    expect(find.byType(NovaTypingDots), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Segmented tabs switch selection', (tester) async {
    var selected = 'الكل';
    await tester.pumpWidget(harness(
      NovaTabs<String>(
        values: const ['الكل', 'غير مقروءة', 'مجموعات'],
        labels: const ['الكل', 'غير مقروءة', 'مجموعات'],
        selected: selected,
        onChanged: (v) => selected = v,
      ),
    ));
    await tester.tap(find.text('مجموعات'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(selected, 'مجموعات');
  });
}

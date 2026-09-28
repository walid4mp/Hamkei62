import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/api.dart';
import '../core/nova_audio.dart';
import '../core/nova_gifts.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _future;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool buying = false;

  @override
  void initState() {
    super.initState();
    _future = Api.wallet();
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (_) {});
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => buying = true);
        continue;
      }
      if (purchase.status == PurchaseStatus.error || purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() => buying = false);
          toast(context, purchase.status == PurchaseStatus.canceled ? 'تم إلغاء الشراء.' : 'تعذر إتمام عملية الشراء.');
        }
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        try {
          final txId = (purchase.purchaseID?.trim().isNotEmpty == true)
              ? purchase.purchaseID!.trim()
              : 'store-${DateTime.now().microsecondsSinceEpoch}';
          final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';
          await Api.purchaseIntent(purchase.productID, platform, txId);
          await Api.verifyPurchase(
            transactionId: txId,
            productId: purchase.productID,
            platform: platform,
            purchaseToken: purchase.verificationData.serverVerificationData,
          );
          if (mounted) {
            setState(() {
              buying = false;
              _future = Api.wallet();
            });
            toast(context, 'تمت إضافة NovaCoins إلى محفظتك ✨');
          }
        } catch (e) {
          if (mounted) {
            setState(() => buying = false);
            toast(context, e.toString().replaceFirst('Exception: ', ''));
          }
        } finally {
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
        }
      }
    }
  }

  Future<void> _buy(Map<String, dynamic> pkg) async {
    if (buying) return;
    final productId = '${pkg['productId']}';
    setState(() => buying = true);
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) throw Exception('متجر المشتريات غير متاح على هذا الجهاز.');
      final response = await InAppPurchase.instance.queryProductDetails({productId});
      if (response.error != null) throw Exception(response.error!.message);
      if (response.productDetails.isEmpty) {
        throw Exception('هذه الباقة غير منشورة بعد في Google Play / App Store.');
      }
      final product = response.productDetails.first;
      final ok = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: true,
      );
      if (!ok && mounted) setState(() => buying = false);
    } catch (e) {
      if (mounted) {
        setState(() => buying = false);
        toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _withdraw(Map<String, dynamic> data) async {
    final wallet = Map<String, dynamic>.from((data['wallet'] ?? {}) as Map);
    final available = ((wallet['withdrawableCoins'] ?? 0) as num).toInt();
    final currency = Map<String,dynamic>.from((data['currency'] ?? {}) as Map);
    final minCoins = ((currency['minWithdrawCoins'] ?? 1000) as num).toInt();
    final feeRate = ((currency['withdrawalFeeRate'] ?? .10) as num).toDouble();
    final coinsCtrl = TextEditingController(text: available >= minCoins ? available.toString() : '');
    final destinationCtrl = TextEditingController();
    String method = 'PAYPAL';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final coins = int.tryParse(coinsCtrl.text.trim()) ?? 0;
          final net = coins > 0 ? ((coins * (1 - feeRate)) / 100).toStringAsFixed(2) : '0.00';
          return Dialog(
            backgroundColor: SN.bg1,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.payments_rounded, color: Colors.white)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('سحب الأرباح', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('تحويل الرصيد القابل للسحب', style: TextStyle(color: SN.textMut, fontSize: 11))])),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: Colors.white), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('الرصيد القابل للسحب', style: TextStyle(color: Colors.white70, fontSize: 11)), Text('$available NVC', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))]))])),
                const SizedBox(height: 14),
                TextField(controller: coinsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setLocal(() {}), decoration: InputDecoration(labelText: 'عدد NovaCoins', hintText: 'الحد الأدنى $minCoins', prefixIcon: const Icon(Icons.toll_rounded), suffixIcon: available >= minCoins ? IconButton(onPressed: () { coinsCtrl.text = '$available'; setLocal(() {}); }, icon: const Icon(Icons.all_inclusive_rounded)) : null)),
                const SizedBox(height: 12),
                const Text('طريقة الاستلام', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final x in const [['PAYPAL','PayPal',Icons.account_balance_wallet_rounded],['BANK','حساب بنكي',Icons.account_balance_rounded],['OTHER','طريقة أخرى',Icons.more_horiz_rounded]]) ChoiceChip(label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(x[2] as IconData, size: 17), const SizedBox(width: 6), Text(x[1] as String)]), selected: method == x[0], onSelected: (_) => setLocal(() => method = x[0] as String)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: destinationCtrl, decoration: const InputDecoration(labelText: 'بيانات الاستلام', hintText: 'البريد أو رقم الحساب', prefixIcon: Icon(Icons.alternate_email_rounded))),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: SN.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: SN.strokeSoft)), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 18, color: SN.textMut), const SizedBox(width: 8), Expanded(child: Text('بعد رسم السحب ${(feeRate * 100).round()}% ستحصل تقريبًا على $net. تتم مراجعة الطلب وفق شروط السحب.', style: TextStyle(fontSize: 11, color: SN.textSec)))])),
                const SizedBox(height: 16),
                Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: () async {
                  final n = int.tryParse(coinsCtrl.text.trim()) ?? 0;
                  if (n < minCoins || n > available || destinationCtrl.text.trim().length < 4) { toast(ctx, 'تحقق من عدد العملات وبيانات الاستلام.'); return; }
                  try { final r = await Api.withdraw(coins: n, method: method, destination: destinationCtrl.text.trim()); if (!ctx.mounted) return; Navigator.pop(ctx); setState(() => _future = Api.wallet()); final cents = ((r['netCashCents'] ?? 0) as num).toInt(); toast(context, 'تم إنشاء طلب السحب بقيمة ${(cents / 100).toStringAsFixed(2)} USD.'); } catch (e) { toast(ctx, e.toString().replaceFirst('Exception: ', '')); }
                }, icon: const Icon(Icons.send_rounded), label: const Text('إرسال الطلب')))]),
              ]),
            ),
          );
        },
      ),
    );
    coinsCtrl.dispose();
    destinationCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('محفظة NovaCoin')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''), icon: Icons.account_balance_wallet_outlined);
          final data = snap.data ?? {};
          final w = Map<String, dynamic>.from((data['wallet'] ?? {}) as Map);
          final packages = List<dynamic>.from(data['packages'] ?? const []);
          final transactions = List<dynamic>.from(data['transactions'] ?? const []);
          final balance = ((w['coinBalance'] ?? 0) as num).toInt();
          final bonus = ((w['bonusCoins'] ?? 0) as num).toInt();
          final purchased = ((w['purchasedCoins'] ?? 0) as num).toInt();
          final withdrawable = ((w['withdrawableCoins'] ?? 0) as num).toInt();
          final fee = (((data['currency'] ?? {})['withdrawalFeeRate'] ?? .10) as num) * 100;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = Api.wallet()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [
                _balanceCard(balance, bonus, purchased, withdrawable),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _quick('شراء NovaCoins', Icons.add_circle_outline, () => _showPackages(packages))),
                  const SizedBox(width: 10),
                  Expanded(child: _quick('سحب الأرباح', Icons.payments_outlined, () => _withdraw(data))),
                ]),
                const SizedBox(height: 18),
                const SectionTitle('باقات NovaCoin'),
                for (final p in packages) _packageTile(Map<String, dynamic>.from(p as Map)),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Text('اقتصاد التطبيق: مستلم الهدية يحصل على ${((data['currency']?['creatorShare'] ?? .70) * 100).round()}% من قيمة الهدية كرصيد قابل للسحب، ورسوم السحب الحالية $fee%.', style: TextStyle(fontSize: 12, color: SN.textSec)),
                ),
                const SizedBox(height: 12),
                const SectionTitle('آخر الحركات'),
                if (transactions.isEmpty) const EmptyState(text: 'لا توجد حركات بعد', icon: Icons.receipt_long_outlined),
                for (final x in transactions) _transactionTile(Map<String, dynamic>.from(x as Map)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceCard(int balance, int bonus, int purchased, int withdrawable) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: SN.grad,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NovaCoin Wallet', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('🎁 مجاني: $bonus  •  💳 مشتراة: $purchased  •  💰 قابل للسحب: $withdrawable', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          const Text('المكافآت المجانية للاستخدام داخل التطبيق وإرسال الهدايا فقط، ولا يمكن سحبها نقدًا. العملات المشتراة منفصلة ويمكن استخدامها للإرسال، والأرباح المؤهلة من الهدايا الممولة بالعملات المشتراة تدخل الرصيد القابل للسحب وفق شروط التطبيق.', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),
          Text('$balance NVC', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('قابل للسحب: $withdrawable NVC', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _quick(String title, IconData icon, VoidCallback onTap) => GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: EdgeInsets.all(14), child: Column(children: [Icon(icon, color: SN.violet), SizedBox(height: 6), Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]))),
      );

  Widget _packageTile(Map<String, dynamic> p) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: SN.violet.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.monetization_on_outlined, color: SN.violet)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['label']}', style: TextStyle(fontWeight: FontWeight.w800)), Text('${((p['amountCents'] ?? 0) as num) / 100} USD', style: TextStyle(color: SN.textSec, fontSize: 12))])),
          FilledButton(onPressed: buying ? null : () => _buy(p), child: const Text('شراء')),
        ]),
      );

  Widget _transactionTile(Map<String, dynamic> x) {
    final coins = ((x['coins'] ?? 0) as num).toInt();
    final positive = coins > 0 || '${x['type']}' == 'GIFT_RECEIVED';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(backgroundColor: positive ? SN.green.withValues(alpha: .12) : SN.pink.withValues(alpha: .12), child: Icon(positive ? Icons.arrow_downward : Icons.arrow_upward, color: positive ? SN.green : SN.pink, size: 18)),
      title: Text('${x['description'] ?? x['type']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      trailing: Text('${coins > 0 ? '+' : ''}$coins NVC', style: TextStyle(color: positive ? SN.green : SN.pink, fontWeight: FontWeight.w800)),
    );
  }

  void _showPackages(List<dynamic> packages) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: SN.bg1,
        showDragHandle: true,
        builder: (_) => SafeArea(child: ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, children: [const Text('اختر باقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10), for (final p in packages) _packageTile(Map<String, dynamic>.from(p as Map))])),
      );
}

Future<void> showGiftPicker(
  BuildContext context, {
  required String receiverId,
  required String contextType,
  String contextId = '',
  String? receiverName,
}) async {
  try {
    final results = await Future.wait([Api.gifts(), Api.wallet()]);
    final rawGifts = List<dynamic>.from(results[0] as List);
    final wallet = Map<String, dynamic>.from(results[1] as Map);
    // Server catalog wins; the bundled catalog is the offline fallback so the
    // sheet is never an empty grid.
    final gifts = rawGifts.isNotEmpty
        ? rawGifts.map((e) => NovaGiftCatalog.resolve(Map<String, dynamic>.from(e as Map))).toList()
        : List<NovaGift>.from(NovaGiftCatalog.all);
    // Keep the original server ids for the send call, aligned by index.
    final ids = rawGifts.isNotEmpty
        ? rawGifts.map((e) => '${(e as Map)['id'] ?? ''}').toList()
        : List<String>.from(NovaGiftCatalog.all.map((g) => g.slug));
    if (!context.mounted) return;
    var selected = -1;
    var sending = false;
    var categoryFilter = ''; // '' = all categories
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final categories = <String>['', ...{for (final g in gifts) if (g.category.isNotEmpty) g.category}];
        final visible = <int>[
          for (var i = 0; i < gifts.length; i++)
            if (categoryFilter.isEmpty || gifts[i].category == categoryFilter) i
        ];
        final selectedGift = selected >= 0 && selected < gifts.length ? gifts[selected] : null;
        return Container(
          height: MediaQuery.of(ctx).size.height * .78,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0B12),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(child: Column(children: [
            Container(width: 44, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
            Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 10), child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.card_giftcard_rounded, color: Colors.white)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إرسال هدية${receiverName == null ? '' : ' إلى $receiverName'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                Text('رصيدك ${wallet['coinBalance'] ?? 0} NovaCoins', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ])),
              IconButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())); }, icon: const Icon(Icons.add_circle_outline, color: SN.cyan)),
            ])),
            if (selectedGift != null) Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(gradient: LinearGradient(colors: [SN.violet.withValues(alpha: .28), SN.cyan.withValues(alpha: .12)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)), child: Row(children: [Text(selectedGift.emoji, style: const TextStyle(fontSize: 30)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(selectedGift.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), Text('${selectedGift.rarity.label} • ${selectedGift.price} NVC', style: const TextStyle(color: Colors.white60, fontSize: 11))])), FilledButton(onPressed: sending ? null : () async { setSheet(() => sending = true); try { await Api.sendGift(receiverId: receiverId, giftId: ids[selected], context: contextType, contextId: contextId); playGiftSound(selectedGift.soundKey, selectedGift.tier); if (ctx.mounted) { Navigator.pop(ctx); toast(context, 'تم إرسال ${selectedGift.emoji} ${selectedGift.name} ✨'); } } catch (e) { if (ctx.mounted) { setSheet(() => sending = false); toast(ctx, e.toString().replaceFirst('Exception: ', '')); } } }, child: Text(sending ? '...' : 'إرسال'))])),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final c in categories)
                    Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(c.isEmpty ? 'الكل' : NovaGiftCatalog.categoryLabel(c)), selected: categoryFilter == c, onSelected: (_) => setSheet(() => categoryFilter = c))),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(18, 6, 18, 6), child: Align(alignment: AlignmentDirectional.centerStart, child: Text('الهدايا', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)))),
            Expanded(child: GridView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 18), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .82), itemCount: visible.length, itemBuilder: (_, vi) { final i = visible[vi]; final g = gifts[i]; final active = i == selected; final accent = NovaGiftCatalog.rarityColor(g.rarity); return GestureDetector(onTap: () { setSheet(() => selected = active ? -1 : i); NovaAudio.i.playGiftSfx(g.tier.key); }, child: AnimatedContainer(duration: const Duration(milliseconds: 160), decoration: BoxDecoration(gradient: active ? LinearGradient(colors: [accent.withValues(alpha: .40), SN.pink.withValues(alpha: .18)]) : null, color: active ? null : const Color(0xFF12141D), borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? accent.withValues(alpha: .85) : Colors.white10), boxShadow: active ? [BoxShadow(color: accent.withValues(alpha: .20), blurRadius: 16)] : null), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(g.emoji, style: TextStyle(fontSize: active ? 38 : 32)), const SizedBox(height: 5), Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${g.price}', style: TextStyle(color: active ? accent : Colors.white54, fontSize: 9, fontWeight: FontWeight.w800)), Text(g.rarity.label, style: TextStyle(color: accent.withValues(alpha: .9), fontSize: 8, fontWeight: FontWeight.w800))]))); })),
          ])),
        );
      }),
    );
  } catch (e) {
    if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
  }
}


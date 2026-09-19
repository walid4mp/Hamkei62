import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/api.dart';
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
    final minCoins = ((data['currency'] ?? {})['minWithdrawCoins'] ?? 1000) as num;
    final coinsCtrl = TextEditingController(text: available >= minCoins ? available.toString() : '');
    final destinationCtrl = TextEditingController();
    String method = 'PAYPAL';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('سحب من المحفظة'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text('الرصيد القابل للسحب: $available NVC'),
                const SizedBox(height: 12),
                TextField(
                  controller: coinsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد NovaCoins'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: method,
                  items: const [
                    DropdownMenuItem(value: 'PAYPAL', child: Text('PayPal')),
                    DropdownMenuItem(value: 'BANK', child: Text('حساب بنكي')),
                    DropdownMenuItem(value: 'OTHER', child: Text('طريقة أخرى')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? 'PAYPAL'),
                  decoration: const InputDecoration(labelText: 'طريقة الاستلام'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: destinationCtrl,
                  decoration: const InputDecoration(labelText: 'بيانات الاستلام'),
                ),
                const SizedBox(height: 10),
                const Text('يُخصم رسم السحب من قيمة الرصيد قبل التحويل النقدي.', style: TextStyle(fontSize: 11, color: SN.textMut)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final coins = int.tryParse(coinsCtrl.text.trim()) ?? 0;
                if (coins <= 0 || destinationCtrl.text.trim().length < 4) {
                  toast(ctx, 'أدخل البيانات بشكل صحيح.');
                  return;
                }
                try {
                  final r = await Api.withdraw(coins: coins, method: method, destination: destinationCtrl.text.trim());
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  setState(() => _future = Api.wallet());
                  final cents = ((r['netCashCents'] ?? 0) as num).toInt();
                  toast(context, 'تم إنشاء طلب السحب بقيمة ${(cents / 100).toStringAsFixed(2)} USD.');
                } catch (e) {
                  toast(ctx, e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
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
                  child: Text('اقتصاد التطبيق: مستلم الهدية يحصل على ${((data['currency']?['creatorShare'] ?? .70) * 100).round()}% من قيمة الهدية كرصيد قابل للسحب، ورسوم السحب الحالية $fee%.', style: const TextStyle(fontSize: 12, color: SN.textSec)),
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
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Icon(icon, color: SN.violet), const SizedBox(height: 6), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]))),
      );

  Widget _packageTile(Map<String, dynamic> p) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: SN.violet.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.monetization_on_outlined, color: SN.violet)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['label']}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('${((p['amountCents'] ?? 0) as num) / 100} USD', style: const TextStyle(color: SN.textSec, fontSize: 12))])),
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
    final gifts = await Api.gifts();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('إرسال هدية${receiverName == null ? '' : ' إلى $receiverName'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final g in gifts) _GiftTile(gift: Map<String, dynamic>.from(g as Map), onTap: () async {
                try {
                  await Api.sendGift(receiverId: receiverId, giftId: '${g['id']}', context: contextType, contextId: contextId);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  toast(context, 'تم إرسال ${g['emoji']} بنجاح ✨');
                } catch (e) {
                  toast(ctx, e.toString().replaceFirst('Exception: ', ''));
                }
              })],
            ),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())); }, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('فتح المحفظة وشراء NovaCoins')),
          ]),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.gift, required this.onTap});
  final Map<String, dynamic> gift;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(margin: const EdgeInsets.all(5), decoration: BoxDecoration(color: SN.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: SN.strokeSoft)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${gift['emoji']}', style: const TextStyle(fontSize: 30)), const SizedBox(height: 4), Text('${gift['name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), Text('${gift['priceCoins']} NVC', style: const TextStyle(fontSize: 10, color: SN.cyan))])));
}

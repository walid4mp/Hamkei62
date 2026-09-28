import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/nova_audio.dart';
import '../../core/nova_gifts.dart';
import '../../core/theme.dart';

/// V93 — the new Nova gift store.
///
/// Rebuilt as real Flutter widgets (neon/glow cards, rarity rings, XP bar,
/// tabs, preview, combos) instead of the old flat emoji grid. It reads the
/// server catalog (`/api/gifts/catalog`, falling back to `/api/wallet/gifts`),
/// so an admin can add or disable a gift without a new app release.
Future<Map<String, dynamic>?> showGiftStore(
  BuildContext context, {
  required String receiverId,
  String receiverName = '',
  String contextType = 'LIVE',
  String contextId = '',
  String title = 'هدايا Nova',
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GiftStoreSheet(
      receiverId: receiverId,
      receiverName: receiverName,
      contextType: contextType,
      contextId: contextId,
      title: title,
    ),
  );
}

class GiftStoreSheet extends StatefulWidget {
  const GiftStoreSheet({
    super.key,
    required this.receiverId,
    this.receiverName = '',
    this.contextType = 'LIVE',
    this.contextId = '',
    this.title = 'هدايا Nova',
  });

  final String receiverId;
  final String receiverName;
  final String contextType;
  final String contextId;
  final String title;

  @override
  State<GiftStoreSheet> createState() => _GiftStoreSheetState();
}

class _GiftStoreSheetState extends State<GiftStoreSheet> {
  List<NovaGift> _gifts = const [];
  List<Map<String, dynamic>> _categories = const [];
  bool _loading = true;
  String? _error;
  String _tab = 'all';
  int _selected = -1;
  int _quantity = 1;
  int _coins = 0;
  int _xp = 0;
  int _level = 1;
  double _xpProgress = 0;
  bool _sending = false;

  static const _fallbackTabs = <Map<String, dynamic>>[
    {'key': 'all', 'labelAr': 'الكل'},
    {'key': 'COMMON', 'labelAr': 'عادية'},
    {'key': 'RARE', 'labelAr': 'نادرة'},
    {'key': 'EPIC', 'labelAr': 'ملحمية'},
    {'key': 'LEGENDARY', 'labelAr': 'أسطورية'},
    {'key': 'MYTHIC', 'labelAr': 'خرافية'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Catalog + wallet + XP in parallel; each degrades on its own.
      final results = await Future.wait<dynamic>([
        Api.giftCatalog().catchError((_) => <String, dynamic>{}),
        Api.wallet().catchError((_) => <String, dynamic>{}),
        Api.giftXp().catchError((_) => <String, dynamic>{}),
      ]);
      final catalog = results[0] as Map<String, dynamic>;
      final wallet = results[1] as Map<String, dynamic>;
      final xp = results[2] as Map<String, dynamic>;

      var raw = (catalog['gifts'] as List?) ?? const [];
      if (raw.isEmpty) {
        raw = await Api.gifts().catchError((_) => <dynamic>[]);
      }
      final gifts = raw.map((e) => NovaGiftCatalog.resolve(Map<String, dynamic>.from(e as Map))).toList();
      final cats = ((catalog['categories'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final walletRow = wallet['wallet'] is Map ? Map<String, dynamic>.from(wallet['wallet'] as Map) : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _gifts = gifts;
        _categories = cats.where((c) => c['kind'] != 'SYSTEM' || c['key'] == 'all').toList();
        _coins = (walletRow['coinBalance'] as num?)?.toInt() ?? 0;
        _xp = (xp['xp'] as num?)?.toInt() ?? 0;
        _level = (xp['level'] as num?)?.toInt() ?? 1;
        _xpProgress = ((xp['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  List<NovaGift> get _visible {
    if (_tab == 'all') return _gifts;
    if (_tab == 'new') return _gifts.take(24).toList();
    const rarities = ['COMMON', 'RARE', 'EPIC', 'LEGENDARY', 'MYTHIC'];
    if (rarities.contains(_tab)) {
      return _gifts.where((g) => g.rarity.key == _tab).toList();
    }
    return _gifts.where((g) => g.category == _tab).toList();
  }

  List<Map<String, dynamic>> get _tabs {
    final base = _categories.isEmpty ? _fallbackTabs : _categories;
    final themes = <String>{for (final g in _gifts) if (g.category.isNotEmpty) g.category};
    return [
      ...base,
      {'key': 'new', 'labelAr': 'جديد'},
      ...themes.map((t) => {'key': t, 'labelAr': NovaGiftCatalog.categoryLabel(t)}),
    ];
  }

  Future<void> _preview(NovaGift gift) async {
    playGiftSound(gift.soundKey, gift.tier);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .86),
      builder: (ctx) => Stack(
        children: [
          NovaGiftEffect(
            emoji: gift.emoji,
            gift: gift,
            name: gift.name,
            effectKey: gift.effectKey,
            tier: gift.tier,
            rarity: gift.rarity,
            coins: gift.price,
            senderName: 'معاينة',
            hostName: widget.receiverName,
            duration: const Duration(milliseconds: 2600),
            onDone: () {
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
            child: const Center(
              child: Text('معاينة — لم تُخصم أي عملات',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_selected < 0 || _selected >= _visible.length) return;
    final gift = _visible[_selected];
    final total = gift.price * _quantity;
    if (total > _coins) {
      _snack('رصيدك غير كافٍ — تحتاج $total NVC');
      return;
    }
    setState(() => _sending = true);
    final key = 'gift-${DateTime.now().microsecondsSinceEpoch}-${gift.slug}';
    try {
      final res = await Api.sendGift(
        receiverId: widget.receiverId,
        giftId: '${_giftId(gift)}',
        context: widget.contextType,
        contextId: widget.contextId,
        quantity: _quantity,
        idempotencyKey: key,
      );
      playGiftSound(gift.soundKey, gift.tier);
      if (!mounted) return;
      Navigator.of(context).pop({
        ...gift.toMap(),
        'coins': total,
        'quantity': _quantity,
        'transactionId': '${res['id'] ?? ''}',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _coins = math.max(0, _coins);
      });
      _snack('تعذّر الإرسال: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// The server id for a gift (the catalog payload keeps it); falls back to the
  /// slug for the bundled offline catalog.
  String _giftId(NovaGift gift) => gift.serverId.isNotEmpty ? gift.serverId : gift.slug;

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selectedGift = _selected >= 0 && _selected < visible.length ? visible[_selected] : null;
    return Container(
      height: MediaQuery.of(context).size.height * .88,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1733), Color(0xFF050817)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          _header(selectedGift),
          _xpBar(),
          _tabStrip(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorState()
                    : visible.isEmpty
                        ? const Center(child: Text('لا توجد هدايا في هذا التبويب', style: TextStyle(color: Colors.white70)))
                        : _grid(visible),
          ),
          if (selectedGift != null) _sendBar(selectedGift),
        ],
      ),
    );
  }

  Widget _header(NovaGift? selected) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(gradient: SN.gradPink, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(
                    widget.receiverName.isEmpty ? '${_gifts.length} هدية متاحة' : 'إلى ${widget.receiverName}',
                    style: const TextStyle(color: SN.textMut, fontSize: 11),
                  ),
                ],
              ),
            ),
            _coinPill(),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _coinPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SN.gold.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SN.gold.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded, size: 16, color: SN.gold),
            const SizedBox(width: 6),
            Text('$_coins', style: const TextStyle(color: SN.gold, fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _xpBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: SN.grad,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('مستوى الداعم $_level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _xpProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(SN.cyan),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$_xp XP', style: const TextStyle(color: SN.textMut, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _tabStrip() => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final t = _tabs[i];
            final key = '${t['key']}';
            final active = key == _tab;
            return GestureDetector(
              onTap: () => setState(() {
                _tab = key;
                _selected = -1;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active ? SN.grad : null,
                  color: active ? null : Colors.white.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? Colors.transparent : Colors.white12),
                ),
                child: Text(
                  '${t['labelAr'] ?? key}',
                  style: TextStyle(
                    color: active ? Colors.white : SN.textSec,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _errorState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );

  Widget _grid(List<NovaGift> visible) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: .78,
        ),
        itemCount: visible.length,
        itemBuilder: (_, i) => _GiftCard(
          gift: visible[i],
          active: i == _selected,
          onTap: () {
            NovaAudio.i.playGiftSfx(visible[i].tier.key);
            setState(() {
              _selected = i == _selected ? -1 : i;
              _quantity = 1;
            });
          },
          onPreview: () => _preview(visible[i]),
        ),
      );

  Widget _sendBar(NovaGift gift) {
    final total = gift.price * _quantity;
    final affordable = total <= _coins;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          NovaGiftArt(gift: gift, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(gift.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                Text('${gift.rarity.label} • $total NVC',
                    style: TextStyle(color: NovaGiftCatalog.rarityColor(gift.rarity), fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          _quantityStepper(),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _preview(gift),
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: const Text('معاينة'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: (!affordable || _sending) ? null : _send,
            child: Text(_sending ? '...' : 'إرسال'),
          ),
        ],
      ),
    );
  }

  Widget _quantityStepper() => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final q in const [1, 5, 10])
              GestureDetector(
                onTap: () => setState(() => _quantity = q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: _quantity == q ? SN.gradGold : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('x$q',
                      style: TextStyle(
                          color: _quantity == q ? Colors.black : SN.textSec,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ),
              ),
          ],
        ),
      );
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.gift, required this.active, required this.onTap, required this.onPreview});

  final NovaGift gift;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final accent = NovaGiftCatalog.rarityColor(gift.rarity);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onPreview,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: active ? .30 : .13),
              const Color(0xFF0A1226),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: active ? .95 : .35), width: active ? 1.6 : 1),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: active ? .55 : .18), blurRadius: active ? 18 : 8, spreadRadius: active ? 1 : 0),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: Column(
                children: [
                  Expanded(child: NovaGiftArt(gift: gift, size: 64, showPremiumBadge: false)),
                  const SizedBox(height: 4),
                  Text(gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monetization_on_rounded, size: 10, color: accent),
                      const SizedBox(width: 3),
                      Text('${gift.price}',
                          style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            if (gift.premium)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(gradient: SN.gradGold, borderRadius: BorderRadius.circular(7)),
                  child: const Text('PRO',
                      style: TextStyle(color: Colors.black, fontSize: 7.5, fontWeight: FontWeight.w900)),
                ),
              ),
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accent, blurRadius: 6)]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

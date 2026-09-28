import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nova_audio.dart';
import 'theme.dart';

/// The four gift tiers used across the app. The Arabic labels are what the
/// gift sheet shows; [key] is the ASCII id sent to / received from the API.
enum NovaGiftTier {
  common('common', 'شائعة'),
  luck('luck', 'حظ'),
  luxury('luxury', 'فاخرة'),
  exclusive('exclusive', 'حصرية');

  const NovaGiftTier(this.key, this.label);
  final String key;
  final String label;
}

/// One gift definition. [effectKey] drives the on-screen animation and
/// [soundKey] drives the audio; both come from the server catalog so the
/// client never hard-codes a single gift.
class NovaGift {
  const NovaGift({
    required this.slug,
    required this.name,
    required this.emoji,
    required this.price,
    required this.tier,
    required this.effectKey,
    required this.soundKey,
  });

  final String slug;
  final String name;
  final String emoji;
  final int price;
  final NovaGiftTier tier;
  final String effectKey;
  final String soundKey;

  String get tierKey => tier.key;

  static NovaGift fromMap(Map<String, dynamic> m) {
    final price = ((m['priceCoins'] ?? 0) as num).toInt();
    return NovaGift(
      slug: '${m['slug'] ?? m['id'] ?? ''}',
      name: '${m['name'] ?? 'هدية'}',
      emoji: '${m['emoji'] ?? '🎁'}',
      price: price,
      tier: NovaGiftCatalog.tierForPrice(price),
      effectKey: '${m['effectKey'] ?? 'pulse'}',
      soundKey: '${m['soundKey'] ?? ''}',
    );
  }
}

/// Canonical client-side catalog. Mirrors the server `ensureCatalog()` list so
/// the UI can render tiers even before the first network call returns, and so
/// no two gifts ever share an emoji/name.
class NovaGiftCatalog {
  NovaGiftCatalog._();

  static const List<NovaGift> all = [
    // شائعة
    NovaGift(slug: 'rose', name: 'وردة', emoji: '🌹', price: 1, tier: NovaGiftTier.common, effectKey: 'rose', soundKey: 'rose'),
    NovaGift(slug: 'heart', name: 'قلب', emoji: '❤️', price: 5, tier: NovaGiftTier.common, effectKey: 'heart', soundKey: 'heart'),
    NovaGift(slug: 'coffee', name: 'قهوة', emoji: '☕', price: 9, tier: NovaGiftTier.common, effectKey: 'coffee', soundKey: 'coffee'),
    NovaGift(slug: 'cake', name: 'كيكة', emoji: '🎂', price: 15, tier: NovaGiftTier.common, effectKey: 'cake', soundKey: 'cake'),
    NovaGift(slug: 'mic', name: 'ميكروفون', emoji: '🎤', price: 22, tier: NovaGiftTier.common, effectKey: 'mic', soundKey: 'mic'),
    NovaGift(slug: 'dumbbell', name: 'دمبل', emoji: '🏋️', price: 29, tier: NovaGiftTier.common, effectKey: 'dumbbell', soundKey: 'dumbbell'),
    NovaGift(slug: 'ball', name: 'كرة', emoji: '⚽', price: 35, tier: NovaGiftTier.common, effectKey: 'ball', soundKey: 'ball'),
    NovaGift(slug: 'lamp', name: 'مصباح', emoji: '💡', price: 49, tier: NovaGiftTier.common, effectKey: 'lamp', soundKey: 'lamp'),
    // حظ
    NovaGift(slug: 'diamond', name: 'ماسة', emoji: '💎', price: 99, tier: NovaGiftTier.luck, effectKey: 'diamond', soundKey: 'spark'),
    NovaGift(slug: 'star', name: 'نجمة', emoji: '⭐', price: 149, tier: NovaGiftTier.luck, effectKey: 'star', soundKey: 'star'),
    NovaGift(slug: 'clover', name: 'حظ', emoji: '🍀', price: 199, tier: NovaGiftTier.luck, effectKey: 'clover', soundKey: 'clover'),
    NovaGift(slug: 'dice', name: 'نرد', emoji: '🎲', price: 299, tier: NovaGiftTier.luck, effectKey: 'dice', soundKey: 'dice'),
    NovaGift(slug: 'rocket', name: 'صاروخ', emoji: '🚀', price: 399, tier: NovaGiftTier.luck, effectKey: 'rocket', soundKey: 'rocket'),
    NovaGift(slug: 'balloon', name: 'بالون', emoji: '🎈', price: 499, tier: NovaGiftTier.luck, effectKey: 'balloon', soundKey: 'balloon'),
    // فاخرة
    NovaGift(slug: 'crown', name: 'تاج', emoji: '👑', price: 999, tier: NovaGiftTier.luxury, effectKey: 'crown', soundKey: 'crown'),
    NovaGift(slug: 'ring', name: 'خاتم', emoji: '💍', price: 1299, tier: NovaGiftTier.luxury, effectKey: 'ring', soundKey: 'ring'),
    NovaGift(slug: 'car', name: 'سيارة', emoji: '🏎️', price: 1799, tier: NovaGiftTier.luxury, effectKey: 'car', soundKey: 'engine'),
    NovaGift(slug: 'yacht', name: 'يخت', emoji: '🛥️', price: 2199, tier: NovaGiftTier.luxury, effectKey: 'yacht', soundKey: 'yacht'),
    NovaGift(slug: 'airplane', name: 'طائرة', emoji: '✈️', price: 2599, tier: NovaGiftTier.luxury, effectKey: 'airplane', soundKey: 'jet'),
    NovaGift(slug: 'castle', name: 'قصر', emoji: '🏰', price: 2999, tier: NovaGiftTier.luxury, effectKey: 'castle', soundKey: 'castle'),
    // حصرية
    NovaGift(slug: 'galaxy', name: 'مجرة', emoji: '🌌', price: 4999, tier: NovaGiftTier.exclusive, effectKey: 'galaxy', soundKey: 'space'),
    NovaGift(slug: 'dragon', name: 'تنين', emoji: '🐉', price: 5999, tier: NovaGiftTier.exclusive, effectKey: 'dragon', soundKey: 'dragon'),
    NovaGift(slug: 'lion', name: 'أسد', emoji: '🦁', price: 6999, tier: NovaGiftTier.exclusive, effectKey: 'lion', soundKey: 'roar'),
    NovaGift(slug: 'spaceship', name: 'سفينة فضاء', emoji: '🛸', price: 7999, tier: NovaGiftTier.exclusive, effectKey: 'spaceship', soundKey: 'warp'),
    NovaGift(slug: 'crystal', name: 'كريستال', emoji: '🔮', price: 8999, tier: NovaGiftTier.exclusive, effectKey: 'crystal', soundKey: 'magic'),
    NovaGift(slug: 'throne', name: 'عرش', emoji: '🪑', price: 9999, tier: NovaGiftTier.exclusive, effectKey: 'throne', soundKey: 'royal'),
  ];

  static NovaGiftTier tierForPrice(int price) {
    if (price >= 4999) return NovaGiftTier.exclusive;
    if (price >= 999) return NovaGiftTier.luxury;
    if (price >= 99) return NovaGiftTier.luck;
    return NovaGiftTier.common;
  }

  /// Tries the slug first, then falls back to price tier. Returns null only
  /// when the gift is completely unknown.
  static NovaGift? bySlug(String slug) {
    for (final g in all) {
      if (g.slug == slug) return g;
    }
    return null;
  }

  static NovaGift resolve(Map<String, dynamic> raw) {
    final slug = '${raw['slug'] ?? ''}';
    final known = bySlug(slug);
    if (known != null) return known;
    return NovaGift.fromMap(raw);
  }

  static List<NovaGift> forTier(NovaGiftTier tier) =>
      all.where((g) => g.tier == tier).toList();

  /// Maps a server soundKey to one of the bundled WAV effects.
  static String sfxKeyFor(String soundKey, NovaGiftTier tier) {
    const map = {
      'spark': 'luck', 'star': 'luck', 'clover': 'luck', 'dice': 'luck',
      'rocket': 'luck', 'balloon': 'luck',
      'crown': 'luxury', 'ring': 'luxury', 'engine': 'luxury',
      'yacht': 'luxury', 'jet': 'luxury', 'castle': 'luxury',
      'space': 'exclusive', 'dragon': 'exclusive', 'roar': 'exclusive',
      'warp': 'exclusive', 'magic': 'exclusive', 'royal': 'exclusive',
    };
    return map[soundKey] ?? tier.key;
  }
}

/// Full-screen animated gift effect. Distinct motion per [effectKey] so no two
/// gifts look the same, with a single [AnimationController] per burst.
class NovaGiftEffect extends StatefulWidget {
  const NovaGiftEffect({
    super.key,
    required this.emoji,
    required this.name,
    required this.effectKey,
    required this.tier,
    this.senderName = '',
    this.coins = 0,
    this.hostName = '',
    this.duration = const Duration(milliseconds: 2600),
    this.onDone,
  });

  final String emoji;
  final String name;
  final String effectKey;
  final NovaGiftTier tier;
  final String senderName;
  final int coins;
  final String hostName;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<NovaGiftEffect> createState() => _NovaGiftEffectState();
}

class _NovaGiftEffectState extends State<NovaGiftEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final math.Random _rnd = math.Random();
  late final List<double> _seed = List.generate(24, (_) => _rnd.nextDouble());

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _isFlight => const {
        'rocket', 'dragon', 'spaceship', 'airplane', 'car', 'yacht', 'galaxy', 'castle'
      }.contains(widget.effectKey);

  bool get _isRoyal => const {'crown', 'throne', 'royal', 'crystal'}.contains(widget.effectKey);

  Color get _tierColor => switch (widget.tier) {
        NovaGiftTier.exclusive => const Color(0xFFFFD700),
        NovaGiftTier.luxury => const Color(0xFFFFB74D),
        NovaGiftTier.luck => SN.cyan,
        NovaGiftTier.common => SN.pink,
      };

  String get _caption => switch (widget.tier) {
        NovaGiftTier.exclusive => widget.hostName.isEmpty ? 'هدية حصرية أسطورية 👑' : 'هدية أسطورية لـ ${widget.hostName} 👑',
        NovaGiftTier.luxury => 'هدية فاخرة 🎁',
        NovaGiftTier.luck => 'هدية حظ رائعة ✨',
        NovaGiftTier.common => 'هدية وصلت 🎉',
      };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            return Stack(
              children: [
                if (_isRoyal) _goldenRain(v),
                if (_isFlight) _flight(v),
                if (!_isFlight) _burst(v),
                _hero(v),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _goldenRain(double v) {
    final fade = (1 - v).clamp(0.0, 1.0);
    return Positioned.fill(
      child: Opacity(
        opacity: fade * .9,
        child: CustomPaint(painter: _RainPainter(v, _seed, _tierColor)),
      ),
    );
  }

  Widget _flight(double v) {
    final dx = (v * 1.25 - 0.15) * MediaQuery.of(context).size.width;
    final dy = MediaQuery.of(context).size.height * (0.62 - 0.22 * math.sin(v * math.pi));
    final angle = -0.5 + v * 0.9;
    return Positioned(
      left: dx - 60,
      top: dy - 60,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _tierColor.withValues(alpha: .55), blurRadius: 60, spreadRadius: 14)],
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 82)),
        ),
      ),
    );
  }

  Widget _burst(double v) {
    final scale = v < .3 ? (v / .3) : 1.0 + (v - .3) * .25;
    final opacity = (1 - v).clamp(0.0, 1.0);
    return Center(
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(painter: _BurstPainter(v, _seed, _tierColor)),
        ),
      ),
    );
  }

  Widget _hero(double v) {
    final appear = (v * 3).clamp(0.0, 1.0);
    final exit = ((v - .78) / .22).clamp(0.0, 1.0);
    final scale = 0.6 + 0.4 * Curves.elasticOut.transform(appear);
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Opacity(
        opacity: (1 - exit).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale * (1 - exit * .15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 178,
                height: 178,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: .5),
                  border: Border.all(color: _tierColor.withValues(alpha: .75), width: 2),
                  boxShadow: [BoxShadow(color: _tierColor.withValues(alpha: .55), blurRadius: 60, spreadRadius: 18)],
                ),
                child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 92))),
              ),
              const SizedBox(height: 12),
              Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${widget.senderName.isEmpty ? '' : '${widget.senderName}  •  '}+${widget.coins} NVC',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Text(_caption, style: TextStyle(color: _tierColor, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.v, this.seed, this.color);
  final double v;
  final List<double> seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .85);
    for (var i = 0; i < seed.length ~/ 2; i++) {
      final x = seed[i * 2] * size.width;
      final start = seed[i * 2 + 1];
      final y = ((start + v * 1.2) % 1.0) * size.height;
      final r = 2.5 + seed[(i * 2 + 1) % seed.length] * 4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => old.v != v;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.v, this.seed, this.color);
  final double v;
  final List<double> seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = color.withValues(alpha: (1 - v) * .9);
    for (var i = 0; i < seed.length; i++) {
      final a = seed[i] * math.pi * 2;
      final dist = (0.2 + v * 0.9) * size.width * 0.5 * (0.5 + seed[(i + 3) % seed.length] * .5);
      canvas.drawCircle(c + Offset(math.cos(a) * dist, math.sin(a) * dist), 2 + seed[i] * 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.v != v;
}

/// Convenience: speak the gift's sound. Kept here so any screen that shows a
/// gift can trigger audio without importing NovaAudio directly.
void playGiftSound(String soundKey, NovaGiftTier tier) {
  NovaAudio.i.playSfx(NovaGiftCatalog.sfxKeyFor(soundKey, tier));
}

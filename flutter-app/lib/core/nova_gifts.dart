import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api.dart';
import 'nova_audio.dart';

/// The four price tiers used across the app (kept for legacy gift sheets).
enum NovaGiftTier {
  common('common', 'شائعة'),
  luck('luck', 'حظ'),
  luxury('luxury', 'فاخرة'),
  exclusive('exclusive', 'حصرية');

  const NovaGiftTier(this.key, this.label);
  final String key;
  final String label;
}

/// Rarity drives the frame colour and the intensity of the animation.
enum NovaGiftRarity {
  common('COMMON', 'عادية'),
  rare('RARE', 'نادرة'),
  epic('EPIC', 'ملحمية'),
  legendary('LEGENDARY', 'أسطورية'),
  mythic('MYTHIC', 'خرافية');

  const NovaGiftRarity(this.key, this.label);
  final String key;
  final String label;
}

/// Motion family — every gift maps to one, so no two categories move alike.
enum NovaMotion { drop, rise, drive, fly, shake, bloom }

/// One gift definition, exactly as the Gift Engine returns it.
class NovaGift {
  const NovaGift({
    required this.slug,
    required this.name,
    required this.emoji,
    required this.price,
    required this.tier,
    required this.effectKey,
    required this.soundKey,
    this.rarity = NovaGiftRarity.common,
    this.category = '',
    this.durationMs = 1800,
    this.imageUrl = '',
    this.previewUrl = '',
    this.premium = false,
    this.serverId = '',
  });

  final String slug;
  final String name;
  final String emoji;
  final int price;
  final NovaGiftTier tier;
  final String effectKey;
  final String soundKey;
  final NovaGiftRarity rarity;
  final String category;
  final int durationMs;
  /// Real artwork rendered by tools/generate_gift_assets.py and served by the
  /// backend. Empty when an admin has not attached an image yet — the UI then
  /// falls back to the emoji so the sheet never shows a broken card.
  final String imageUrl;
  final String previewUrl;
  final bool premium;
  /// The database id when the row came from the server (empty for the bundled
  /// offline catalog, where the slug is used instead).
  final String serverId;

  String get tierKey => tier.key;
  bool get hasArtwork => imageUrl.trim().isNotEmpty;
  /// Absolute URL the app can load (the server returns a root-relative path).
  String get artworkUrl {
    final u = imageUrl.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return '${Api.baseUrl}$u';
  }

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
      rarity: NovaGiftCatalog.rarityFor('${m['rarity'] ?? ''}'),
      category: '${m['category'] ?? ''}',
      durationMs: (m['effectMs'] as num?)?.toInt() ?? 1800,
      imageUrl: '${m['imageUrl'] ?? ''}',
      previewUrl: '${m['previewUrl'] ?? ''}',
      premium: m['premium'] == true,
      serverId: '${m['id'] ?? ''}',
    );
  }

  NovaMotion get motion => NovaGiftCatalog.motionFor(effectKey);

  /// Plain map for callers that need to hand a gift back (e.g. the store).
  Map<String, dynamic> toMap() => {
        'id': serverId,
        'slug': slug,
        'name': name,
        'emoji': emoji,
        'priceCoins': price,
        'rarity': rarity.key,
        'category': category,
        'effectKey': effectKey,
        'effectMs': durationMs,
        'soundKey': soundKey,
        'imageUrl': imageUrl,
        'previewUrl': previewUrl,
        'premium': premium,
      };
}

/// Canonical fallback catalog (mirrors the first 26 engine entries) so the UI
/// still renders before the first network call returns.
class NovaGiftCatalog {
  NovaGiftCatalog._();

  static const List<NovaGift> all = [
    NovaGift(slug: 'rose', name: 'وردة', emoji: '🌹', price: 1, tier: NovaGiftTier.common, effectKey: 'rose', soundKey: 'rose'),
    NovaGift(slug: 'heart', name: 'قلب', emoji: '❤️', price: 5, tier: NovaGiftTier.common, effectKey: 'heart', soundKey: 'heart'),
    NovaGift(slug: 'coffee', name: 'قهوة', emoji: '☕', price: 9, tier: NovaGiftTier.common, effectKey: 'coffee', soundKey: 'coffee'),
    NovaGift(slug: 'cake', name: 'كيكة', emoji: '🎂', price: 15, tier: NovaGiftTier.common, effectKey: 'cake', soundKey: 'cake'),
    NovaGift(slug: 'mic', name: 'ميكروفون', emoji: '🎤', price: 22, tier: NovaGiftTier.common, effectKey: 'mic', soundKey: 'mic'),
    NovaGift(slug: 'dumbbell', name: 'دمبل', emoji: '🏋️', price: 29, tier: NovaGiftTier.common, effectKey: 'dumbbell', soundKey: 'dumbbell'),
    NovaGift(slug: 'ball', name: 'كرة', emoji: '⚽', price: 35, tier: NovaGiftTier.common, effectKey: 'ball', soundKey: 'ball'),
    NovaGift(slug: 'lamp', name: 'مصباح', emoji: '💡', price: 49, tier: NovaGiftTier.common, effectKey: 'lamp', soundKey: 'lamp'),
    NovaGift(slug: 'diamond', name: 'ماسة', emoji: '💎', price: 99, tier: NovaGiftTier.luck, effectKey: 'diamond', soundKey: 'spark', rarity: NovaGiftRarity.rare),
    NovaGift(slug: 'star', name: 'نجمة', emoji: '⭐', price: 149, tier: NovaGiftTier.luck, effectKey: 'star', soundKey: 'star', rarity: NovaGiftRarity.rare),
    NovaGift(slug: 'clover', name: 'حظ', emoji: '🍀', price: 199, tier: NovaGiftTier.luck, effectKey: 'clover', soundKey: 'clover', rarity: NovaGiftRarity.rare),
    NovaGift(slug: 'dice', name: 'نرد', emoji: '🎲', price: 299, tier: NovaGiftTier.luck, effectKey: 'dice', soundKey: 'dice', rarity: NovaGiftRarity.rare),
    NovaGift(slug: 'rocket', name: 'صاروخ', emoji: '🚀', price: 399, tier: NovaGiftTier.luck, effectKey: 'rocket', soundKey: 'rocket', rarity: NovaGiftRarity.rare),
    NovaGift(slug: 'balloon', name: 'بالون', emoji: '🎈', price: 499, tier: NovaGiftTier.luck, effectKey: 'balloon', soundKey: 'balloon', rarity: NovaGiftRarity.rare),
    NovaGift(slug: 'crown', name: 'تاج', emoji: '👑', price: 999, tier: NovaGiftTier.luxury, effectKey: 'crown', soundKey: 'crown', rarity: NovaGiftRarity.epic),
    NovaGift(slug: 'ring', name: 'خاتم', emoji: '💍', price: 1299, tier: NovaGiftTier.luxury, effectKey: 'ring', soundKey: 'ring', rarity: NovaGiftRarity.epic),
    NovaGift(slug: 'car', name: 'سيارة', emoji: '🏎️', price: 1799, tier: NovaGiftTier.luxury, effectKey: 'car', soundKey: 'engine', rarity: NovaGiftRarity.epic),
    NovaGift(slug: 'yacht', name: 'يخت', emoji: '🛥️', price: 2199, tier: NovaGiftTier.luxury, effectKey: 'yacht', soundKey: 'yacht', rarity: NovaGiftRarity.epic),
    NovaGift(slug: 'airplane', name: 'طائرة', emoji: '✈️', price: 2599, tier: NovaGiftTier.luxury, effectKey: 'airplane', soundKey: 'jet', rarity: NovaGiftRarity.epic),
    NovaGift(slug: 'castle', name: 'قصر', emoji: '🏰', price: 2999, tier: NovaGiftTier.luxury, effectKey: 'castle', soundKey: 'castle', rarity: NovaGiftRarity.epic),
    NovaGift(slug: 'galaxy', name: 'مجرة', emoji: '🌌', price: 4999, tier: NovaGiftTier.exclusive, effectKey: 'galaxy', soundKey: 'space', rarity: NovaGiftRarity.legendary),
    NovaGift(slug: 'dragon', name: 'تنين', emoji: '🐉', price: 5999, tier: NovaGiftTier.exclusive, effectKey: 'dragon', soundKey: 'dragon', rarity: NovaGiftRarity.legendary),
    NovaGift(slug: 'lion', name: 'أسد', emoji: '🦁', price: 6999, tier: NovaGiftTier.exclusive, effectKey: 'lion', soundKey: 'roar', rarity: NovaGiftRarity.legendary),
    NovaGift(slug: 'spaceship', name: 'سفينة فضاء', emoji: '🛸', price: 7999, tier: NovaGiftTier.exclusive, effectKey: 'spaceship', soundKey: 'warp', rarity: NovaGiftRarity.legendary),
    NovaGift(slug: 'crystal', name: 'كريستال', emoji: '🔮', price: 8999, tier: NovaGiftTier.exclusive, effectKey: 'crystal', soundKey: 'magic', rarity: NovaGiftRarity.legendary),
    NovaGift(slug: 'throne', name: 'عرش', emoji: '🪑', price: 9999, tier: NovaGiftTier.exclusive, effectKey: 'throne', soundKey: 'royal', rarity: NovaGiftRarity.mythic),
  ];

  static NovaGiftTier tierForPrice(int price) {
    if (price >= 4999) return NovaGiftTier.exclusive;
    if (price >= 999) return NovaGiftTier.luxury;
    if (price >= 99) return NovaGiftTier.luck;
    return NovaGiftTier.common;
  }

  static NovaGiftRarity rarityFor(String raw) {
    switch (raw.toUpperCase()) {
      case 'MYTHIC': return NovaGiftRarity.mythic;
      case 'LEGENDARY': return NovaGiftRarity.legendary;
      case 'EPIC': return NovaGiftRarity.epic;
      case 'RARE': return NovaGiftRarity.rare;
      default: return NovaGiftRarity.common;
    }
  }

  /// Maps the engine's animation key onto one of six motion families.
  static NovaMotion motionFor(String effectKey) {
    switch (effectKey) {
      case 'crown':
      case 'castle':
      case 'trophy':
      case 'diamond':
      case 'crystal':
      case 'coins':
      case 'throne':
      case 'ring':
        return NovaMotion.drop;
      case 'rocket':
      case 'balloon':
      case 'fireworks':
        return NovaMotion.rise;
      case 'car':
      case 'yacht':
        return NovaMotion.drive;
      case 'plane':
      case 'galaxy':
      case 'dragon':
      case 'spaceship':
        return NovaMotion.fly;
      case 'lion':
      case 'fire':
      case 'lightning':
      case 'roar':
        return NovaMotion.shake;
      default:
        return NovaMotion.bloom;
    }
  }

  static Color rarityColor(NovaGiftRarity r) => switch (r) {
        NovaGiftRarity.mythic => const Color(0xFFFF4D6D),
        NovaGiftRarity.legendary => const Color(0xFFFFD54F),
        NovaGiftRarity.epic => const Color(0xFFBA68C8),
        NovaGiftRarity.rare => const Color(0xFF4FC3F7),
        NovaGiftRarity.common => const Color(0xFF90A4AE),
      };

  static const Map<String, String> categoryLabels = {
    'love': 'حب ومشاعر',
    'luxury': 'فخامة',
    'tech': 'تقنية وسيارات',
    'nature': 'طبيعة',
    'food': 'مأكولات',
    'music': 'موسيقى وترفيه',
    'sport': 'رياضة وقوة',
  };

  static String categoryLabel(String key) => categoryLabels[key] ?? key;

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

/// Full-screen animated gift effect. Six motion families plus rarity-driven
/// intensity (golden rain, white flash) so no two gifts feel the same.
class NovaGiftEffect extends StatefulWidget {
  const NovaGiftEffect({
    super.key,
    required this.emoji,
    required this.name,
    required this.effectKey,
    required this.tier,
    this.rarity = NovaGiftRarity.common,
    this.senderName = '',
    this.coins = 0,
    this.quantity = 1,
    this.hostName = '',
    this.duration = const Duration(milliseconds: 2600),
    this.gift,
    this.onDone,
  });

  final String emoji;
  final String name;
  final String effectKey;
  final NovaGiftTier tier;
  final NovaGiftRarity rarity;
  final String senderName;
  final int coins;
  /// Combo count — identical gifts merge into one animation shown as xN.
  final int quantity;
  final String hostName;
  final Duration duration;
  /// When provided, the effect renders the gift's real artwork instead of the
  /// emoji fallback.
  final NovaGift? gift;
  final VoidCallback? onDone;

  @override
  State<NovaGiftEffect> createState() => _NovaGiftEffectState();
}

class _NovaGiftEffectState extends State<NovaGiftEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final math.Random _rnd = math.Random();
  late final List<double> _seed = List.generate(28, (_) => _rnd.nextDouble());

  NovaMotion get _motion => NovaGiftCatalog.motionFor(widget.effectKey);
  Color get _accent => NovaGiftCatalog.rarityColor(widget.rarity);
  bool get _fancy => widget.rarity == NovaGiftRarity.legendary || widget.rarity == NovaGiftRarity.mythic;

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

  String get _caption => switch (widget.rarity) {
        NovaGiftRarity.mythic => 'هدية أسطورية خرافية 🔥',
        NovaGiftRarity.legendary => widget.hostName.isEmpty ? 'هدية أسطورية 👑' : 'هدية أسطورية لـ ${widget.hostName} 👑',
        NovaGiftRarity.epic => 'هدية ملحمية فاخرة 🎁',
        NovaGiftRarity.rare => 'هدية نادرة ✨',
        NovaGiftRarity.common => 'هدية وصلت 🎉',
      };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            final content = Stack(
              children: [
                if (_fancy) _goldenRain(v),
                switch (_motion) {
                  NovaMotion.drop => _drop(v),
                  NovaMotion.rise => _rise(v),
                  NovaMotion.drive => _drive(v),
                  NovaMotion.fly => _fly(v),
                  NovaMotion.shake => _shake(v),
                  NovaMotion.bloom => _bloom(v),
                },
                _hero(v),
                if (_fancy) _flash(v),
              ],
            );
            return content;
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
        child: CustomPaint(painter: _RainPainter(v, _seed, _accent)),
      ),
    );
  }

  Widget _flash(double v) {
    // A very short white flash at the start of legendary/mythic gifts.
    final a = v < .12 ? (1 - v / .12) * .35 : 0.0;
    return Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: a))));
  }

  Widget _drop(double v) {
    // Falls from above the screen, bounces, then settles while glowing.
    final t = Curves.bounceOut.transform((v / .45).clamp(0.0, 1.0));
    final dy = -0.45 * MediaQuery.of(context).size.height * (1 - t);
    return Align(
      alignment: Alignment(0, -0.35),
      child: Transform.translate(
        offset: Offset(0, dy),
        child: _glowDisc(120, 84),
      ),
    );
  }

  Widget _rise(double v) {
    // Travels from the bottom of the screen to the top with a trail.
    final dy = MediaQuery.of(context).size.height * (0.75 - 1.5 * v);
    return Positioned(
      left: MediaQuery.of(context).size.width / 2 - 70,
      top: dy,
      child: _glowDisc(140, 88),
    );
  }

  Widget _drive(double v) {
    // Crosses horizontally with speed lines and tire smoke.
    final dx = -140 + (MediaQuery.of(context).size.width + 280) * v;
    return Stack(children: [
      Positioned(
        left: 0, right: 0, top: MediaQuery.of(context).size.height * .52,
        child: Opacity(
          opacity: (1 - v).clamp(0.0, 1.0) * .6,
          child: CustomPaint(painter: _SpeedPainter(v, _seed, _accent), child: const SizedBox(height: 160)),
        ),
      ),
      Positioned(left: dx, top: MediaQuery.of(context).size.height * .42, child: _glowDisc(140, 84)),
    ]);
  }

  Widget _fly(double v) {
    final dx = (v * 1.25 - 0.15) * MediaQuery.of(context).size.width;
    final dy = MediaQuery.of(context).size.height * (0.62 - 0.24 * math.sin(v * math.pi));
    return Positioned(
      left: dx - 70,
      top: dy,
      child: Transform.rotate(angle: -0.5 + v * 0.9, child: _glowDisc(140, 86)),
    );
  }

  Widget _shake(double v) {
    // Screen shake + radial glow + big text effect.
    final amp = (1 - v) * 10;
    final sx = math.sin(v * math.pi * 26) * amp;
    final sy = math.cos(v * math.pi * 22) * amp * .6;
    return Stack(children: [
      Positioned.fill(
        child: Transform.translate(
          offset: Offset(sx, sy),
          child: Opacity(
            opacity: (1 - v).clamp(0.0, 1.0) * .85,
            child: CustomPaint(painter: _BurstPainter(v, _seed, _accent)),
          ),
        ),
      ),
      Center(child: Transform.translate(offset: Offset(sx, sy), child: _glowDisc(190, 100))),
    ]);
  }

  Widget _bloom(double v) {
    final scale = v < .3 ? (v / .3) : 1.0 + (v - .3) * .25;
    return Stack(children: [
      Center(
        child: Opacity(
          opacity: (1 - v).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 230,
              height: 230,
              child: CustomPaint(painter: _BurstPainter(v, _seed, _accent)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _glowDisc(double size, double fontSize) {
    final v = _c.value;
    final pulse = 1 + math.sin(v * math.pi * 3) * .04;
    return Transform.scale(
      scale: pulse,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: .42),
          border: Border.all(color: _accent.withValues(alpha: .8), width: 2),
          boxShadow: [BoxShadow(color: _accent.withValues(alpha: .6), blurRadius: 60, spreadRadius: 16)],
        ),
        child: (widget.gift?.hasArtwork ?? false)
            ? NovaGiftArt(gift: widget.gift!, size: size * .74, showPremiumBadge: false)
            : Text(widget.emoji, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }

  Widget _hero(double v) {
    final appear = (v * 3).clamp(0.0, 1.0);
    final exit = ((v - .78) / .22).clamp(0.0, 1.0);
    final scale = 0.6 + 0.4 * Curves.elasticOut.transform(appear);
    return Align(
      alignment: const Alignment(0, 0.42),
      child: Opacity(
        opacity: (1 - exit).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale * (1 - exit * .15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accent.withValues(alpha: .5))),
                child: Text(
                  '${widget.senderName.isEmpty ? '' : '${widget.senderName}  •  '}+${widget.coins} NVC${widget.quantity > 1 ? '  ×${widget.quantity}' : ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              Text(_caption, style: TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 14)),
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

class _SpeedPainter extends CustomPainter {
  _SpeedPainter(this.v, this.seed, this.color);
  final double v;
  final List<double> seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2..color = color.withValues(alpha: (1 - v).clamp(0.0, 1.0) * .7);
    for (var i = 0; i < 14; i++) {
      final y = seed[i % seed.length] * size.height;
      final len = 40 + seed[(i + 5) % seed.length] * 120;
      final x = (size.width + 200) * v - len;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter old) => old.v != v;
}

/// Speaks the gift's sound. Kept here so any screen can trigger audio.
void playGiftSound(String soundKey, NovaGiftTier tier) {
  NovaAudio.i.playSfx(NovaGiftCatalog.sfxKeyFor(soundKey, tier));
}

/// Renders a gift's real artwork from the server, falling back to the emoji
/// while the image loads or when a gift has no image attached yet.
///
/// Every gift card in the store, the live gift overlay and the gift counter
/// use this widget, so artwork only has to be uploaded once (Asset Manager or
/// `PATCH /api/admin/gifts/:id`) for it to appear everywhere.
class NovaGiftArt extends StatelessWidget {
  const NovaGiftArt({
    super.key,
    required this.gift,
    this.size = 56,
    this.showPremiumBadge = true,
  });

  final NovaGift gift;
  final double size;
  final bool showPremiumBadge;

  @override
  Widget build(BuildContext context) {
    final art = gift.hasArtwork
        ? Image.network(
            gift.artworkUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _emoji(),
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : _emoji(),
          )
        : _emoji();
    if (!showPremiumBadge || !gift.premium) return art;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        art,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: .5), blurRadius: 8)],
            ),
            child: const Text('PRO',
                style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _emoji() => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(gift.emoji, style: TextStyle(fontSize: size * .58)),
        ),
      );
}

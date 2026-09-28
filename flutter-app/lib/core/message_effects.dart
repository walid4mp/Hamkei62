import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The message effects a user can attach to a chat message. The id is stored
/// with the message on the server and replayed for the receiver.
class NovaMessageEffectDef {
  const NovaMessageEffectDef(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

const List<NovaMessageEffectDef> kMessageEffects = [
  NovaMessageEffectDef('celebration', 'احتفال', '🎉'),
  NovaMessageEffectDef('hearts', 'قلوب', '❤️'),
  NovaMessageEffectDef('fire', 'نار', '🔥'),
  NovaMessageEffectDef('stars', 'نجوم', '✨'),
  NovaMessageEffectDef('snow', 'ثلج', '❄️'),
  NovaMessageEffectDef('fireworks', 'ألعاب نارية', '🎆'),
];

NovaMessageEffectDef? messageEffectById(String id) {
  for (final e in kMessageEffects) {
    if (e.id == id) return e;
  }
  return null;
}

/// Plays a short full-screen effect over the current screen. Safe to call from
/// anywhere: it inserts one overlay entry and removes it when finished.
void showMessageEffect(BuildContext context, String effectId) {
  if (messageEffectById(effectId) == null) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => NovaMessageEffect(
      effectId: effectId,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class NovaMessageEffect extends StatefulWidget {
  const NovaMessageEffect({super.key, required this.effectId, this.onDone});
  final String effectId;
  final VoidCallback? onDone;

  @override
  State<NovaMessageEffect> createState() => _NovaMessageEffectState();
}

class _NovaMessageEffectState extends State<NovaMessageEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final math.Random _rnd = math.Random();
  late final List<double> _seed = List.generate(40, (_) => _rnd.nextDouble());

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
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

  Color get _color => switch (widget.effectId) {
        'hearts' => const Color(0xFFFF4D8D),
        'fire' => const Color(0xFFFF7A18),
        'stars' => const Color(0xFFFFD54F),
        'snow' => const Color(0xFFB3E5FC),
        'fireworks' => const Color(0xFFFF5252),
        _ => const Color(0xFF7C4DFF),
      };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          return SizedBox.expand(
            child: CustomPaint(painter: _EffectPainter(widget.effectId, v, _seed, _color)),
          );
        },
      ),
    );
  }
}

class _EffectPainter extends CustomPainter {
  _EffectPainter(this.mode, this.v, this.seed, this.color);
  final String mode;
  final double v;
  final List<double> seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = mode == 'fireworks' ? (v < .15 ? v / .15 : (1 - (v - .15) / .85)) : (1 - v);
    switch (mode) {
      case 'hearts':
        _confetti(canvas, size, fade, 26, heart: true);
        break;
      case 'fire':
        _rising(canvas, size, fade, 30);
        break;
      case 'stars':
        _twinkle(canvas, size, fade, 40);
        break;
      case 'snow':
        _falling(canvas, size, fade, 40, 0.06);
        break;
      case 'fireworks':
        _fireworks(canvas, size, fade);
        break;
      default:
        _confetti(canvas, size, fade, 34);
    }
  }

  void _confetti(Canvas canvas, Size size, double a, int count, {bool heart = false}) {
    final paint = Paint()..color = color.withValues(alpha: (a * .85).clamp(0.0, 1.0));
    for (var i = 0; i < count; i++) {
      final x = (seed[i % seed.length] * size.width + math.sin(v * 6.28 + i) * 30) % size.width;
      final y = ((seed[(i + 3) % seed.length] + v * .9 + i * .013) % 1.0) * size.height;
      if (heart) {
        canvas.drawCircle(Offset(x, y), 5 + seed[i % seed.length] * 6, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(v * 6 + i);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 8, height: 12), paint);
        canvas.restore();
      }
    }
  }

  void _rising(Canvas canvas, Size size, double a, int count) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = (seed[i % seed.length] * size.width + math.sin(v * 6.28 + i) * 20) % size.width;
      final y = (1 - ((seed[(i + 5) % seed.length] + v * 1.15 + i * .02) % 1.0)) * size.height;
      paint.color = (i.isEven ? const Color(0xFFFF7A18) : const Color(0xFFFFC53D)).withValues(alpha: (a * .8).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3 + seed[i % seed.length] * 8, paint);
    }
  }

  void _twinkle(Canvas canvas, Size size, double a, int count) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = seed[i % seed.length] * size.width;
      final y = seed[(i + 7) % seed.length] * size.height;
      final tw = (0.3 + 0.7 * math.sin((v * 4 + i * .3) * 3.14).abs());
      paint.color = color.withValues(alpha: (a * tw).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 1.5 + seed[i % seed.length] * 3, paint);
    }
  }

  void _falling(Canvas canvas, Size size, double a, int count, double speed) {
    final paint = Paint()..color = color.withValues(alpha: (a * .75).clamp(0.0, 1.0));
    for (var i = 0; i < count; i++) {
      final x = (seed[i % seed.length] * size.width + math.sin(v * 6.28 + i) * 16) % size.width;
      final y = ((seed[(i + 2) % seed.length] + v * speed * 10) % 1.0) * size.height;
      canvas.drawCircle(Offset(x, y), 1.5 + seed[i % seed.length] * 3, paint);
    }
  }

  void _fireworks(Canvas canvas, Size size, double a) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
    final bursts = [
      Offset(size.width * .3, size.height * .32),
      Offset(size.width * .7, size.height * .26),
      Offset(size.width * .5, size.height * .46),
    ];
    for (var b = 0; b < bursts.length; b++) {
      final local = ((v - b * .12) / .5).clamp(0.0, 1.0);
      paint.color = (b == 1 ? const Color(0xFFFFD54F) : color).withValues(alpha: (a * (1 - local)).clamp(0.0, 1.0));
      for (var i = 0; i < 10; i++) {
        final ang = i * 0.628 + b;
        final dist = local * (60 + b * 20);
        canvas.drawCircle(bursts[b] + Offset(math.cos(ang) * dist, math.sin(ang) * dist), 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) => old.v != v;
}

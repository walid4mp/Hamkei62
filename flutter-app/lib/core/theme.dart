import 'dart:math' as math;
import 'package:flutter/material.dart';

/// SocialNova v9 design system.
/// A unified, premium dark theme shared by every screen.
class AppAppearance {
  AppAppearance._();
  static final ValueNotifier<String> mode = ValueNotifier<String>('neon');
}

class SN {
  SN._();

  // Core palette
  static const bg0 = Color(0xFF020817); // neon app background
  static const bg1 = Color(0xFF050A1B); // glass surface
  static const bg2 = Color(0xFF081431); // glass card
  static const bg3 = Color(0xFF0C1B3C); // elevated glass
  static const stroke = Color(0xFF2453A0);
  static const strokeSoft = Color(0xFF17396F);

  static const violet = Color(0xFF6847FF);
  static const indigo = Color(0xFF2C72FF);
  static const cyan = Color(0xFF259BFF);
  static const pink = Color(0xFFFF2D78);
  static const gold = Color(0xFFFFC24B);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);

  static const textPri = Color(0xFFF4F7FF);
  static const textSec = Color(0xFFB8C6E6);
  static const textMut = Color(0xFF7183AA);

  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, indigo],
  );

  static const gradPink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, violet],
  );

  static const gradGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, Color(0xFFFF8A3D)],
  );

  static ThemeData theme({bool night = false}) {
    final baseBg = night ? const Color(0xFF01030A) : bg0;
    final baseSurface = night ? const Color(0xFF050914) : bg1;
    final seed = night ? cyan : violet;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: baseBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        surface: baseSurface,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textPri,
        displayColor: textPri,
      ),
      dividerColor: strokeSoft,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: baseSurface,
        elevation: 0,
        height: 70,
        indicatorColor: violet.withValues(alpha: .22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textSec),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 23,
            color: s.contains(WidgetState.selected) ? violet : textMut,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: const TextStyle(color: textSec),
        hintStyle: const TextStyle(color: textMut),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: violet, width: 1.6),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: bg3,
        contentTextStyle: TextStyle(color: textPri),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
    );
  }
}

/// Reusable glass-style surface used across the app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? SN.bg2 : null,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: SN.strokeSoft),
        ),
        child: child,
      );
}

/// Full-width gradient primary button.
class GradButton extends StatelessWidget {
  const GradButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.gradient,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final Gradient? gradient;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: gradient ?? SN.grad,
          boxShadow: [
            BoxShadow(color: SN.violet.withValues(alpha: .32), blurRadius: 18),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: Colors.white),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
}

/// Circular avatar with graceful fallback + optional verified ring.
class SNav extends StatelessWidget {
  const SNav({
    super.key,
    this.url,
    this.name = '',
    this.size = 46,
    this.ring = false,
  });

  final String? url;
  final String name;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e[0]).join();
    Widget inner = u.isEmpty
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            color: SN.bg3,
            child: Text(
              initials.toUpperCase(),
              style: TextStyle(
                color: SN.textPri,
                fontWeight: FontWeight.w700,
                fontSize: size * .34,
              ),
            ),
          )
        : Image.network(
            u,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              color: SN.bg3,
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  color: SN.textPri,
                  fontWeight: FontWeight.w700,
                  fontSize: size * .34,
                ),
              ),
            ),
          );
    inner = ClipOval(child: inner);
    return SizedBox(
      width: size,
      height: size,
      child: ring
          ? Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SN.grad,
              ),
              child: Padding(padding: const EdgeInsets.all(1.5), child: inner),
            )
          : inner,
    );
  }
}


/// Profile activity ring: LIVE / STORY / POST / REEL segments.
/// It is data-driven by the backend; no fake activity is generated client-side.
class StatusAvatar extends StatelessWidget {
  const StatusAvatar({super.key, required this.url, required this.name, this.size = 48, this.status = const {}, this.onSegmentTap});
  final String? url;
  final String name;
  final double size;
  final Map<String, dynamic> status;
  final ValueChanged<String>? onSegmentTap;

  void _handleTap(TapUpDetails details) {
    final segments = List<String>.from(status['segments'] ?? const <String>[]);
    if (segments.isEmpty || onSegmentTap == null) return;
    if (segments.length == 1) { onSegmentTap!(segments.first); return; }
    final box = details.localPosition;
    final center = Offset(size / 2, size / 2);
    final dx = box.dx - center.dx;
    final dy = box.dy - center.dy;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final index = ((angle / (math.pi * 2)) * segments.length).floor().clamp(0, segments.length - 1);
    onSegmentTap!(segments[index]);
  }

  @override
  Widget build(BuildContext context) {
    final segs = List<String>.from(status['segments'] ?? const <String>[]);
    if (segs.isEmpty) return GestureDetector(onTap: onSegmentTap == null ? null : () => onSegmentTap!('NONE'), child: SNav(url: url, name: name, size: size));
    final colors = <String, Color>{
      'LIVE': SN.red,
      'STORY': SN.gold,
      'POST': SN.cyan,
      'REEL': SN.violet,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _StatusRingPainter(colors: segs.map((x) => colors[x] ?? SN.violet).toList()),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SNav(url: url, name: name, size: size - 8),
          ),
        ),
      ),
    );
  }
}
class _StatusRingPainter extends CustomPainter {
  _StatusRingPainter({required this.colors});
  final List<Color> colors;
  @override
  void paint(Canvas c, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2.0;
    final stroke = math.max(2.5, size.shortestSide * .055);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    final gap = colors.length == 1 ? 0.0 : 0.055;
    final sweep = (math.pi * 2 - gap * colors.length) / colors.length;
    var start = -math.pi / 2;
    for (final color in colors) {
      p.color = color;
      c.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, p);
      start += sweep + gap;
    }
  }
  @override bool shouldRepaint(covariant _StatusRingPainter old) => old.colors.length != colors.length || old.colors.join() != colors.join();
}

/// Blue / gold verification badge.
class VerifiedBadge extends StatefulWidget {
  const VerifiedBadge({super.key, this.tier = 'NONE', this.size = 16});

  final String tier; // NONE | NORMAL | PRO
  final double size;

  @override
  State<VerifiedBadge> createState() => _VerifiedBadgeState();
}

class _VerifiedBadgeState extends State<VerifiedBadge> with SingleTickerProviderStateMixin {
  // Lazily created, but NEVER from dispose(): a NONE/NORMAL badge never builds
  // the animated branch, and creating a Ticker while unmounting used to throw
  // "Looking up a deactivated widget's ancestor is unsafe".
  AnimationController? _anim;
  AnimationController get _controller =>
      _anim ??= AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() { _anim?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.tier == 'NONE') return const SizedBox.shrink();
    if (widget.tier == 'PRO') {
      return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => ShaderMask(
          shaderCallback: (r) {
            final x = (_controller.value * 2 - .5) * r.width;
            return LinearGradient(
              colors: const [Color(0xFFFFB300), Color(0xFFFFF3A3), Color(0xFFFFC107), Color(0xFFFF8F00)],
              stops: const [0, .35, .62, 1],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              transform: GradientTranslation(x),
            ).createShader(r);
          },
          child: Stack(alignment: Alignment.center, children: [
            Icon(Icons.verified_rounded, size: widget.size + 2, color: Colors.white.withValues(alpha: .20)),
            Icon(Icons.verified_rounded, size: widget.size, color: Colors.white),
          ]),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: SN.indigo.withValues(alpha: .65), blurRadius: widget.size * .8)]),
      child: Icon(Icons.verified_rounded, size: widget.size, color: SN.indigo),
    );
  }
}

class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.x);
  final double x;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(x, 0, 0);
}

String timeAgo(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso.toString());
  if (d == null) return '';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} ${diff.inMinutes == 1 ? 'دقيقة' : diff.inMinutes == 2 ? 'دقيقتين' : 'دقائق'}';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ${diff.inHours == 1 ? 'ساعة' : diff.inHours == 2 ? 'ساعتين' : 'ساعات'}';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} ${diff.inDays == 1 ? 'يوم' : diff.inDays == 2 ? 'يومين' : 'أيام'}';
  if (diff.inDays < 30) return 'قبل ${(diff.inDays / 7).floor()} أسبوع';
  if (diff.inDays < 365) return 'قبل ${(diff.inDays / 30).floor()} شهر';
  return 'قبل ${(diff.inDays / 365).floor()} سنة';
}

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
  );
}

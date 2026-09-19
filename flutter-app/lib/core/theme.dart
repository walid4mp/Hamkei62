import 'package:flutter/material.dart';

/// SocialNova v9 design system.
/// A unified, premium dark theme shared by every screen.
class SN {
  SN._();

  // Core palette
  static const bg0 = Color(0xFFF8F8FA); // app background
  static const bg1 = Color(0xFFFFFFFF); // surface
  static const bg2 = Color(0xFFFFFFFF); // card
  static const bg3 = Color(0xFFF1F2F6); // elevated card
  static const stroke = Color(0xFFE3E4E8);
  static const strokeSoft = Color(0xFFECECEF);

  static const violet = Color(0xFF5B5FEF);
  static const indigo = Color(0xFF3E8BFF);
  static const cyan = Color(0xFF2AA7FF);
  static const pink = Color(0xFFFF4F86);
  static const gold = Color(0xFFFFC24B);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);

  static const textPri = Color(0xFF151823);
  static const textSec = Color(0xFF596174);
  static const textMut = Color(0xFF8A92A3);

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

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg0,
      colorScheme: ColorScheme.fromSeed(
        seedColor: violet,
        brightness: Brightness.light,
        surface: bg1,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textPri,
        displayColor: textPri,
      ),
      dividerColor: strokeSoft,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg1,
        elevation: 0,
        height: 70,
        indicatorColor: violet.withValues(alpha: .10),
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
    this.radius = 20,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
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

/// Blue / gold verification badge.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.tier = 'NONE', this.size = 16});

  final String tier; // NONE | NORMAL | PRO
  final double size;

  @override
  Widget build(BuildContext context) {
    if (tier == 'NONE') return const SizedBox.shrink();
    if (tier == 'PRO') {
      return ShaderMask(
        shaderCallback: (r) => SN.gradGold.createShader(r),
        child: Icon(Icons.verified_rounded, size: size, color: Colors.white),
      );
    }
    return Icon(Icons.verified_rounded, size: size, color: SN.indigo);
  }
}

String timeAgo(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso.toString());
  if (d == null) return '';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} ي';
  if (diff.inDays < 30) return 'قبل ${(diff.inDays / 7).floor()} أسبوع';
  if (diff.inDays < 365) return 'قبل ${(diff.inDays / 30).floor()} شهر';
  return 'قبل ${(diff.inDays / 365).floor()} سنة';
}

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// ---------------------------------------------------------------------------
/// SocialNova — Nova UI kit (V88)
///
/// One source of truth for the Live + Messenger presentation layer that was
/// designed on top of the SocialNova dark theme (`SN`). Every widget here is
/// presentation-only: it never fetches, never invents data and never mutates
/// state, so screens can adopt it without touching their logic.
///
/// Performance rules baked into the kit:
///  * motion is transform/opacity only (no layout thrash, no setState storms);
///  * glass surfaces are cheap single-pass `BackdropFilter`s, and callers can
///    set `blur: 0` for long scrolling lists (chat rows) to save GPU time;
///  * painters repaint only when their animation value changes.
/// ---------------------------------------------------------------------------
class NovaTokens {
  NovaTokens._();

  // Radius scale
  static const double rXs = 8;
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rBubble = 18;
  static const double rCard = 20;
  static const double rXl = 26;
  static const double rPill = 999;

  // Spacing scale
  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gap = 12;
  static const double pad = 16;

  // Motion (transform/opacity only)
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration pulse = Duration(milliseconds: 1400);
  static const Duration hearts = Duration(milliseconds: 2400);

  /// Translucent dark surface used on top of video/photo content.
  static Color get glass => const Color(0xFF05070F).withValues(alpha: .48);
  static Color get glassStrong => const Color(0xFF05070F).withValues(alpha: .62);
  static Color get hairline => Colors.white.withValues(alpha: .14);

  static const EdgeInsets pillPad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
  static const EdgeInsets bubblePad = EdgeInsets.symmetric(horizontal: 12, vertical: 9);

  static TextStyle get micro => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: SN.textSec,
        height: 1.2,
      );
  static TextStyle get label => const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: SN.textSec,
        height: 1.25,
      );

  /// Comment author name: accent gradient, clipped to the glyphs.
  /// Uses a plain (non-directional) alignment because ShaderMask resolves the
  /// shader without a TextDirection.
  static const ShaderCallback nameShader = _nameShader;
  static Shader _nameShader(Rect bounds) => const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [SN.cyan, SN.violet],
      ).createShader(bounds);
}

/// Frosted, hairline-bordered surface. `blur: 0` renders a flat tinted box
/// (use that inside long lists so we never stack dozens of blur passes).
class NovaGlass extends StatelessWidget {
  const NovaGlass({
    super.key,
    required this.child,
    this.radius = NovaTokens.rMd,
    this.padding = NovaTokens.pillPad,
    this.tint,
    this.border = true,
    this.blur = 14,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final bool border;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? NovaTokens.glass,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: NovaTokens.hairline) : null,
      ),
      child: child,
    );
    if (blur <= 0) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}

/// Pulsing red LIVE flag (opacity + scale only).
class NovaLiveBadge extends StatefulWidget {
  const NovaLiveBadge({super.key, this.label = 'مباشر', this.compact = false});
  final String label;
  final bool compact;

  @override
  State<NovaLiveBadge> createState() => _NovaLiveBadgeState();
}

class _NovaLiveBadgeState extends State<NovaLiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: NovaTokens.pulse)..repeat(reverse: true);
  late final Animation<double> _dot = Tween<double>(begin: 1, end: .35).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8, vertical: widget.compact ? 3 : 4),
        decoration: BoxDecoration(
          color: SN.red,
          borderRadius: BorderRadius.circular(NovaTokens.rXs),
          boxShadow: [BoxShadow(color: SN.red.withValues(alpha: .35), blurRadius: 12)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FadeTransition(
            opacity: _dot,
            child: Container(width: widget.compact ? 5 : 6, height: widget.compact ? 5 : 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 5),
          Text(
            widget.label,
            style: TextStyle(color: Colors.white, fontSize: widget.compact ? 9 : 10, fontWeight: FontWeight.w900, letterSpacing: .2),
          ),
        ]),
      );
}

/// Glass pill: icon + text. Used for viewers, taps, gift score, challenge.
class NovaStatPill extends StatelessWidget {
  const NovaStatPill({
    super.key,
    required this.icon,
    required this.text,
    this.color = Colors.white,
    this.iconColor,
    this.gradient,
    this.blur = 12,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color? iconColor;
  final Gradient? gradient;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gradient == null ? NovaTokens.glass : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(NovaTokens.rPill),
        border: gradient == null ? Border.all(color: NovaTokens.hairline) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: iconColor ?? color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ]),
    );
    final wrapped = onTap == null ? inner : InkWell(borderRadius: BorderRadius.circular(NovaTokens.rPill), onTap: onTap, child: inner);
    if (gradient != null || blur <= 0) return wrapped;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NovaTokens.rPill),
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: wrapped),
    );
  }
}

/// Circular glass icon button used across the Live layer.
class NovaGlassIcon extends StatelessWidget {
  const NovaGlassIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.tint,
    this.size = 34,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final Color? tint;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final btn = ClipRRect(
      borderRadius: BorderRadius.circular(NovaTokens.rPill),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: active ? SN.violet.withValues(alpha: .85) : (tint ?? NovaTokens.glass),
          borderRadius: BorderRadius.circular(NovaTokens.rPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(NovaTokens.rPill),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: Colors.white),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Segmented, pill-style tabs (Messenger filters, Live categories).
class NovaTabs<T> extends StatelessWidget {
  const NovaTabs({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SN.bg2,
            borderRadius: BorderRadius.circular(NovaTokens.rMd),
            border: Border.all(color: SN.strokeSoft),
          ),
          child: Row(
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(values[i]),
                    child: AnimatedContainer(
                      duration: NovaTokens.quick,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: values[i] == selected ? SN.violet : Colors.transparent,
                        borderRadius: BorderRadius.circular(NovaTokens.rSm),
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: values[i] == selected ? Colors.white : SN.textMut,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// One Live comment: glass bubble, accent-gradient author, reply chip, pin.
class NovaCommentTile extends StatelessWidget {
  const NovaCommentTile({
    super.key,
    required this.username,
    required this.body,
    this.avatarUrl = '',
    this.userId,
    this.replyToName = '',
    this.pinned = false,
    this.onTap,
    this.onLongPress,
    this.onAvatarTap,
    this.onNameTap,
    this.onReply,
    this.trailingIcon,
    this.trailingColor,
    this.blur = 12,
  });

  final String username;
  final String body;
  final String avatarUrl;
  final String? userId;
  final String replyToName;
  final bool pinned;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;
  final VoidCallback? onReply;
  final IconData? trailingIcon;
  final Color? trailingColor;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * .86;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: NovaGlass(
              blur: blur,
              radius: NovaTokens.rBubble,
              padding: NovaTokens.bubblePad,
              tint: pinned ? const Color(0xFF3A2445).withValues(alpha: .9) : NovaTokens.glass,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: SNav(url: avatarUrl, name: username.isEmpty ? '?' : username, size: 30, ring: pinned),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: NovaTokens.nameShader,
                                child: GestureDetector(
                                  onTap: onNameTap,
                                  child: Text(
                                    username.isEmpty ? 'مستخدم' : username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                            if (pinned) const Padding(
                              padding: EdgeInsetsDirectional.only(start: 4),
                              child: Icon(Icons.push_pin_rounded, color: SN.gold, size: 12),
                            ),
                            if (onReply != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(onTap: onReply, child: const Icon(Icons.reply_rounded, color: Colors.white54, size: 14)),
                            ],
                            if (trailingIcon != null) ...[
                              const SizedBox(width: 6),
                              Icon(trailingIcon, color: trailingColor ?? Colors.white54, size: 14),
                            ],
                          ],
                        ),
                        if (replyToName.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 3, bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(NovaTokens.rXs),
                            ),
                            child: Text('رد على $replyToName', style: const TextStyle(color: Colors.white60, fontSize: 9)),
                          ),
                        Text(body, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.28)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-dot "typing" bubble (ListedWidget friendly; animation is opacity only).
class NovaTypingDots extends StatefulWidget {
  const NovaTypingDots({super.key, this.dark = false});
  final bool dark;

  @override
  State<NovaTypingDots> createState() => _NovaTypingDotsState();
}

class _NovaTypingDotsState extends State<NovaTypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dark ? SN.bg2 : SN.textMut;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsetsDirectional.only(end: i == 2 ? 0 : 4),
              child: Opacity(
                opacity: .3 + .7 * (1 - ((_c.value + i / 3) % 1)).clamp(0.0, 1.0),
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Messenger inbox row: avatar (+ online dot), name, verified badge, preview,
/// time and unread counter.
class NovaChatRow extends StatelessWidget {
  const NovaChatRow({
    super.key,
    required this.name,
    required this.preview,
    required this.onTap,
    this.avatarUrl = '',
    this.username = '',
    this.verificationTier = 'NONE',
    this.timeLabel = '',
    this.unread = 0,
    this.online = false,
    this.lastSeen,
    this.showOnlineStatus = true,
    this.typing = false,
    this.onAvatarTap,
    this.onNameTap,
    this.statusRings = const <String,dynamic>{},
    this.onLongPress,
  });

  final String name;
  final String preview;
  final VoidCallback onTap;
  final String avatarUrl;
  final String username;
  final String verificationTier;
  final String timeLabel;
  final int unread;
  final bool online;
  final String? lastSeen;
  final bool showOnlineStatus;
  final bool typing;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;
  final Map<String,dynamic> statusRings;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(NovaTokens.rCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  StatusAvatar(url: avatarUrl, name: name, size: 50, status: statusRings),
                  if (online)
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(color: SN.green, shape: BoxShape.circle, border: Border.all(color: SN.bg0, width: 2.4)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(onTap: onNameTap, child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: SN.textPri),
                        )),
                      ),
                      const SizedBox(width: 4),
                      VerifiedBadge(tier: verificationTier, size: 14),
                      const Spacer(),
                      if (timeLabel.isNotEmpty)
                        Text(timeLabel, style: TextStyle(fontSize: 10.5, color: hasUnread ? SN.cyan : SN.textMut, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (showOnlineStatus && (online || (lastSeen ?? '').isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 1, bottom: 1),
                      child: Text(
                        online ? 'متصل الآن' : 'كان متصلًا ${timeAgo(lastSeen)}',
                        style: TextStyle(fontSize: 10.5, color: online ? SN.green : SN.textMut, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: typing
                            ? Row(children: const [
                                Text('يكتب الآن…', style: TextStyle(fontSize: 12, color: SN.cyan, fontWeight: FontWeight.w800)),
                                SizedBox(width: 6),
                                NovaTypingDots(),
                              ])
                            : Text(
                                preview.isEmpty ? '@$username' : preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: hasUnread ? SN.textPri : SN.textMut,
                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsetsDirectional.only(start: 6),
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: SN.violet, borderRadius: BorderRadius.circular(NovaTokens.rPill)),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat bubble shell with tails: outgoing right, incoming left (RTL aware).
class NovaBubble extends StatelessWidget {
  const NovaBubble({
    super.key,
    required this.child,
    required this.mine,
    this.padding = NovaTokens.bubblePad,
    this.maxWidthFactor = .74,
    this.tail = true,
  });

  final Widget child;
  final bool mine;
  final EdgeInsetsGeometry padding;
  final double maxWidthFactor;
  final bool tail;

  /// Direction-aware tail: it always sits under the sender's shoulder, so the
  /// same bubble renders correctly in RTL and LTR.
  static BorderRadiusGeometry radiusFor({required bool tailAtEnd, double r = NovaTokens.rBubble, bool tail = true}) {
    final big = Radius.circular(r);
    if (!tail) return BorderRadius.all(big);
    const tailR = Radius.circular(5);
    return BorderRadiusDirectional.only(
      topStart: big,
      topEnd: big,
      bottomStart: tailAtEnd ? big : tailR,
      bottomEnd: tailAtEnd ? tailR : big,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * maxWidthFactor),
      padding: padding,
      decoration: BoxDecoration(
        gradient: mine ? SN.grad : null,
        color: mine ? null : SN.bg2,
        borderRadius: radiusFor(tailAtEnd: mine, tail: tail),
        border: mine ? null : Border.all(color: SN.strokeSoft),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .16), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }
}

/// Voice note bubble: play affordance, waveform, duration.
class NovaVoiceNote extends StatelessWidget {
  const NovaVoiceNote({super.key, required this.mine, this.seconds = 0, this.onPlay, this.progress = 0});

  final bool mine;
  final int seconds;
  final VoidCallback? onPlay;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final fg = mine ? Colors.white : SN.textPri;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPlay,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .22) : SN.bg3, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow_rounded, size: 19, color: fg),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          height: 24,
          child: CustomPaint(painter: _WavePainter(color: fg, progress: progress)),
        ),
        const SizedBox(width: 8),
        Text('$mm:$ss', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: mine ? Colors.white70 : SN.textMut)),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color, required this.progress});
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 16;
    final step = size.width / bars;
    for (var i = 0; i < bars; i++) {
      final t = i / bars;
      final h = 5 + (math.sin(i * 1.7).abs() * 15);
      final played = t <= progress;
      final p = Paint()
        ..color = color.withValues(alpha: played ? .95 : .38)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4;
      final x = i * step + step / 2;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.progress != progress || old.color != color;
}

/// Double-tick read receipt (single tick once sent, double when delivered/read).
class NovaTicks extends StatelessWidget {
  const NovaTicks({super.key, required this.read, required this.delivered, this.mine = true});

  final bool read;
  final bool delivered;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final icon = (read || delivered) ? Icons.done_all_rounded : Icons.check_rounded;
    final color = read ? SN.cyan : (mine ? Colors.white70 : SN.textMut);
    return Icon(icon, size: 14, color: color);
  }
}

/// Dark glass composer that replaces the legacy light bar in Messenger.
class NovaComposer extends StatelessWidget {
  const NovaComposer({
    super.key,
    required this.field,
    required this.onPrimary,
    required this.primaryIcon,
    this.leading = const [],
    this.secondary,
    this.recordingNote,
    this.busy = false,
  });

  final Widget field;
  final VoidCallback? onPrimary;
  final IconData primaryIcon;
  final List<Widget> leading;
  final Widget? secondary;
  final String? recordingNote;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: NovaGlass(
          radius: NovaTokens.rPill,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          blur: 16,
          child: Row(
            children: [
              ...leading,
              const SizedBox(width: 4),
              Expanded(
                child: recordingNote != null
                    ? Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(recordingNote!, style: const TextStyle(color: SN.textSec, fontSize: 12.5)))
                    : field,
              ),
              if (secondary != null) secondary!,
              const SizedBox(width: 4),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: SN.grad, shape: BoxShape.circle, boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .35), blurRadius: 14)]),
                child: IconButton(
                  onPressed: busy ? null : onPrimary,
                  icon: Icon(primaryIcon, color: Colors.white, size: 22),
                  tooltip: 'إرسال',
                ),
              ),
            ],
          ),
        ),
      );
}

/// Rising-hearts layer for Live taps/gestures. Driven by a ValueNotifier<int>
/// burst counter so the parent page stays the only owner of Live state.
/// Cost: one CustomPaint, transform/opacity only, no widget rebuild per heart.
class NovaHeartsOverlay extends StatefulWidget {
  const NovaHeartsOverlay({super.key, required this.burst, this.color = SN.pink});

  final ValueNotifier<int> burst;
  final Color color;

  @override
  State<NovaHeartsOverlay> createState() => _NovaHeartsOverlayState();
}

class _NovaHeartsOverlayState extends State<NovaHeartsOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: NovaTokens.hearts);
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    widget.burst.addListener(_onBurst);
  }

  @override
  void didUpdateWidget(covariant NovaHeartsOverlay old) {
    super.didUpdateWidget(old);
    if (old.burst != widget.burst) {
      old.burst.removeListener(_onBurst);
      widget.burst.addListener(_onBurst);
    }
  }

  void _onBurst() {
    if (!mounted) return;
    _seed++;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.burst.removeListener(_onBurst);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _HeartsPainter(t: _c.value, seed: _seed, color: widget.color),
            size: Size.infinite,
          ),
        ),
      );
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter({required this.t, required this.seed, required this.color});
  final double t;
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final rnd = math.Random(seed);
    const count = 7;
    for (var i = 0; i < count; i++) {
      final delay = rnd.nextDouble() * .3;
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final baseX = size.width * (.68 + rnd.nextDouble() * .24);
      final wobble = math.sin(p * math.pi * 2.2 + i) * 16;
      final y = size.height * .96 - p * size.height * .78;
      final opacity = ((1 - p) * .95).clamp(0.0, 1.0);
      final scale = .55 + p * .55;
      canvas.save();
      canvas.translate(baseX + wobble, y);
      canvas.scale(scale);
      final paint = Paint()..color = color.withValues(alpha: opacity);
      final path = Path()
        ..moveTo(0, 12)
        ..cubicTo(16, -2, 22, -14, 10, -18)
        ..cubicTo(4, -20, 0, -14, 0, -10)
        ..cubicTo(0, -14, -4, -20, -10, -18)
        ..cubicTo(-22, -14, -16, -2, 0, 12)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter old) => old.t != t || old.seed != seed || old.color != color;
}

/// Live discovery card (explore grid).
class NovaLiveTile extends StatelessWidget {
  const NovaLiveTile({
    super.key,
    required this.title,
    required this.hostName,
    required this.onTap,
    this.hostAvatar = '',
    this.viewers = 0,
    this.gradientSeed = 0,
    this.height = 150,
  });

  final String title;
  final String hostName;
  final VoidCallback onTap;
  final String hostAvatar;
  final int viewers;
  final int gradientSeed;
  final double height;

  static const _seeds = <List<Color>>[
    [Color(0xFF7C4DFF), Color(0xFF1B1035)],
    [Color(0xFFFF4F86), Color(0xFF2A0A1C)],
    [Color(0xFF2AA7FF), Color(0xFF071B33)],
    [Color(0xFFFFB300), Color(0xFF2A1B05)],
    [Color(0xFF34D399), Color(0xFF04241B)],
  ];

  @override
  Widget build(BuildContext context) {
    final pair = _seeds[gradientSeed.abs() % _seeds.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NovaTokens.rCard),
          border: Border.all(color: SN.strokeSoft),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NovaTokens.rCard - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pair[0], pair[1]]))),
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .82)], stops: const [.35, 1])))),
              Positioned(top: 8, right: 8, child: NovaLiveBadge(compact: true, label: 'مباشر')),
              Positioned(top: 8, left: 8, child: NovaStatPill(icon: Icons.visibility_rounded, text: _compact(viewers))),
              Center(
                child: Opacity(
                  opacity: .92,
                  child: SNav(url: hostAvatar, name: hostName, size: 52, ring: true),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(hostName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Section header with an optional action ("مذيعون نشطون الآن" → عرض الكل).
class NovaSectionTitle extends StatelessWidget {
  const NovaSectionTitle({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900))),
            if (action != null)
              GestureDetector(
                onTap: onAction,
                child: Text(action!, style: const TextStyle(fontSize: 11, color: SN.cyan, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      );
}

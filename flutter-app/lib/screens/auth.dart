import 'package:flutter/material.dart';
import '../core/localization.dart';

import '../core/api.dart';
import '../core/push_notifications.dart';
import '../core/theme.dart';
import 'home.dart';

/// SocialNova v9 sign-in / sign-up.
/// The birthday field is state-driven (no controller rebuilt every frame) and
/// the picker is opened through a helper that is guaranteed to be wired to the
/// localisations delegates, which fixes the "birthday button does nothing" bug.
class _AuthParticle {
  final int seed;
  _AuthParticle(this.seed);
  double get x => ((seed * 37) % 100) / 100.0;
  double get y => ((seed * 61) % 100) / 100.0;
  double get size => 2.0 + (seed % 4);
}

class _AuthParticlesPainter extends CustomPainter {
  final List<_AuthParticle> particles;
  final double t;
  _AuthParticlesPainter(this.particles, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final dx = p.x * size.width + (t * 34 * (p.seed.isEven ? 1 : -1));
      final dy = ((p.y + t * .18 + p.seed * .003) % 1.0) * size.height;
      paint.color = (p.seed.isEven ? SN.violet : SN.cyan).withValues(alpha: .16);
      canvas.drawCircle(Offset(dx % size.width, dy), p.size, paint);
    }
  }
  @override bool shouldRepaint(covariant _AuthParticlesPainter oldDelegate) => true;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  final List<_AuthParticle> _particles = List.generate(18, (i) => _AuthParticle(i));
  bool registerMode = false;
  bool busy = false;
  bool obscure = true;
  bool serverDown = false;

  final loginCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final mailCtrl = TextEditingController();

  DateTime? birth;
  String gender = '';

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
    _probe();
  }

  @override
  void dispose() {
    loginCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    userCtrl.dispose();
    mailCtrl.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final ok = await Api.checkServer();
    if (!mounted) return;
    setState(() => serverDown = !ok);
  }

  Future<void> _pickBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birth ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (!mounted) return;
    if (picked != null) setState(() => birth = picked);
  }

  String get _birthLabel => birth == null
      ? 'لم يتم التحديد'
      : '${birth!.year}/${birth!.month.toString().padLeft(2, '0')}/${birth!.day.toString().padLeft(2, '0')}';

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (registerMode) {
        if (nameCtrl.text.trim().length < 2) throw Exception('الاسم الكامل مطلوب.');
        if (userCtrl.text.trim().length < 3) throw Exception('اسم المستخدم قصير جدًا (3 أحرف على الأقل).');
        await Api.register(
          userCtrl.text.trim(),
          mailCtrl.text.trim(),
          passCtrl.text,
          nameCtrl.text.trim(),
        );
        // Persist the extra onboarding fields on the freshly created account.
        final extra = <String, dynamic>{};
        if (birth != null) extra['birthDate'] = birth!.toUtc().toIso8601String();
        if (gender.isNotEmpty) extra['gender'] = gender;
        if (extra.isNotEmpty) {
          try {
            await Api.updateMe(extra);
          } catch (_) {}
        }
      } else {
        await Api.login(loginCtrl.text.trim(), passCtrl.text);
      }
      await initPushNotifications();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _editServer() async {
    final c = TextEditingController(text: Api.baseUrl);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('عنوان الخادم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اتركه فارغًا للعودة إلى العنوان الافتراضي.',
                style: TextStyle(fontSize: 12, color: SN.textSec)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://example.com'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('حفظ')),
        ],
      ),
    );
    c.dispose();
    if (r == null) return;
    await Api.setBaseUrl(r);
    if (!mounted) return;
    toast(context, 'عنوان الخادم: ${Api.baseUrl}');
    await _probe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [SN.bg1, SN.bg0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -90,
            child: _glow(300, SN.violet.withValues(alpha: .35)),
          ),
          Positioned(bottom: -150, left: -100, child: _glow(320, SN.cyan.withValues(alpha: .22))),
          Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _motion, builder: (_, __) => CustomPaint(painter: _AuthParticlesPainter(_particles, _motion.value))))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      const _Logo(),
                      const SizedBox(height: 16),
                      const Text('SocialNova',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: .5)),
                      const SizedBox(height: 4),
                      const Text('تواصل • شارك • اكتشف',
                          style: TextStyle(color: SN.textSec, fontSize: 13, letterSpacing: 1)),
                      if (serverDown) ...[const SizedBox(height: 18), _serverBanner()],
                      const SizedBox(height: 20),
                      if (registerMode) ..._registerForm() else ..._loginForm(),
                      const SizedBox(height: 18),
                      TextButton.icon(
                        onPressed: busy ? null : _editServer,
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: const Text('إعدادات الخادم'),
                      ),
                      const Text('A WHX Labs Product',
                          style: TextStyle(color: SN.textMut, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double s, Color c) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, Colors.transparent])),
      );

  Widget _serverBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3A2A12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8A6A20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined, color: SN.gold, size: 20),
                SizedBox(width: 8),
                Text(L10n.t('تعذّر الوصول إلى الخادم'), style: TextStyle(color: SN.gold, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text('العنوان الحالي: ${Api.baseUrl}',
                style: TextStyle(color: SN.textSec, fontSize: 11), textDirection: TextDirection.ltr),
            Row(children: [
              TextButton(onPressed: _probe, child: const Text('إعادة الفحص')),
              TextButton(onPressed: _editServer, child: const Text('تغيير العنوان')),
            ]),
          ],
        ),
      );

  List<Widget> _loginForm() => [
        const Text('مرحبًا بعودتك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('سجّل الدخول إلى حسابك', style: TextStyle(color: SN.textSec, fontSize: 13)),
        const SizedBox(height: 20),
        TextField(
          controller: loginCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني أو اسم المستخدم',
            prefixIcon: Icon(Icons.mail_outline, color: SN.textSec),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passCtrl,
          obscureText: obscure,
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: Icon(Icons.lock_outline, color: SN.textSec),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: SN.textSec, size: 20),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GradButton(label: 'تسجيل الدخول', icon: Icons.arrow_forward_rounded, busy: busy, onTap: submit),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ليس لديك حساب؟', style: TextStyle(color: SN.textSec)),
            TextButton(
              onPressed: busy ? null : () => setState(() => registerMode = true),
              child: const Text('إنشاء حساب'),
            ),
          ],
        ),
      ];

  List<Widget> _registerForm() => [
        Row(children: [
          IconButton(onPressed: () => setState(() => registerMode = false), icon: const Icon(Icons.arrow_back)),
          const Spacer(),
          const Text('حساب جديد', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline, color: SN.textSec)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: userCtrl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'اسم المستخدم',
            prefixIcon: Icon(Icons.alternate_email, color: SN.textSec),
            helperText: 'أحرف إنجليزية وأرقام و _ فقط',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: mailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline, color: SN.textSec)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passCtrl,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: 'كلمة المرور (6 أحرف على الأقل)',
            prefixIcon: Icon(Icons.lock_outline, color: SN.textSec),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: SN.textSec, size: 20),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Birthday: an InkWell-wrapped read-only field with a real state value.
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickBirth,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'تاريخ الميلاد',
              prefixIcon: Icon(Icons.cake_outlined, color: SN.textSec),
              suffixIcon: Icon(Icons.calendar_month_outlined, color: SN.violet),
            ),
            child: Text(
              _birthLabel,
              style: TextStyle(color: birth == null ? SN.textMut : SN.textPri),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: Text(L10n.t('الجنس'), style: TextStyle(color: SN.textSec, fontSize: 13))),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final g in const ['ذكر', 'أنثى', 'آخر'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => gender = g),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: gender == g ? SN.violet.withValues(alpha: .22) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: gender == g ? SN.violet : SN.stroke),
                      ),
                      child: Text(g,
                          style: TextStyle(
                            color: gender == g ? SN.textPri : SN.textSec,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        GradButton(label: 'إنشاء حساب', icon: Icons.person_add_alt_1, busy: busy, onTap: submit),
        const SizedBox(height: 12),
        const Text(
          'بالضغط على إنشاء حساب فإنك توافق على شروط الاستخدام وسياسة الخصوصية.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SN.textMut, fontSize: 11, height: 1.7),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('لديك حساب؟', style: TextStyle(color: SN.textSec)),
            TextButton(
              onPressed: busy ? null : () => setState(() => registerMode = false),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      ];
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: SN.grad,
          boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .45), blurRadius: 30, spreadRadius: 2)],
        ),
        child: const Icon(Icons.auto_awesome_rounded, size: 44, color: Colors.white),
      );
}

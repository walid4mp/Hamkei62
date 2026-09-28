import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    final maxDate = DateTime(now.year - 13, now.month, now.day);
    final initial = birth ?? DateTime(now.year - 20, now.month, now.day);
    var selectedYear = initial.year.clamp(1930, maxDate.year) as int;
    var selectedMonth = initial.month;
    var selectedDay = initial.day.clamp(1, DateUtils.getDaysInMonth(selectedYear, selectedMonth)) as int;
    final dayController = FixedExtentScrollController(initialItem: selectedDay - 1);
    final monthController = FixedExtentScrollController(initialItem: selectedMonth - 1);
    final yearController = FixedExtentScrollController(initialItem: selectedYear - 1930);
    const months = <String>[
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];

    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            final days = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
            if (selectedDay > days) selectedDay = days;
            final calculatedAge = now.year - selectedYear -
                ((now.month < selectedMonth ||
                        (now.month == selectedMonth && now.day < selectedDay))
                    ? 1
                    : 0);
            return Dialog(
              backgroundColor: const Color(0xFF081431),
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: SN.violet.withValues(alpha: .55)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101D4A), Color(0xFF050B1F)],
                  ),
                  boxShadow: [
                    BoxShadow(color: SN.violet.withValues(alpha: .20), blurRadius: 35, spreadRadius: 1),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: SN.grad,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('تاريخ الميلاد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                SizedBox(height: 3),
                                Text('اختر تاريخك بدقة — الحد الأدنى للعمر 13 سنة', style: TextStyle(color: SN.textMut, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, color: SN.textSec),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              SN.violet.withValues(alpha: .20),
                              SN.cyan.withValues(alpha: .08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: SN.violet.withValues(alpha: .42)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: SN.cyan, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('تاريخ الميلاد المختار',
                                      style: TextStyle(color: SN.textMut, fontSize: 10)),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${selectedDay.toString().padLeft(2, '0')} ${months[selectedMonth - 1]} $selectedYear',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: SN.bg2,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$calculatedAge سنة',
                                style: const TextStyle(
                                  color: SN.cyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 190,
                        child: Stack(
                          children: [
                            Center(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: SN.violet.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: SN.violet.withValues(alpha: .45)),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoPicker.builder(
                                    scrollController: dayController,
                                    itemExtent: 46,
                                    childCount: days,
                                    selectionOverlay: const SizedBox.shrink(),
                                    onSelectedItemChanged: (i) => setDialogState(() => selectedDay = i + 1),
                                    itemBuilder: (_, i) => Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: i + 1 == selectedDay ? 18 : 15,
                                          fontWeight: i + 1 == selectedDay ? FontWeight.w900 : FontWeight.w500,
                                          color: i + 1 == selectedDay ? Colors.white : SN.textMut,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: CupertinoPicker.builder(
                                    scrollController: monthController,
                                    itemExtent: 46,
                                    childCount: 12,
                                    selectionOverlay: const SizedBox.shrink(),
                                    onSelectedItemChanged: (i) {
                                      setDialogState(() {
                                        selectedMonth = i + 1;
                                        final maxDay = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
                                        if (selectedDay > maxDay) selectedDay = maxDay;
                                      });
                                    },
                                    itemBuilder: (_, i) => Center(
                                      child: Text(
                                        months[i],
                                        style: TextStyle(
                                          fontSize: i + 1 == selectedMonth ? 18 : 15,
                                          fontWeight: i + 1 == selectedMonth ? FontWeight.w900 : FontWeight.w500,
                                          color: i + 1 == selectedMonth ? Colors.white : SN.textMut,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: CupertinoPicker.builder(
                                    scrollController: yearController,
                                    itemExtent: 46,
                                    childCount: maxDate.year - 1930 + 1,
                                    selectionOverlay: const SizedBox.shrink(),
                                    onSelectedItemChanged: (i) {
                                      setDialogState(() {
                                        selectedYear = 1930 + i;
                                        final maxDay = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
                                        if (selectedDay > maxDay) selectedDay = maxDay;
                                      });
                                    },
                                    itemBuilder: (_, i) {
                                      final y = 1930 + i;
                                      return Center(
                                        child: Text(
                                          '$y',
                                          style: TextStyle(
                                            fontSize: y == selectedYear ? 18 : 15,
                                            fontWeight: y == selectedYear ? FontWeight.w900 : FontWeight.w500,
                                            color: y == selectedYear ? Colors.white : SN.textMut,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: SN.textSec,
                                side: BorderSide(color: SN.stroke),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: GradButton(
                              label: 'تأكيد التاريخ',
                              icon: Icons.check_rounded,
                              onTap: () => Navigator.pop(
                                dialogContext,
                                DateTime(selectedYear, selectedMonth, selectedDay),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    if (!mounted || picked == null) return;
    if (picked.isAfter(maxDate)) {
      toast(context, 'يجب أن يكون العمر 13 سنة أو أكثر.');
      return;
    }
    setState(() => birth = picked);
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
            Text('تعذر الاتصال بالخدمة الآن. اضغط لإعادة المحاولة.',
                style: TextStyle(color: SN.textSec, fontSize: 11)),
            TextButton(onPressed: _probe, child: const Text('إعادة المحاولة')),
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

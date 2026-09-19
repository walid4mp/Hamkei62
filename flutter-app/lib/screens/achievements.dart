import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

class AchievementItem {
  final String id, title, subtitle;
  final IconData icon;
  final int target;
  final int progress;
  final Color color;
  final bool seasonal;
  const AchievementItem({required this.id, required this.title, required this.subtitle, required this.icon, required this.target, required this.progress, required this.color, this.seasonal = false});
  double get ratio => target == 0 ? 1 : (progress / target).clamp(0, 1);
  bool get unlocked => progress >= target;
}

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});
  @override State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  int tab = 0;
  bool privateOnly = false;

  final items = const <AchievementItem>[
    AchievementItem(id: 'daily', title: 'المتفاعل اليومي', subtitle: 'تفاعل لمدة 7 أيام', icon: Icons.local_fire_department_rounded, target: 7, progress: 5, color: SN.pink),
    AchievementItem(id: 'comment', title: 'صوت المجتمع', subtitle: 'اكتب 25 تعليقًا مفيدًا', icon: Icons.chat_bubble_rounded, target: 25, progress: 18, color: SN.violet),
    AchievementItem(id: 'post', title: 'أول إبداع', subtitle: 'انشر أول منشور لك', icon: Icons.auto_awesome_rounded, target: 1, progress: 1, color: SN.gold),
    AchievementItem(id: 'friends', title: 'صانع العلاقات', subtitle: 'كوّن 10 صداقات', icon: Icons.people_alt_rounded, target: 10, progress: 6, color: SN.cyan),
    AchievementItem(id: 'live', title: 'نجم Live', subtitle: 'شارك في أول بث مباشر', icon: Icons.sensors_rounded, target: 1, progress: 1, color: SN.green),
    AchievementItem(id: 'creative', title: 'لمسة إبداعية', subtitle: 'شارك 5 أعمال إبداعية', icon: Icons.palette_rounded, target: 5, progress: 2, color: SN.indigo),
    AchievementItem(id: 'season', title: 'إنجاز موسمي', subtitle: 'إنجاز خاص بالموسم الحالي', icon: Icons.celebration_rounded, target: 3, progress: 1, color: SN.pink, seasonal: true),
  ];

  @override void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _shareAchievement(AchievementItem a) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('last_shared_achievement', a.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز الإنجاز للمشاركة في قصتك')));
  }

  @override Widget build(BuildContext context) {
    final filtered = items.where((a) => !privateOnly || a.unlocked).where((a) => tab == 0 || (tab == 1 ? a.unlocked : a.seasonal)).toList();
    final unlocked = items.where((a) => a.unlocked).length;
    final xp = items.fold<int>(0, (s, a) => s + (a.progress * 10));
    final level = 1 + (xp ~/ 100);
    final levelProgress = (xp % 100) / 100;
    return Scaffold(
      backgroundColor: SN.bg0,
      appBar: AppBar(title: const Text('لوحة الإنجازات', style: TextStyle(fontWeight: FontWeight.w900)), actions: [
        IconButton(tooltip: 'الإنجازات المحققة فقط', onPressed: () => setState(() => privateOnly = !privateOnly), icon: Icon(privateOnly ? Icons.verified_rounded : Icons.verified_outlined, color: SN.violet)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
        AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .18 + .12 * _pulse.value), blurRadius: 28, spreadRadius: 1)]),
          child: Row(children: [
            ScaleTransition(scale: Tween(begin: .96, end: 1.04).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)), child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .18), border: Border.all(color: Colors.white.withValues(alpha: .5))), child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 38))),
            const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('المستوى $level', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('$unlocked من ${items.length} إنجازات مكتملة', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: levelProgress, minHeight: 8, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white))), const SizedBox(height: 5), Text('${(levelProgress * 100).round()} XP حتى المستوى التالي', style: const TextStyle(color: Colors.white70, fontSize: 12))]))
          ]),
        )),
        const SizedBox(height: 18),
        SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('الكل'), icon: Icon(Icons.grid_view_rounded)), ButtonSegment(value: 1, label: Text('مكتملة'), icon: Icon(Icons.verified_rounded)), ButtonSegment(value: 2, label: Text('موسمية'), icon: Icon(Icons.auto_awesome_rounded))], selected: {tab}, onSelectionChanged: (s) => setState(() => tab = s.first)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('إنجازاتك', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text('${filtered.length} بطاقة', style: const TextStyle(color: SN.textMut))]),
        const SizedBox(height: 10),
        ...filtered.map((a) => _card(a)),
        const SizedBox(height: 12),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('💡 فكرة SocialNova', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('يمكن مشاركة الإنجاز المكتمل في القصة أو الملف الشخصي، وتظهر الشارة بجانب اسمك عند التفاعل.')])),
      ]),
    );
  }

  Widget _card(AchievementItem a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GlassCard(padding: const EdgeInsets.all(14), child: Row(children: [
    Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle, color: a.color.withValues(alpha: .12), border: Border.all(color: a.color.withValues(alpha: .28))), child: Icon(a.unlocked ? Icons.verified_rounded : a.icon, color: a.color, size: 30)),
    const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), if (a.seasonal) const Chip(label: Text('موسمي'), visualDensity: VisualDensity.compact)]), const SizedBox(height: 3), Text(a.subtitle, style: const TextStyle(color: SN.textSec, fontSize: 13)), const SizedBox(height: 9), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: a.ratio, minHeight: 6, backgroundColor: SN.strokeSoft, valueColor: AlwaysStoppedAnimation(a.color))), const SizedBox(height: 4), Text('${a.progress}/${a.target}', style: const TextStyle(color: SN.textMut, fontSize: 11))])),
    const SizedBox(width: 6), IconButton(tooltip: 'مشاركة', onPressed: a.unlocked ? () => _shareAchievement(a) : null, icon: const Icon(Icons.share_rounded)),
  ])));
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/widgets.dart';

class FitnessChallengesPage extends StatefulWidget {
  const FitnessChallengesPage({super.key});
  @override
  State<FitnessChallengesPage> createState() => _FitnessChallengesPageState();
}

class _FitnessChallengesPageState extends State<FitnessChallengesPage> {
  final List<_Challenge> challenges = const [
    _Challenge('نشاط 7 أيام', 'حافظ على نشاط بسيط يناسبك لمدة أسبوع', Icons.local_fire_department_rounded, 7, 'يوم'),
    _Challenge('خطواتك اليومية', 'سجّل خطواتك أو نشاطك اليومي', Icons.directions_walk_rounded, 7, 'يوم'),
    _Challenge('ترطيب يومي', 'تذكير بتسجيل أكواب الماء خلال اليوم', Icons.water_drop_rounded, 8, 'كوب'),
    _Challenge('جري الأسبوع', 'سجّل مسافتك الأسبوعية بدون مقارنة قسرية مع الآخرين', Icons.directions_run_rounded, 5, 'كم'),
    _Challenge('تمرين منزلي', 'نشاط منزلي قصير بدون معدات', Icons.fitness_center_rounded, 5, 'جلسات'),
    _Challenge('دقيقة نشاط', 'تحدٍ سريع للحركة اليومية حسب قدرتك', Icons.timer_rounded, 5, 'دقائق'),
  ];

  Map<String, int> progress = {};
  Set<String> joined = {};
  int teamPoints = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('fitness_progress') ?? [];
    final rawJoined = p.getStringList('fitness_joined') ?? [];
    if (!mounted) return;
    setState(() {
      for (final item in raw) {
        final parts = item.split('|');
        if (parts.length == 2) progress[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
      joined = rawJoined.toSet();
      teamPoints = p.getInt('fitness_team_points') ?? 0;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('fitness_progress', progress.entries.map((e) => '${e.key}|${e.value}').toList());
    await p.setStringList('fitness_joined', joined.toList());
    await p.setInt('fitness_team_points', teamPoints);
  }

  void _addProgress(_Challenge c) {
    final current = progress[c.id] ?? 0;
    if (current >= c.target) return;
    setState(() {
      progress[c.id] = (current + 1).clamp(0, c.target);
      teamPoints += 10;
    });
    _save();
  }

  void _toggleJoin(_Challenge c) {
    setState(() {
      if (joined.contains(c.id)) {
        joined.remove(c.id);
      } else {
        joined.add(c.id);
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final completed = challenges.where((c) => (progress[c.id] ?? 0) >= c.target).length;
    return Scaffold(
      appBar: AppBar(title: const Text('تحديات اللياقة'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: SN.cyan.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.sports_rounded, color: SN.cyan, size: 28)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تحرّك بطريقتك 🏃', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('تحديات صحية خفيفة، سجّل نشاطك وتابع تقدمك يومًا بيوم.', style: TextStyle(color: SN.textSec, height: 1.35))])),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _stat('مكتمل', '$completed/${challenges.length}', Icons.check_circle_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _stat('نقاط الفريق', '$teamPoints', Icons.groups_rounded)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          const Text('تحديات اليوم والأسبوع', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...challenges.map(_challengeCard),
          const SizedBox(height: 8),
          GlassCard(child: ListTile(leading: const Icon(Icons.emoji_events_rounded, color: SN.gold), title: const Text('الأوسمة الرياضية', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('النشيط • بطل التحدي • روح الفريق'), trailing: const Icon(Icons.chevron_left_rounded))),
          const SizedBox(height: 10),
          GlassCard(child: ListTile(leading: const Icon(Icons.groups_rounded, color: SN.violet), title: const Text('مجموعات التحدي', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('أنشئ تحديًا مع أصدقائك واجمعوا النقاط معًا'), trailing: const Icon(Icons.chevron_left_rounded))),
          const SizedBox(height: 10),
          GlassCard(child: ListTile(leading: const Icon(Icons.privacy_tip_outlined, color: SN.cyan), title: const Text('الخصوصية', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('المشاركة في الترتيب اختيارية، ولا تتم مشاركة بيانات الصحة دون إذنك.'))),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: SN.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: SN.strokeSoft)),
    child: Row(children: [Icon(icon, color: SN.cyan), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: SN.textSec, fontSize: 12)), Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]))]),
  );

  Widget _challengeCard(_Challenge c) {
    final value = progress[c.id] ?? 0;
    final done = value >= c.target;
    final isJoined = joined.contains(c.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: SN.violet.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(c.icon, color: SN.violet)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 3), Text(c.description, style: const TextStyle(color: SN.textSec, fontSize: 12, height: 1.3))])),
            IconButton(onPressed: () => _toggleJoin(c), tooltip: isJoined ? 'إلغاء المشاركة' : 'انضمام', icon: Icon(isJoined ? Icons.group_remove_rounded : Icons.group_add_rounded, color: isJoined ? SN.cyan : SN.textSec)),
          ]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: value / c.target, minHeight: 7))), const SizedBox(width: 10), Text('$value/${c.target} ${c.unit}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: done ? null : () => _addProgress(c), icon: Icon(done ? Icons.check_rounded : Icons.add_rounded), label: Text(done ? 'تم الإنجاز' : 'سجّل إنجازًا'))),
        ]),
      ),
    );
  }
}

class _Challenge {
  final String id;
  final String description;
  String get title => id;
  final IconData icon;
  final int target;
  final String unit;
  const _Challenge(this.id, this.description, this.icon, this.target, this.unit);
}

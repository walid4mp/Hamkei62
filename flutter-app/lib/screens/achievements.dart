import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});
  @override State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late Future<Map<String,dynamic>> _future;
  int tab = 0;
  bool completedOnly = false;

  @override void initState(){super.initState(); _future=Api.achievements();}
  @override void dispose(){_pulse.dispose(); super.dispose();}
  Future<void> _refresh() async { setState(() => _future=Api.achievements()); await _future; }
  IconData _icon(String key) { switch(key){case 'groups':return Icons.groups_rounded;case 'verified':return Icons.verified_rounded;case 'post':return Icons.article_rounded;case 'movie':return Icons.movie_creation_rounded;case 'comment':return Icons.chat_bubble_rounded;case 'live':return Icons.sensors_rounded;case 'heart':return Icons.favorite_rounded;case 'people':return Icons.people_alt_rounded;default:return Icons.emoji_events_rounded;} }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      appBar: AppBar(
        title: const Text('لوحة الإنجازات', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: Text('${snap.error}'),
            ));
          }
          final data = snap.data ?? <String, dynamic>{};
          final rows = <Map<String, dynamic>>[];
          final raw = data['tasks'];
          if (raw is List) {
            for (final e in raw) {
              if (e is Map) rows.add(Map<String, dynamic>.from(e));
            }
          }
          final filtered = rows.where((x) => !completedOnly || x['completed'] == true).toList();
          final unlocked = rows.where((x) => x['completed'] == true).length;
          final followers = (data['followers'] as num?)?.toInt() ?? 0;
          final xp = rows.fold<int>(0, (sum, x) {
            final progress = (x['progress'] as num?)?.toInt() ?? 0;
            final target = (x['target'] as num?)?.toInt() ?? 0;
            return sum + progress.clamp(0, target).toInt();
          });
          final level = 1 + xp ~/ 100;
          final levelProgress = (xp % 100) / 100;
          return RefreshIndicator(
            onRefresh: _refresh,
            color: SN.violet,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(28)),
                    child: Row(children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .18)),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 38),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('المستوى $level', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('$unlocked من ${rows.length} مهام مكتملة • $followers متابع', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: levelProgress,
                            minHeight: 8,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text('${(levelProgress * 100).round()} XP حتى المستوى التالي', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('الكل'), icon: Icon(Icons.grid_view_rounded)),
                      ButtonSegment(value: 1, label: Text('مكتملة'), icon: Icon(Icons.verified_rounded)),
                    ],
                    selected: <int>{tab},
                    onSelectionChanged: (s) { if (s.isNotEmpty) setState(() => tab = s.first); },
                  )),
                  IconButton(
                    onPressed: () => setState(() => completedOnly = !completedOnly),
                    icon: Icon(completedOnly ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, color: SN.violet),
                  ),
                ]),
                const SizedBox(height: 14),
                Text('مهامك ومكافآتك', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ...filtered.where((x) => tab == 0 || x['completed'] == true).map(_task),
                const SizedBox(height: 14),
                const Text('زيادات المتابعين والمشاهدات والتفاعلات الإدارية تدخل في العدادات والإنجازات.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _task(Map<String, dynamic> x) {
    final target = (x['target'] as num?)?.toInt() ?? 0;
    final progress = (x['progress'] as num?)?.toInt() ?? 0;
    final reward = (x['rewardCoins'] as num?)?.toInt() ?? 0;
    final done = x['completed'] == true;
    final color = done ? SN.gold : SN.violet;
    final value = target == 0 ? 1.0 : (progress / target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .12), border: Border.all(color: color.withValues(alpha: .28))),
            child: Icon(done ? Icons.verified_rounded : _icon('${x['icon'] ?? ''}'), color: color, size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${x['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              if (done) const Chip(label: Text('مكتملة'), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 3),
            Text('${x['description'] ?? ''}', style: TextStyle(color: SN.textSec, fontSize: 13)),
            const SizedBox(height: 9),
            LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: SN.strokeSoft, valueColor: AlwaysStoppedAnimation<Color>(color)),
            const SizedBox(height: 4),
            Row(children: [
              Text('$progress/$target', style: TextStyle(color: SN.textMut, fontSize: 11)),
              const Spacer(),
              if (reward > 0) Text('🎁 +$reward NovaCoin', style: TextStyle(color: SN.gold, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
            if (done) ...[
              const SizedBox(height: 7),
              Row(children: [
                Icon(x['rewardGranted'] == true ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, size: 15, color: x['rewardGranted'] == true ? SN.green : SN.gold),
                const SizedBox(width: 5),
                Text(x['rewardGranted'] == true ? 'تم استلام المكافأة وإضافتها للمحفظة' : 'جاري منح المكافأة تلقائيًا...', style: TextStyle(color: x['rewardGranted'] == true ? SN.green : SN.gold, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ],
          ])),
        ]),
      ),
    );
  }

}
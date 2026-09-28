import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/creator_levels.dart';
import '../core/nova_ui.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// V93 — Creator Rewards inside the app.
///
/// Shows the milestones a creator has actually earned (server-side, granted
/// once each), everything still locked with the progress towards it, and the
/// concrete rewards attached to each one (badge, frame, background, entry
/// effect, chat effect, gift and coins) — all read from the database, so an
/// admin edit shows up here without a release.
class CreatorRewardsPage extends StatefulWidget {
  const CreatorRewardsPage({super.key, required this.userId, this.displayName = ''});

  final String userId;
  final String displayName;

  @override
  State<CreatorRewardsPage> createState() => _CreatorRewardsPageState();
}

class _CreatorRewardsPageState extends State<CreatorRewardsPage> {
  bool _loading = true;
  String? _error;
  int _followers = 0;
  List<Map<String, dynamic>> _milestones = [];
  List<Map<String, dynamic>> _rewards = [];
  Map<String, dynamic>? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await Api.myMilestones();
      final rewards = await Api.myMilestoneRewards().catchError((_) => <dynamic>[]);
      if (!mounted) return;
      setState(() {
        _followers = (me['followers'] as num?)?.toInt() ?? 0;
        _milestones = ((me['earned'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _rewards = rewards.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _next = me['next'] is Map ? Map<String, dynamic>.from(me['next'] as Map) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Set<String> get _earnedIds => {
        for (final r in _rewards) '${r['milestoneId']}',
      };

  Map<String, dynamic> _payloadFor(String milestoneId) {
    for (final r in _rewards) {
      if ('${r['milestoneId']}' == milestoneId && r['payload'] is Map) {
        return Map<String, dynamic>.from(r['payload'] as Map);
      }
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('مكافآت المبدع'),
        actions: [
          IconButton(tooltip: 'تحديث', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        color: SN.violet,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(text: _error!),
                    const SizedBox(height: 12),
                    Center(child: FilledButton(onPressed: _load, child: const Text('إعادة المحاولة'))),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                    children: [
                      _headerCard(),
                      const SizedBox(height: 12),
                      if (_next != null) _nextCard(_next!),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Text('الإنجازات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      if (_milestones.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('لا توجد إنجازات متاحة بعد.', style: TextStyle(color: Colors.white70)),
                        ),
                      for (final m in _milestones) _milestoneCard(m),
                    ],
                  ),
      ),
    );
  }

  Widget _headerCard() => NovaGlass(
        radius: NovaTokens.rCard,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(gradient: SN.gradGold, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.displayName.isEmpty ? 'مستوى المبدع' : widget.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(children: [
                    CreatorLevelBadge(followers: _followers),
                    const SizedBox(width: 8),
                    Text('$_followers متابع',
                        style: const TextStyle(color: SN.textSec, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _nextCard(Map<String, dynamic> next) {
    final required = (next['followersRequired'] as num?)?.toInt() ?? 0;
    final remaining = (required - _followers).clamp(0, required);
    final progress = required <= 0 ? 1.0 : (_followers / required).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [SN.violet.withValues(alpha: .22), SN.cyan.withValues(alpha: .10)]),
        borderRadius: BorderRadius.circular(NovaTokens.rCard),
        border: Border.all(color: SN.violet.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الهدف التالي: ${next['title']}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 9,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(SN.cyan),
            ),
          ),
          const SizedBox(height: 6),
          Text('تبقّى $remaining متابع للوصول إلى $required',
              style: const TextStyle(color: SN.textSec, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _milestoneCard(Map<String, dynamic> m) {
    final id = '${m['id']}';
    final earned = _earnedIds.contains(id);
    final payload = _payloadFor(id);
    final followers = (m['followersRequired'] as num?)?.toInt() ?? 0;
    final accent = earned ? SN.gold : SN.textMut;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SN.bg1,
        borderRadius: BorderRadius.circular(NovaTokens.rCard),
        border: Border.all(color: accent.withValues(alpha: earned ? .55 : .25), width: earned ? 1.4 : 1),
        boxShadow: earned ? [BoxShadow(color: SN.gold.withValues(alpha: .18), blurRadius: 16)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(earned ? Icons.verified_rounded : Icons.lock_outline_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${m['title']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              Text('$followers متابع',
                  style: const TextStyle(color: SN.textMut, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if ('${payload['badge'] ?? m['badge'] ?? ''}'.isNotEmpty)
                _chip(Icons.military_tech_rounded, 'شارة ${payload['badge'] ?? m['badge']}'),
              if ('${payload['profileFrame'] ?? m['profileFrame'] ?? ''}'.isNotEmpty)
                _chip(Icons.crop_square_rounded, 'إطار ${payload['profileFrame'] ?? m['profileFrame']}'),
              if ('${payload['profileBackground'] ?? m['profileBackground'] ?? ''}'.isNotEmpty)
                _chip(Icons.wallpaper_rounded, 'خلفية ${payload['profileBackground'] ?? m['profileBackground']}'),
              if ('${payload['entryEffect'] ?? m['entryEffect'] ?? ''}'.isNotEmpty)
                _chip(Icons.auto_awesome_rounded, 'تأثير دخول ${payload['entryEffect'] ?? m['entryEffect']}'),
              if ('${payload['chatEffect'] ?? m['chatEffect'] ?? ''}'.isNotEmpty)
                _chip(Icons.chat_bubble_outline_rounded, 'تأثير دردشة ${payload['chatEffect'] ?? m['chatEffect']}'),
              if ('${payload['rewardGiftSlug'] ?? m['rewardGiftSlug'] ?? ''}'.isNotEmpty)
                _chip(Icons.card_giftcard_rounded, 'هدية ${payload['rewardGiftSlug'] ?? m['rewardGiftSlug']}'),
              if (((payload['rewardCoins'] ?? m['rewardCoins']) as num?)?.toInt() != null &&
                  ((payload['rewardCoins'] ?? m['rewardCoins']) as num).toInt() > 0)
                _chip(Icons.monetization_on_rounded,
                    '${((payload['rewardCoins'] ?? m['rewardCoins']) as num).toInt()} عملة'),
            ],
          ),
          if (earned) ...[
            const SizedBox(height: 8),
            const Text('تم منحها تلقائيًا ✅', style: TextStyle(color: SN.green, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: SN.cyan),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: SN.textSec, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

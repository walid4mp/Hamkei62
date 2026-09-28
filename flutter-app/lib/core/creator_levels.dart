import 'package:flutter/material.dart';

import 'api.dart';

/// A creator level as configured by the admin (thresholds are editable server
/// side via `PUT /api/admin/creator-levels`).
class CreatorLevel {
  const CreatorLevel({required this.key, required this.label, required this.minFollowers, required this.tier, required this.color});
  final String key;
  final String label;
  final int minFollowers;
  final int tier;
  final Color color;

  static CreatorLevel fromMap(Map<String, dynamic> m) => CreatorLevel(
        key: '${m['key'] ?? ''}',
        label: '${m['label'] ?? ''}',
        minFollowers: (m['minFollowers'] as num?)?.toInt() ?? 0,
        tier: (m['tier'] as num?)?.toInt() ?? 0,
        color: _hex('${m['color'] ?? ''}'),
      );
}

Color _hex(String value) {
  final v = value.replaceAll('#', '').trim();
  if (v.length != 6) return const Color(0xFF9CA3AF);
  return Color(int.parse('FF$v', radix: 16));
}

/// Levels are fetched once and cached for the session.
class CreatorLevels {
  CreatorLevels._();
  static List<CreatorLevel> _cache = const [];

  static List<CreatorLevel> get cached => _cache;

  static Future<List<CreatorLevel>> load({bool force = false}) async {
    if (_cache.isNotEmpty && !force) return _cache;
    try {
      final rows = await Api.creatorLevels();
      _cache = rows
          .map((e) => CreatorLevel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.minFollowers.compareTo(b.minFollowers));
    } catch (_) {
      // Keep the previous cache on failure.
    }
    return _cache;
  }

  /// Highest level the follower count qualifies for, or null below the first.
  static CreatorLevel? levelFor(int followers) {
    CreatorLevel? out;
    for (final l in _cache) {
      if (followers >= l.minFollowers) out = l;
    }
    return out;
  }
}

/// Small pill showing the creator level for [followers]. Renders nothing until
/// the levels are loaded or when the account has no level yet.
class CreatorLevelBadge extends StatefulWidget {
  const CreatorLevelBadge({super.key, required this.followers, this.compact = false});
  final int? followers;
  final bool compact;

  @override
  State<CreatorLevelBadge> createState() => _CreatorLevelBadgeState();
}

class _CreatorLevelBadgeState extends State<CreatorLevelBadge> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    CreatorLevels.load().then((_) { if (mounted) setState(() => _loaded = true); });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || widget.followers == null) return const SizedBox.shrink();
    final level = CreatorLevels.levelFor(widget.followers!);
    if (level == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 10, vertical: widget.compact ? 2 : 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [level.color.withValues(alpha: .28), level.color.withValues(alpha: .10)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color.withValues(alpha: .7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.workspace_premium_rounded, size: widget.compact ? 12 : 14, color: level.color),
        const SizedBox(width: 4),
        Text(
          level.label,
          style: TextStyle(color: level.color, fontSize: widget.compact ? 10 : 11, fontWeight: FontWeight.w900),
        ),
      ]),
    );
  }
}

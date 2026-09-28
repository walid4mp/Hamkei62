import 'package:flutter/material.dart';

import '../../core/api.dart';

/// SocialNova V93 — the in-app admin console.
///
/// Every button here performs a real API call against a permission-guarded
/// endpoint (gifts, assets, creator rewards, Nova TV content). Nothing is a
/// placeholder: the lists are loaded from the server, edits are persisted and
/// the server rejects callers that lack the matching permission.
class AdminConsolePage extends StatelessWidget {
  const AdminConsolePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز الإدارة'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.card_giftcard_rounded), text: 'الهدايا'),
              Tab(icon: Icon(Icons.collections_rounded), text: 'الأصول'),
              Tab(icon: Icon(Icons.emoji_events_rounded), text: 'المكافآت'),
              Tab(icon: Icon(Icons.movie_rounded), text: 'Nova TV'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GiftsTab(),
            _AssetsTab(),
            _RewardsTab(),
            _NovaTvTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// shared bits
// ─────────────────────────────────────────────────────────────────────────────

class _AsyncBody extends StatelessWidget {
  const _AsyncBody({required this.loading, required this.error, required this.child, required this.onRetry});

  final bool loading;
  final String? error;
  final Widget child;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 10),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => onRetry(), child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    return child;
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
      ],
    ),
  );
  return ok == true;
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

/// A tiny form builder: one dialog, a list of (label, controller) fields.
class _FieldSpec {
  _FieldSpec(this.label, this.controller, {this.keyboard = TextInputType.text, this.hint = ''});
  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final String hint;
}

Future<Map<String, String>?> _formDialog(
  BuildContext context, {
  required String title,
  required List<_FieldSpec> fields,
  String submitLabel = 'حفظ',
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: f.controller,
                    keyboardType: f.keyboard,
                    decoration: InputDecoration(labelText: f.label, hintText: f.hint, border: const OutlineInputBorder()),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, {for (final f in fields) f.label: f.controller.text.trim()}),
          child: Text(submitLabel),
        ),
      ],
    ),
  );
}

int _int(Map<String, String> m, String k, [int fallback = 0]) => int.tryParse(m[k] ?? '') ?? fallback;
bool _bool(Map<String, String> m, String k) => (m[k] ?? '').toLowerCase() == 'true' || (m[k] ?? '') == '1' || (m[k] ?? '').toLowerCase() == 'نعم';

// ─────────────────────────────────────────────────────────────────────────────
// Gifts
// ─────────────────────────────────────────────────────────────────────────────

class _GiftsTab extends StatefulWidget {
  const _GiftsTab();
  @override
  State<_GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<_GiftsTab> {
  List<dynamic> _gifts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Api.adminGifts();
      setState(() { _gifts = (res['gifts'] as List?) ?? const []; _loading = false; });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل مكتبة الهدايا: ${_err(e)}'; _loading = false; });
    }
  }

  Future<void> _edit({Map<String, dynamic>? gift}) async {
    final isNew = gift == null;
    final fields = [
      _FieldSpec('slug', TextEditingController(text: '${gift?['slug'] ?? ''}'), hint: 'love_001 (اتركه فارغًا للتوليد)'),
      _FieldSpec('name', TextEditingController(text: '${gift?['name'] ?? ''}')),
      _FieldSpec('nameEn', TextEditingController(text: '${gift?['nameEn'] ?? ''}')),
      _FieldSpec('emoji', TextEditingController(text: '${gift?['emoji'] ?? '🎁'}')),
      _FieldSpec('priceCoins', TextEditingController(text: '${gift?['priceCoins'] ?? 100}'), keyboard: TextInputType.number),
      _FieldSpec('category', TextEditingController(text: '${gift?['category'] ?? 'love'}'), hint: 'love | luxury | tech | nature | food | music | sport'),
      _FieldSpec('rarity', TextEditingController(text: '${gift?['rarity'] ?? 'COMMON'}'), hint: 'COMMON | RARE | EPIC | LEGENDARY | MYTHIC'),
      _FieldSpec('effectKey', TextEditingController(text: '${gift?['effectKey'] ?? 'bloom'}'), hint: 'drop | rise | drive | fly | shake | bloom'),
      _FieldSpec('imageUrl', TextEditingController(text: '${gift?['imageUrl'] ?? ''}'), hint: 'رابط الصورة الحقيقية (اختياري)'),
      _FieldSpec('premium', TextEditingController(text: '${gift?['premium'] ?? false}'), hint: 'true / false'),
      _FieldSpec('enabled', TextEditingController(text: '${gift?['enabled'] ?? true}'), hint: 'true / false'),
    ];
    final out = await _formDialog(context, title: isNew ? 'هدية جديدة' : 'تعديل هدية', fields: fields);
    if (out == null) return;
    final body = <String, dynamic>{
      'name': out['name'],
      'nameEn': out['nameEn'] ?? '',
      'emoji': out['emoji'] ?? '🎁',
      'priceCoins': _int(out, 'priceCoins', 100),
      'category': out['category'] ?? 'love',
      'rarity': (out['rarity'] ?? 'COMMON').toUpperCase(),
      'effectKey': out['effectKey'] ?? 'bloom',
      'animationFamily': out['effectKey'] ?? 'bloom',
      'imageUrl': out['imageUrl'] ?? '',
      'premium': _bool(out, 'premium'),
      'enabled': _bool(out, 'enabled'),
    };
    if ((out['slug'] ?? '').isNotEmpty) body['slug'] = out['slug'];
    try {
      if (isNew) {
        await Api.createGift(body);
      } else {
        await Api.updateGift('${gift['id']}', body);
      }
      if (!mounted) return;
      _toast(context, isNew ? 'أُنشئت الهدية' : 'حُدّثت الهدية');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncBody(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(child: Text('${_gifts.length} هدية في المكتبة', style: const TextStyle(fontWeight: FontWeight.w800))),
                FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('هدية جديدة')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _gifts.length,
              itemBuilder: (_, i) {
                final g = Map<String, dynamic>.from(_gifts[i] as Map);
                final enabled = g['enabled'] == true;
                return Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 44,
                      height: 44,
                      child: (g['imageUrl'] ?? '').toString().isEmpty
                          ? Center(child: Text('${g['emoji']}', style: const TextStyle(fontSize: 24)))
                          : Image.network(
                              '${Api.baseUrl}${g['imageUrl']}',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(child: Text('${g['emoji']}', style: const TextStyle(fontSize: 24))),
                            ),
                    ),
                    title: Text('${g['name']}  •  ${g['rarity']}'),
                    subtitle: Text('${g['slug']}  |  ${g['priceCoins']} NVC  |  ${g['category']}${g['premium'] == true ? '  |  PRO' : ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: enabled,
                          onChanged: (v) async {
                            try {
                              await Api.updateGift('${g['id']}', {'enabled': v});
                              await _load();
                            } catch (e) {
                              if (mounted) _toast(context, 'فشل التحديث: ${_err(e)}');
                            }
                          },
                        ),
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(gift: g)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assets
// ─────────────────────────────────────────────────────────────────────────────

class _AssetsTab extends StatefulWidget {
  const _AssetsTab();
  @override
  State<_AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<_AssetsTab> {
  List<dynamic> _assets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Api.adminAssets();
      setState(() { _assets = rows; _loading = false; });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل الأصول: ${_err(e)}'; _loading = false; });
    }
  }

  Future<void> _edit({Map<String, dynamic>? asset}) async {
    final isNew = asset == null;
    final fields = [
      _FieldSpec('type', TextEditingController(text: '${asset?['type'] ?? 'GIFT'}'), hint: 'GIFT | THEME | BACKGROUND | FRAME | ENTRY_EFFECT | CHAT_EFFECT | CREATOR_REWARD'),
      _FieldSpec('name', TextEditingController(text: '${asset?['name'] ?? ''}')),
      _FieldSpec('assetUrl', TextEditingController(text: '${asset?['assetUrl'] ?? ''}')),
      _FieldSpec('previewUrl', TextEditingController(text: '${asset?['previewUrl'] ?? ''}')),
      _FieldSpec('animationUrl', TextEditingController(text: '${asset?['animationUrl'] ?? ''}')),
      _FieldSpec('soundUrl', TextEditingController(text: '${asset?['soundUrl'] ?? ''}')),
      _FieldSpec('priceCoins', TextEditingController(text: '${asset?['priceCoins'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('requiredFollowers', TextEditingController(text: '${asset?['requiredFollowers'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('requiredLevel', TextEditingController(text: '${asset?['requiredLevel'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('premium', TextEditingController(text: '${asset?['premium'] ?? false}'), hint: 'true / false'),
      _FieldSpec('enabled', TextEditingController(text: '${asset?['enabled'] ?? true}'), hint: 'true / false'),
    ];
    final out = await _formDialog(context, title: isNew ? 'أصل جديد' : 'تعديل أصل', fields: fields);
    if (out == null) return;
    final body = <String, dynamic>{
      'type': (out['type'] ?? 'GIFT').toUpperCase(),
      'name': out['name'],
      'assetUrl': out['assetUrl'] ?? '',
      'previewUrl': out['previewUrl'] ?? '',
      'animationUrl': out['animationUrl'] ?? '',
      'soundUrl': out['soundUrl'] ?? '',
      'priceCoins': _int(out, 'priceCoins'),
      'requiredFollowers': _int(out, 'requiredFollowers'),
      'requiredLevel': _int(out, 'requiredLevel'),
      'premium': _bool(out, 'premium'),
      'enabled': _bool(out, 'enabled'),
    };
    try {
      if (isNew) {
        await Api.createAsset(body);
      } else {
        await Api.updateAsset('${asset['id']}', body);
      }
      if (!mounted) return;
      _toast(context, isNew ? 'أُضيف الأصل' : 'حُدّث الأصل');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncBody(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(child: Text('${_assets.length} أصل مركزي', style: const TextStyle(fontWeight: FontWeight.w800))),
                FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('أصل جديد')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _assets.length,
              itemBuilder: (_, i) {
                final a = Map<String, dynamic>.from(_assets[i] as Map);
                return Card(
                  child: ListTile(
                    leading: Icon(a['type'] == 'GIFT' ? Icons.card_giftcard : Icons.collections_rounded),
                    title: Text('${a['name']}  •  ${a['type']}'),
                    subtitle: Text('${a['assetUrl']}\n${a['priceCoins']} NVC  |  ${a['requiredFollowers']} متابع  |  ${a['premium'] == true ? 'PRO' : 'عادي'}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(asset: a)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (!await _confirm(context, 'حذف أصل', 'سيُحذف «${a['name']}» نهائيًا.')) return;
                            try {
                              await Api.deleteAsset('${a['id']}');
                              await _load();
                            } catch (e) {
                              if (mounted) _toast(context, 'فشل الحذف: ${_err(e)}');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rewards (creator milestones + levels)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardsTab extends StatefulWidget {
  const _RewardsTab();
  @override
  State<_RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<_RewardsTab> {
  List<Map<String, dynamic>> _milestones = [];
  List<Map<String, dynamic>> _levels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ms = await Api.adminMilestones();
      final lv = await Api.adminCreatorLevels();
      setState(() {
        _milestones = ms.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _levels = lv.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل المكافآت: ${_err(e)}'; _loading = false; });
    }
  }

  Future<void> _editMilestone({Map<String, dynamic>? m, int index = -1}) async {
    final fields = [
      _FieldSpec('followersRequired', TextEditingController(text: '${m?['followersRequired'] ?? 1000}'), keyboard: TextInputType.number),
      _FieldSpec('title', TextEditingController(text: '${m?['title'] ?? ''}')),
      _FieldSpec('badge', TextEditingController(text: '${m?['badge'] ?? ''}')),
      _FieldSpec('profileFrame', TextEditingController(text: '${m?['profileFrame'] ?? ''}')),
      _FieldSpec('profileBackground', TextEditingController(text: '${m?['profileBackground'] ?? ''}')),
      _FieldSpec('entryEffect', TextEditingController(text: '${m?['entryEffect'] ?? ''}')),
      _FieldSpec('chatEffect', TextEditingController(text: '${m?['chatEffect'] ?? ''}')),
      _FieldSpec('rewardCoins', TextEditingController(text: '${m?['rewardCoins'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('rewardGiftSlug', TextEditingController(text: '${m?['rewardGiftSlug'] ?? ''}')),
    ];
    final out = await _formDialog(context, title: m == null ? 'إنجاز جديد' : 'تعديل الإنجاز', fields: fields);
    if (out == null) return;
    final row = <String, dynamic>{
      'followersRequired': _int(out, 'followersRequired', 1000),
      'title': out['title'] ?? '',
      'badge': out['badge'] ?? '',
      'profileFrame': out['profileFrame'] ?? '',
      'profileBackground': out['profileBackground'] ?? '',
      'entryEffect': out['entryEffect'] ?? '',
      'chatEffect': out['chatEffect'] ?? '',
      'rewardCoins': _int(out, 'rewardCoins'),
      'rewardGiftSlug': out['rewardGiftSlug'] ?? '',
      'enabled': true,
    };
    final next = List<Map<String, dynamic>>.from(_milestones);
    if (index >= 0) {
      next[index] = row;
    } else {
      next.add(row);
    }
    next.sort((a, b) => (_intOf(a['followersRequired'])).compareTo(_intOf(b['followersRequired'])));
    await _saveMilestones(next);
  }

  static int _intOf(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _saveMilestones(List<Map<String, dynamic>> list) async {
    try {
      await Api.saveMilestones(list);
      if (!mounted) return;
      _toast(context, 'حُفظت الإنجازات');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  Future<void> _editLevel({Map<String, dynamic>? l}) async {
    final fields = [
      _FieldSpec('key', TextEditingController(text: '${l?['key'] ?? ''}'), hint: 'ascii key'),
      _FieldSpec('label', TextEditingController(text: '${l?['label'] ?? ''}')),
      _FieldSpec('minFollowers', TextEditingController(text: '${l?['minFollowers'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('tier', TextEditingController(text: '${l?['tier'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('color', TextEditingController(text: '${l?['color'] ?? '#9CA3AF'}')),
    ];
    final out = await _formDialog(context, title: l == null ? 'مستوى جديد' : 'تعديل المستوى', fields: fields);
    if (out == null) return;
    final row = <String, dynamic>{
      'key': out['key'] ?? '',
      'label': out['label'] ?? '',
      'minFollowers': _int(out, 'minFollowers'),
      'tier': _int(out, 'tier'),
      'color': out['color'] ?? '#9CA3AF',
      'enabled': true,
    };
    final next = List<Map<String, dynamic>>.from(_levels);
    final at = next.indexWhere((e) => '${e['key']}' == row['key']);
    if (at >= 0) {
      next[at] = row;
    } else {
      next.add(row);
    }
    try {
      await Api.saveCreatorLevels(next);
      if (!mounted) return;
      _toast(context, 'حُفظت المستويات');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncBody(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(child: Text('إنجازات المبدعين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              FilledButton.icon(onPressed: () => _editMilestone(), icon: const Icon(Icons.add), label: const Text('إنجاز')),
            ],
          ),
          const SizedBox(height: 6),
          const Text('كل ما يصل إلى عدد المتابعين المطلوب يُمنح تلقائيًا مرة واحدة (عملات + إشعار).',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          for (var i = 0; i < _milestones.length; i++)
            Card(
              child: ListTile(
                leading: const Icon(Icons.emoji_events_rounded),
                title: Text('${_milestones[i]['title']}  •  ${_milestones[i]['followersRequired']} متابع'),
                subtitle: Text('badge: ${_milestones[i]['badge']} | frame: ${_milestones[i]['profileFrame']} | entry: ${_milestones[i]['entryEffect']} | coins: ${_milestones[i]['rewardCoins']} | gift: ${_milestones[i]['rewardGiftSlug']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _editMilestone(m: _milestones[i], index: i)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await _confirm(context, 'حذف إنجاز', 'سيُحذف «${_milestones[i]['title']}».')) return;
                        final next = List<Map<String, dynamic>>.from(_milestones)..removeAt(i);
                        await _saveMilestones(next);
                      },
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 34),
          Row(
            children: [
              const Expanded(child: Text('مستويات المبدعين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              FilledButton.icon(onPressed: () => _editLevel(), icon: const Icon(Icons.add), label: const Text('مستوى')),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in _levels)
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: _parseColor('${l['color']}')),
                title: Text('${l['label']}  •  ${l['minFollowers']} متابع'),
                subtitle: Text('key: ${l['key']} | tier: ${l['tier']}'),
                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editLevel(l: l)),
              ),
            ),
        ],
      ),
    );
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return Color(v ?? 0xFF9CA3AF);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nova TV
// ─────────────────────────────────────────────────────────────────────────────

class _NovaTvTab extends StatefulWidget {
  const _NovaTvTab();
  @override
  State<_NovaTvTab> createState() => _NovaTvTabState();
}

class _NovaTvTabState extends State<_NovaTvTab> {
  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _series = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Api.adminContentTree();
      setState(() {
        _movies = ((res['movies'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _series = ((res['series'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل المحتوى: ${_err(e)}'; _loading = false; });
    }
  }

  Future<void> _editMovie({Map<String, dynamic>? m}) async {
    final fields = [
      _FieldSpec('title', TextEditingController(text: '${m?['title'] ?? ''}')),
      _FieldSpec('description', TextEditingController(text: '${m?['description'] ?? ''}')),
      _FieldSpec('posterUrl', TextEditingController(text: '${m?['posterUrl'] ?? ''}')),
      _FieldSpec('backdropUrl', TextEditingController(text: '${m?['backdropUrl'] ?? ''}')),
      _FieldSpec('trailerUrl', TextEditingController(text: '${m?['trailerUrl'] ?? ''}')),
      _FieldSpec('videoUrl', TextEditingController(text: '${m?['videoUrl'] ?? ''}')),
      _FieldSpec('year', TextEditingController(text: '${m?['year'] ?? ''}'), keyboard: TextInputType.number),
      _FieldSpec('durationSec', TextEditingController(text: '${m?['durationSec'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('genres', TextEditingController(text: '${m?['genres'] ?? ''}')),
      _FieldSpec('cast', TextEditingController(text: '${m?['cast'] ?? ''}')),
      _FieldSpec('rating', TextEditingController(text: '${m?['rating'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('accessMode', TextEditingController(text: '${m?['accessMode'] ?? 'FREE'}'), hint: 'FREE | PAID | SUBSCRIPTION | AD'),
      _FieldSpec('priceCents', TextEditingController(text: '${m?['priceCents'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('published', TextEditingController(text: '${m?['published'] ?? true}'), hint: 'true / false'),
    ];
    final out = await _formDialog(context, title: m == null ? 'فيلم جديد' : 'تعديل الفيلم', fields: fields);
    if (out == null) return;
    final body = <String, dynamic>{
      'title': out['title'] ?? '',
      'description': out['description'] ?? '',
      'posterUrl': out['posterUrl'] ?? '',
      'backdropUrl': out['backdropUrl'] ?? '',
      'trailerUrl': out['trailerUrl'] ?? '',
      'videoUrl': out['videoUrl'] ?? '',
      'durationSec': _int(out, 'durationSec'),
      'genres': out['genres'] ?? '',
      'cast': out['cast'] ?? '',
      'rating': double.tryParse(out['rating'] ?? '') ?? 0,
      'accessMode': (out['accessMode'] ?? 'FREE').toUpperCase(),
      'priceCents': _int(out, 'priceCents'),
      'published': _bool(out, 'published'),
    };
    if ((out['year'] ?? '').isNotEmpty) body['year'] = _int(out, 'year');
    try {
      await Api.saveMovie(body, id: '${m?['id'] ?? ''}');
      if (!mounted) return;
      _toast(context, m == null ? 'أُضيف الفيلم' : 'حُدّث الفيلم');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  Future<void> _editSeries({Map<String, dynamic>? s}) async {
    final fields = [
      _FieldSpec('title', TextEditingController(text: '${s?['title'] ?? ''}')),
      _FieldSpec('description', TextEditingController(text: '${s?['description'] ?? ''}')),
      _FieldSpec('posterUrl', TextEditingController(text: '${s?['posterUrl'] ?? ''}')),
      _FieldSpec('backdropUrl', TextEditingController(text: '${s?['backdropUrl'] ?? ''}')),
      _FieldSpec('trailerUrl', TextEditingController(text: '${s?['trailerUrl'] ?? ''}')),
      _FieldSpec('genres', TextEditingController(text: '${s?['genres'] ?? ''}')),
      _FieldSpec('cast', TextEditingController(text: '${s?['cast'] ?? ''}')),
      _FieldSpec('rating', TextEditingController(text: '${s?['rating'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('subscriberOnly', TextEditingController(text: '${s?['subscriberOnly'] ?? false}'), hint: 'true / false'),
      _FieldSpec('seasonPassPriceCents', TextEditingController(text: '${s?['seasonPassPriceCents'] ?? 0}'), keyboard: TextInputType.number),
    ];
    final out = await _formDialog(context, title: s == null ? 'مسلسل جديد' : 'تعديل المسلسل', fields: fields);
    if (out == null) return;
    final body = <String, dynamic>{
      'title': out['title'] ?? '',
      'description': out['description'] ?? '',
      'posterUrl': out['posterUrl'] ?? '',
      'backdropUrl': out['backdropUrl'] ?? '',
      'trailerUrl': out['trailerUrl'] ?? '',
      'genres': out['genres'] ?? '',
      'cast': out['cast'] ?? '',
      'rating': double.tryParse(out['rating'] ?? '') ?? 0,
      'subscriberOnly': _bool(out, 'subscriberOnly'),
      'seasonPassPriceCents': _int(out, 'seasonPassPriceCents'),
    };
    try {
      await Api.saveSeries(body, id: '${s?['id'] ?? ''}');
      if (!mounted) return;
      _toast(context, s == null ? 'أُضيف المسلسل' : 'حُدّث المسلسل');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  Future<void> _addSeason(Map<String, dynamic> series) async {
    final fields = [
      _FieldSpec('number', TextEditingController(text: '1'), keyboard: TextInputType.number),
      _FieldSpec('title', TextEditingController(text: '')),
    ];
    final out = await _formDialog(context, title: 'موسم جديد', fields: fields);
    if (out == null) return;
    try {
      await Api.saveSeason({'seriesId': series['id'], 'number': _int(out, 'number', 1), 'title': out['title'] ?? ''});
      if (!mounted) return;
      _toast(context, 'أُضيف الموسم');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  Future<void> _addEpisode(Map<String, dynamic> season, {Map<String, dynamic>? ep}) async {
    final fields = [
      _FieldSpec('number', TextEditingController(text: '${ep?['number'] ?? 1}'), keyboard: TextInputType.number),
      _FieldSpec('title', TextEditingController(text: '${ep?['title'] ?? ''}')),
      _FieldSpec('videoUrl', TextEditingController(text: '${ep?['videoUrl'] ?? ''}')),
      _FieldSpec('thumbnailUrl', TextEditingController(text: '${ep?['thumbnailUrl'] ?? ''}')),
      _FieldSpec('durationSec', TextEditingController(text: '${ep?['durationSec'] ?? 0}'), keyboard: TextInputType.number),
      _FieldSpec('accessMode', TextEditingController(text: '${ep?['accessMode'] ?? 'FREE'}')),
      _FieldSpec('priceCents', TextEditingController(text: '${ep?['priceCents'] ?? 0}'), keyboard: TextInputType.number),
    ];
    final out = await _formDialog(context, title: ep == null ? 'حلقة جديدة' : 'تعديل الحلقة', fields: fields);
    if (out == null) return;
    final body = <String, dynamic>{
      'seasonId': season['id'],
      'number': _int(out, 'number', 1),
      'title': out['title'] ?? '',
      'videoUrl': out['videoUrl'] ?? '',
      'thumbnailUrl': out['thumbnailUrl'] ?? '',
      'durationSec': _int(out, 'durationSec'),
      'accessMode': (out['accessMode'] ?? 'FREE').toUpperCase(),
      'priceCents': _int(out, 'priceCents'),
    };
    try {
      await Api.saveEpisode(body, id: '${ep?['id'] ?? ''}');
      if (!mounted) return;
      _toast(context, ep == null ? 'أُضيفت الحلقة' : 'حُدّثت الحلقة');
      await _load();
    } catch (e) {
      if (mounted) _toast(context, 'فشل الحفظ: ${_err(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncBody(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(child: Text('الأفلام', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              FilledButton.icon(onPressed: () => _editMovie(), icon: const Icon(Icons.add), label: const Text('فيلم')),
            ],
          ),
          for (final m in _movies)
            Card(
              child: ListTile(
                leading: (m['posterUrl'] ?? '').toString().isEmpty
                    ? const Icon(Icons.movie_rounded)
                    : SizedBox(width: 40, height: 56, child: Image.network('${m['posterUrl']}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded))),
                title: Text('${m['title']}${m['published'] == true ? '' : '  (مؤرشف)'}'),
                subtitle: Text('${m['genres']}  |  ${m['durationSec']} ثانية  |  ${m['accessMode']}  |  ${m['views']} مشاهدة'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _editMovie(m: m)),
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () async {
                        if (!await _confirm(context, 'أرشفة الفيلم', 'لن يُحذف السجل، فقط سيُخفى من الكتالوج.')) return;
                        try {
                          await Api.archiveMovie('${m['id']}');
                          await _load();
                        } catch (e) {
                          if (mounted) _toast(context, 'فشل: ${_err(e)}');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 34),
          Row(
            children: [
              const Expanded(child: Text('المسلسلات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              FilledButton.icon(onPressed: () => _editSeries(), icon: const Icon(Icons.add), label: const Text('مسلسل')),
            ],
          ),
          for (final s in _series) _seriesCard(s),
        ],
      ),
    );
  }

  Widget _seriesCard(Map<String, dynamic> s) {
    final seasons = ((s['seasons'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.live_tv_rounded),
        title: Text('${s['title']}'),
        subtitle: Text('${seasons.length} موسم  |  ${s['status']}'),
        trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editSeries(s: s)),
        children: [
          for (final season in seasons) ...[
            ListTile(
              dense: true,
              title: Text('الموسم ${season['number']}${'${season['title']}'.isEmpty ? '' : ' — ${season['title']}'}'),
              subtitle: Text('${((season['episodes'] as List?) ?? const []).length} حلقة'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(onPressed: () => _addEpisode(season), icon: const Icon(Icons.add, size: 18), label: const Text('حلقة')),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      if (!await _confirm(context, 'حذف موسم', 'سيُحذف الموسم وكل حلقاته.')) return;
                      try {
                        await Api.deleteSeason('${season['id']}');
                        await _load();
                      } catch (e) {
                        if (mounted) _toast(context, 'فشل: ${_err(e)}');
                      }
                    },
                  ),
                ],
              ),
            ),
            for (final ep in ((season['episodes'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)))
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 42, right: 12),
                leading: const Icon(Icons.play_circle_outline, size: 20),
                title: Text('${ep['number']}. ${ep['title']}'),
                subtitle: Text('${ep['durationSec']} ثانية  |  ${ep['accessMode']}  |  ${ep['published'] == true ? 'منشورة' : 'مؤرشفة'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _addEpisode(season, ep: ep)),
                    IconButton(
                      icon: const Icon(Icons.archive_outlined, size: 20),
                      onPressed: () async {
                        try {
                          await Api.archiveEpisode('${ep['id']}');
                          await _load();
                        } catch (e) {
                          if (mounted) _toast(context, 'فشل: ${_err(e)}');
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(onPressed: () => _addSeason(s), icon: const Icon(Icons.add), label: const Text('إضافة موسم')),
          ),
        ],
      ),
    );
  }
}

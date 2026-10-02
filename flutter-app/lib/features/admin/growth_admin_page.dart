import 'package:flutter/material.dart';
import '../../core/api.dart';

class AdminGrowthPage extends StatefulWidget {
  const AdminGrowthPage({super.key});
  @override State<AdminGrowthPage> createState() => _AdminGrowthPageState();
}

class _AdminGrowthPageState extends State<AdminGrowthPage> {
  final userId = TextEditingController();
  final delta = TextEditingController(text: '100');
  final contentId = TextEditingController();
  final views = TextEditingController(text: '1000');
  final likes = TextEditingController(text: '0');
  final taps = TextEditingController(text: '0');
  final commentId = TextEditingController();
  final heartDelta = TextEditingController(text: '100');
  String kind = 'REEL';
  String commentKind = 'POST';
  String msg = '';
  bool busy = false;
  List<dynamic> users = [];
  List<dynamic> comments = [];

  @override
  void dispose() {
    userId.dispose(); delta.dispose(); contentId.dispose(); views.dispose(); likes.dispose(); taps.dispose();
    commentId.dispose(); heartDelta.dispose(); super.dispose();
  }

  String err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> loadUsers() async {
    try { final x = await Api.adminUsers(); if (mounted) setState(() => users = x); }
    catch (e) { if (mounted) setState(() => msg = err(e)); }
  }

  Future<void> addFollowers() async {
    final id = userId.text.trim();
    final d = int.tryParse(delta.text.trim()) ?? 0;
    if (id.isEmpty || d == 0) { setState(() => msg = 'أدخل User ID وقيمة المتابعين.'); return; }
    setState(() => busy = true);
    try {
      final x = await Api.adminAddFollowers(id, d);
      final milestones = (x['milestones'] as List?)?.map((m) => m is Map ? '${m['title'] ?? ''}' : '$m').join('، ') ?? '';
      setState(() => msg = 'تم تعديل المتابعين: ${x['previous'] ?? '-'} → ${x['next'] ?? '-'}${milestones.isEmpty ? '' : ' • الإنجازات: $milestones'}');
    } catch (e) { setState(() => msg = err(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> addViews() async {
    final id = contentId.text.trim();
    final v = int.tryParse(views.text.trim()) ?? 0;
    if (id.isEmpty || v <= 0) { setState(() => msg = 'أدخل Content ID وعدد المشاهدات.'); return; }
    setState(() => busy = true);
    final l = int.tryParse(likes.text.trim()) ?? 0; final t = int.tryParse(taps.text.trim()) ?? 0; try { final x = await Api.adminBoostContent(kind, id, viewers: v, likes: l, taps: t); setState(() => msg = 'تمت إضافة +${x['addedViews'] ?? v} مشاهدة، +${x['addedLikes'] ?? l} إعجاب، +${x['addedTaps'] ?? t} تكبيس إلى $kind.'); }
    catch (e) { setState(() => msg = err(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> loadComments() async {
    try { final rows = await Api.adminComments(kind: commentKind); if (mounted) setState(() => comments = rows); }
    catch (e) { if (mounted) setState(() => msg = err(e)); }
  }

  Future<void> addCommentHearts() async {
    final id = commentId.text.trim();
    final d = int.tryParse(heartDelta.text.trim()) ?? 0;
    if (id.isEmpty || d == 0) { setState(() => msg = 'أدخل Comment ID وقيمة القلوب.'); return; }
    setState(() => busy = true);
    try {
      final x = await Api.adminBoostCommentHearts(commentKind, id, d);
      setState(() => msg = 'تم تحديث قلوب التعليق إلى ${x['likeCount'] ?? 0}.');
      await loadComments();
    } catch (e) { setState(() => msg = err(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('النمو والإحصائيات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('تعديلات إدارية محفوظة في Audit Log.', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('المتابعون + الإنجازات', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        TextField(controller: userId, decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: delta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الزيادة / النقصان (+/-)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: busy ? null : addFollowers, icon: const Icon(Icons.group_add_rounded), label: const Text('تطبيق')),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('المشاهدات', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: kind, items: const [
          DropdownMenuItem(value: 'REEL', child: Text('Reel')), DropdownMenuItem(value: 'POST', child: Text('Post')),
          DropdownMenuItem(value: 'STORY', child: Text('Story')), DropdownMenuItem(value: 'LIVE', child: Text('Live')), DropdownMenuItem(value: 'MOVIE', child: Text('فيلم')), DropdownMenuItem(value: 'SERIES', child: Text('مسلسل')), DropdownMenuItem(value: 'EPISODE', child: Text('حلقة')),
        ], onChanged: busy ? null : (v) => setState(() => kind = v ?? 'REEL'), decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: contentId, decoration: const InputDecoration(labelText: 'Content ID / Room ID', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: views, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المشاهدات +', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: TextField(controller: likes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القلوب/الإعجابات +', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: taps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'التكبيس + (Live)', border: OutlineInputBorder())))]),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: busy ? null : addViews, icon: const Icon(Icons.visibility_rounded), label: const Text('زيادة المشاهدات')),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('قلوب التعليقات ❤️', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('يمكن للإدارة إضافة أو إزالة قلوب لأي تعليق.', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: commentKind, items: const [
          DropdownMenuItem(value: 'POST', child: Text('تعليق منشور')), DropdownMenuItem(value: 'REEL', child: Text('تعليق Reel')),
        ], onChanged: busy ? null : (v) => setState(() => commentKind = v ?? 'POST'), decoration: const InputDecoration(labelText: 'نوع التعليق', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: commentId, decoration: const InputDecoration(labelText: 'Comment ID', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: heartDelta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد القلوب (+/-)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: busy ? null : addCommentHearts, icon: const Icon(Icons.favorite_rounded), label: const Text('تطبيق القلوب'))),
          const SizedBox(width: 8), OutlinedButton.icon(onPressed: busy ? null : loadComments, icon: const Icon(Icons.list_rounded), label: const Text('التعليقات')),
        ]),
        if (comments.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...comments.take(30).map((raw) {
            final x = Map<String, dynamic>.from(raw as Map);
            final author = Map<String, dynamic>.from((x['author'] ?? {}) as Map);
            final name = '${author['displayName'] ?? author['username'] ?? 'مستخدم'}';
            return ListTile(dense: true, title: Text(name), subtitle: Text('${x['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis), trailing: Text('❤️ ${x['likeCount'] ?? 0}'), onTap: () => setState(() => commentId.text = '${x['id'] ?? ''}'));
          }),
        ],
      ]))),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: busy ? null : loadUsers, icon: const Icon(Icons.people_alt_rounded), label: const Text('اختيار مستخدم')),
      if (users.isNotEmpty) ...users.take(50).map((raw) { final u = Map<String, dynamic>.from(raw as Map); return ListTile(title: Text('${u['displayName'] ?? u['username'] ?? ''}'), subtitle: Text('${u['id'] ?? ''}'), onTap: () => setState(() => userId.text = '${u['id'] ?? ''}')); }),
      if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]);
  }
}

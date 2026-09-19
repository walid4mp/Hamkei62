import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class DigitalIdPage extends StatefulWidget {
  const DigitalIdPage({super.key});
  @override
  State<DigitalIdPage> createState() => _DigitalIdPageState();
}

class _DigitalIdPageState extends State<DigitalIdPage> {
  late Future<Map<String, dynamic>> future;
  final boundaryKey = GlobalKey();
  String theme = 'midnight';
  String shape = 'rounded';
  String visibility = 'PUBLIC';
  String? groupId;
  bool showFollowers = true;
  bool showPosts = true;
  bool showStories = true;
  bool showActivity = true;
  bool showGender = false;
  bool showBirthDate = false;
  List<dynamic> myGroups = [];

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([Api.digitalCard(), Api.myGroups()]);
    final d = Map<String, dynamic>.from(results[0] as Map);
    myGroups = List<dynamic>.from(results[1] as List);
    theme = '${d['digitalCardTheme'] ?? 'midnight'}';
    shape = '${d['digitalCardShape'] ?? 'rounded'}';
    visibility = '${d['digitalCardVisibility'] ?? 'PUBLIC'}';
    groupId = d['digitalCardGroupId']?.toString();
    showFollowers = d['digitalCardShowFollowers'] != false;
    showPosts = d['digitalCardShowPosts'] != false;
    showStories = d['digitalCardShowStories'] != false;
    showActivity = d['digitalCardShowActivity'] != false;
    showGender = d['digitalCardShowGender'] == true;
    showBirthDate = d['digitalCardShowBirthDate'] == true;
    return d;
  }

  Color accent() {
    switch (theme) {
      case 'gold': return SN.gold;
      case 'green': return SN.green;
      case 'violet': return SN.violet;
      default: return SN.cyan;
    }
  }

  String code(String id) {
    final n = id.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) % 100000000);
    return n.toString().padLeft(8, '0');
  }

  String _genderLabel(dynamic value) {
    switch ('${value ?? ''}'.toLowerCase()) {
      case 'male': case 'ذكر': return 'ذكر';
      case 'female': case 'أنثى': case 'انثى': return 'أنثى';
      default: return '${value ?? ''}';
    }
  }

  String _birthLabel(dynamic value) {
    final raw = '${value ?? ''}';
    if (raw.isEmpty) return '';
    try { return DateFormat('yyyy-MM-dd').format(DateTime.parse(raw).toLocal()); }
    catch (_) { return raw.split('T').first; }
  }

  String _groupName(Map<String, dynamic> d) {
    final g = d['digitalCardGroup'];
    if (g is Map && '${g['name'] ?? ''}'.isNotEmpty) return '${g['name']}';
    final selected = myGroups.where((e) => e is Map && '${e['id'] ?? ''}' == '${d['digitalCardGroupId'] ?? ''}');
    return selected.isEmpty ? '' : '${(selected.first as Map)['name'] ?? ''}';
  }

  Future<void> save() async {
    await Api.updateMe({
      'digitalCardTheme': theme,
      'digitalCardShape': shape,
      'digitalCardVisibility': visibility,
      'digitalCardGroupId': groupId,
      'digitalCardShowFollowers': showFollowers,
      'digitalCardShowPosts': showPosts,
      'digitalCardShowStories': showStories,
      'digitalCardShowActivity': showActivity,
      'digitalCardShowGender': showGender,
      'digitalCardShowBirthDate': showBirthDate,
    });
  }

  Future<void> shareCard(Map<String, dynamic> d) async {
    try {
      final box = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (box == null) return;
      final image = await box.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(data.buffer.asUint8List(), name: 'socialnova-digital-id.png', mimeType: 'image/png')],
        text: 'بطاقتي الرقمية في SocialNova',
      ));
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: 'socialnova://profile/${d['id']}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('بطاقة الهوية الرقمية'),
        actions: [IconButton(onPressed: _settings, icon: const Icon(Icons.tune_rounded))],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return const EmptyState(text: 'تعذر تحميل البطاقة', icon: Icons.badge_outlined);
          final d = snap.data ?? {};
          final verified = d['isVerified'] == true;
          final id = '${d['id'] ?? ''}';
          final name = '${d['displayName'] ?? d['username'] ?? 'SocialNova'}';
          final username = '${d['username'] ?? ''}';
          final avatar = '${d['avatarUrl'] ?? ''}';
          final location = '${d['location'] ?? ''}';
          final gender = _genderLabel(d['gender']);
          final birth = _birthLabel(d['birthDate']);
          final group = _groupName(d);
          final a = accent();
          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
            children: [
              RepaintBoundary(key: boundaryKey, child: _card(d, verified, id, name, username, avatar, location, gender, birth, group, a)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => shareCard(d), icon: const Icon(Icons.share_rounded), label: const Text('مشاركة البطاقة'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _settings, icon: const Icon(Icons.palette_outlined), label: const Text('تخصيص'))),
              ]),
              const SizedBox(height: 10),
              const Text('البيانات تُسحب تلقائيًا من حسابك. يمكنك التحكم في ظهور تاريخ الميلاد والجنس واسم المجموعة من تخصيص البطاقة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: SN.textSec)),
            ],
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> d, bool verified, String id, String name, String username, String avatar, String location, String gender, String birth, String group, Color a) {
    final radius = shape == 'sharp' ? 10.0 : 26.0;
    final city = location.isEmpty ? 'غير محدد' : location;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF030814),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: a.withValues(alpha: .75), width: 1.6),
        boxShadow: [BoxShadow(color: a.withValues(alpha: .20), blurRadius: 24, spreadRadius: 2)],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [SN.bg2, a.withValues(alpha: .12), Colors.black]),
          borderRadius: BorderRadius.circular(radius - 6),
        ),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: QrImageView(data: 'socialnova://profile/$id', size: 64)),
            const SizedBox(width: 10),
            const Expanded(child: Text('البطاقة الرقمية', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
            Icon(verified ? Icons.verified_rounded : Icons.verified_outlined, color: verified ? SN.green : SN.textMut, size: 42),
          ]),
          const SizedBox(height: 4),
          const Text('SocialNova', style: TextStyle(color: SN.cyan, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Stack(alignment: Alignment.center, children: [
            Container(width: 174, height: 174, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: a, width: 5), boxShadow: [BoxShadow(color: a.withValues(alpha: .35), blurRadius: 28)])),
            CircleAvatar(radius: 78, backgroundColor: SN.bg3, backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person_rounded, size: 72) : null),
          ]),
          const SizedBox(height: 12),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          Text('@$username', style: const TextStyle(fontSize: 16, color: SN.textSec)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: (verified ? SN.green : a).withValues(alpha: .12), borderRadius: BorderRadius.circular(30), border: Border.all(color: (verified ? SN.green : a).withValues(alpha: .35))), child: Text(verified ? 'حساب موثق • ${d['verificationTier'] ?? 'NORMAL'}' : 'حساب SocialNova', style: TextStyle(color: verified ? SN.green : a, fontWeight: FontWeight.w800))),
          const SizedBox(height: 14),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _info('الدولة / المدينة', city, Icons.location_on_rounded, a),
            if (showGender && gender.isNotEmpty) _info('الجنس', gender, Icons.person_rounded, a),
            if (showBirthDate && birth.isNotEmpty) _info('تاريخ الميلاد', birth, Icons.cake_rounded, a),
            if (group.isNotEmpty) _info('اسم المجموعة', group, Icons.groups_rounded, a),
            _info('تاريخ إنشاء الحساب', _birthLabel(d['createdAt']), Icons.event_rounded, a),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [
            if (showFollowers) _statBox('${d['followers'] ?? 0}', 'المتابعون', Icons.favorite_rounded, a),
            _statBox('${d['following'] ?? 0}', 'أتابع', Icons.people_alt_rounded, a),
            if (showPosts) _statBox('${d['posts'] ?? 0}', 'المنشورات', Icons.article_rounded, a),
            if (showStories) _statBox('${d['stories'] ?? 0}', 'القصص', Icons.auto_stories_rounded, a),
          ]),
          const SizedBox(height: 10),
          if (showActivity) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(16), border: Border.all(color: a.withValues(alpha: .25))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _mini('${d['sales'] ?? 0}', 'المبيعات'),
            _mini('${d['productViews'] ?? 0}', 'زيارات المتجر'),
            _mini('${d['activeStories'] ?? 0}', 'قصص نشطة'),
          ])),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: .68, child: Container(decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(20)))))),
            const SizedBox(width: 10),
            Text('ID-${code(id)}', style: TextStyle(color: a, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 12),
          const Text('بطاقة ملفك في SocialNova', style: TextStyle(color: SN.textSec, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _info(String label, String value, IconData icon, Color a) => Container(width: 154, constraints: const BoxConstraints(minHeight: 76), padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .28), borderRadius: BorderRadius.circular(14), border: Border.all(color: a.withValues(alpha: .22))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: a), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, color: SN.textSec)), const SizedBox(height: 2), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]));

  Widget _statBox(String value, String label, IconData icon, Color a) => Container(width: 145, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .28), borderRadius: BorderRadius.circular(14), border: Border.all(color: a.withValues(alpha: .22))), child: Row(children: [Icon(icon, color: a, size: 22), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 10, color: SN.textSec))])]));

  Widget _mini(String value, String label) => Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 9, color: SN.textSec))]);

  Future<void> _settings() async {
    var localTheme = theme;
    var localShape = shape;
    var localVisibility = visibility;
    var localGroup = groupId;
    var localFollowers = showFollowers;
    var localPosts = showPosts;
    var localStories = showStories;
    var localActivity = showActivity;
    var localGender = showGender;
    var localBirth = showBirthDate;
    await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: SN.bg2, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 28 + MediaQuery.viewInsetsOf(ctx).bottom), child: ListView(shrinkWrap: true, children: [
      const Text('تخصيص البطاقة الرقمية', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('اختر المظهر والمعلومات التي تريد إظهارها.', style: TextStyle(color: SN.textSec)),
      const SizedBox(height: 14),
      const Text('النمط', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: ['midnight', 'gold', 'green', 'violet'].map((x) => ChoiceChip(label: Text(x), selected: localTheme == x, onSelected: (_) => set(() => localTheme = x))).toList()),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: localVisibility, decoration: const InputDecoration(labelText: 'ظهور البطاقة'), items: const [DropdownMenuItem(value: 'PUBLIC', child: Text('الجميع')), DropdownMenuItem(value: 'FRIENDS', child: Text('الأصدقاء')), DropdownMenuItem(value: 'PRIVATE', child: Text('أنا فقط'))], onChanged: (x) { if (x != null) set(() => localVisibility = x); }),
      const SizedBox(height: 10),
      DropdownButtonFormField<String?>(value: localGroup, decoration: const InputDecoration(labelText: 'اسم المجموعة'), items: [const DropdownMenuItem<String?>(value: null, child: Text('بدون مجموعة')), ...myGroups.whereType<Map>().map((g) => DropdownMenuItem<String?>(value: '${g['id']}', child: Text('${g['name'] ?? ''}', overflow: TextOverflow.ellipsis)))], onChanged: (x) => set(() => localGroup = x)),
      SwitchListTile(value: localGender, onChanged: (x) => set(() => localGender = x), title: const Text('إظهار الجنس'), subtitle: const Text('يظهر فقط إذا كانت بيانات الجنس محفوظة في الحساب.')),
      SwitchListTile(value: localBirth, onChanged: (x) => set(() => localBirth = x), title: const Text('إظهار تاريخ الميلاد'), subtitle: const Text('يظهر التاريخ الكامل عند تفعيل هذا الخيار.')),
      SwitchListTile(value: localFollowers, onChanged: (x) => set(() => localFollowers = x), title: const Text('عدد المتابعين')),
      SwitchListTile(value: localPosts, onChanged: (x) => set(() => localPosts = x), title: const Text('عدد المنشورات')),
      SwitchListTile(value: localStories, onChanged: (x) => set(() => localStories = x), title: const Text('عدد القصص')),
      SwitchListTile(value: localActivity, onChanged: (x) => set(() => localActivity = x), title: const Text('إحصائيات النشاط')),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: () async { theme = localTheme; shape = localShape; visibility = localVisibility; groupId = localGroup; showGender = localGender; showBirthDate = localBirth; showFollowers = localFollowers; showPosts = localPosts; showStories = localStories; showActivity = localActivity; Navigator.pop(ctx); await save(); if (mounted) setState(() => future = _load()); }, icon: const Icon(Icons.save_rounded), label: const Text('حفظ التخصيص')),
    ]))));
  }
}

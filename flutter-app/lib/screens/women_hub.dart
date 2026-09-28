import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/localization.dart';

class WomenHubPage extends StatefulWidget {
  const WomenHubPage({super.key});
  @override State<WomenHubPage> createState() => _WomenHubPageState();
}

class _WomenHubPageState extends State<WomenHubPage> {
  int tab = 0;
  final categories = const [
    ('الموضة والجمال', Icons.checkroom_rounded, 'إطلالات، تنسيق، عناية وأفكار يومية'),
    ('العافية', Icons.spa_rounded, 'محتوى هادئ وعادات مفيدة ودعم مجتمعي'),
    ('الدعم والصداقة', Icons.diversity_2_rounded, 'نقاشات محترمة وتجارب ومساندة'),
    ('الإبداع', Icons.palette_rounded, 'رسم، تصميم، أشغال يدوية وديكور'),
  ];

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      appBar: AppBar(
        title: const Text('مساحات البنات'),
        backgroundColor: SN.bg0,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [SN.violet.withOpacity(.9), SN.cyan.withOpacity(.72)])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L10n.t('مساحة آمنة ومجتمعية 🌸'), style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(L10n.t('اكتشفي محتوى حسب اهتماماتك، شاركي أفكارك وتواصلي باحترام وخصوصية.'), style: TextStyle(color: Colors.white, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _chip('لكِ', 0), _chip('الأكثر تفاعلاً', 1), _chip('جديد', 2),
          ])),
          const SizedBox(height: 18),
          Text('الأقسام', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: SN.textPri)),
          const SizedBox(height: 10),
          for (final c in categories) Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(backgroundColor: SN.violet.withOpacity(.12), child: Icon(c.$2, color: SN.violet)),
              title: Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(c.$3),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _openCategory(c.$1),
            ),
          ),
          const SizedBox(height: 8),
          Text('ميزات المجتمع', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: SN.textPri)),
          const SizedBox(height: 10),
          _feature(Icons.shield_outlined, 'فلترة التعليقات', 'إخفاء الكلمات المسيئة قبل ظهورها لك.'),
          _feature(Icons.lock_outline_rounded, 'مساحات خاصة', 'مجتمعات خاصة بالدعوات أو موافقة المشرف.'),
          _feature(Icons.report_gmailerrorred_outlined, 'إبلاغ سريع', 'إبلاغ وحظر وكتم من نفس الشاشة.'),
          _feature(Icons.auto_awesome_rounded, 'تحديات ومحتوى ملهم', 'أفكار أسبوعية للإبداع والموضة والهوايات.'),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('إنشاء مساحة جديدة')),
        ],
      ),
    );
  }

  Widget _chip(String text, int value) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(text), selected: tab == value, onSelected: (_) => setState(() => tab = value)));

  Widget _feature(IconData icon, String title, String sub) => Card(child: ListTile(leading: Icon(icon, color: SN.cyan), title: Text(title, style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(sub)));

  void _openCategory(String title) => showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    const Text('سيتم ربط هذا القسم بمنشورات وReels ومجموعات SocialNova الخاصة بالاهتمام.'),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.explore_rounded), label: const Text('استكشاف')),
  ]))));

  void _create() => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('إنشاء مساحة'), content: const Text('يمكن إنشاء مساحة عامة أو خاصة مع قواعد واضحة وموافقة المشرف على الأعضاء.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('متابعة'))]));
}

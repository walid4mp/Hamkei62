import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class TechGamingPage extends StatefulWidget {
  const TechGamingPage({super.key});
  @override State<TechGamingPage> createState() => _TechGamingPageState();
}
class _TechGamingPageState extends State<TechGamingPage> with SingleTickerProviderStateMixin {
  int section = 0;
  String techFilter = 'الكل';
  bool safeMode = true;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  final tech = const <_TechItem>[
    _TechItem('هواتف','تحديثات ومراجعات الهواتف والأجهزة القابلة للارتداء',Icons.smartphone_rounded,'ما الجديد في الهواتف الحديثة؟'),
    _TechItem('حواسيب','أخبار اللابتوبات والقطع وأنظمة التشغيل',Icons.laptop_mac_rounded,'دليل مبسط للدراسة والبرمجة'),
    _TechItem('AI','أدوات الذكاء الاصطناعي وتطبيقاته اليومية',Icons.auto_awesome_rounded,'أفكار لاستخدام الذكاء الاصطناعي'),
    _TechItem('برمجة','نصائح قصيرة لتطوير التطبيقات والويب',Icons.code_rounded,'فكرة Flutter صغيرة لواجهة أجمل'),
    _TechItem('مستقبل','روبوتات وVR وابتكارات تقنية',Icons.view_in_ar_rounded,'نظرة مبسطة على الواقع الممتد'),
  ];
  final games = const <_GameItem>[
    _GameItem('بطولات','بطولة مجتمعية أسبوعية',Icons.emoji_events_rounded,'أنشئ بطولة ودع اللاعبين ينضمون إليها.'),
    _GameItem('مراجعات','مراجعات قصيرة بدون حرق',Icons.rate_review_rounded,'تعرّف على لعبة جديدة في دقيقة.'),
    _GameItem('نصائح','استراتيجيات وتعلم مهارات اللعب',Icons.tips_and_updates_rounded,'نصائح لعب تركز على المهارة والتعاون.'),
    _GameItem('مجتمع اللاعبين','غرف نقاش حسب اللعبة',Icons.groups_rounded,'ناقش التحديثات والاستراتيجيات مع اللاعبين.'),
  ];
  final achievements = const <_Badge>[
    _Badge('المطور','أنجز 5 منشورات برمجية',Icons.code_rounded,SN.violet),
    _Badge('المبتكر','شارك 10 أفكار تقنية',Icons.lightbulb_rounded,SN.gold),
    _Badge('لاعب جماعي','شارك في 5 بطولات مجتمعية',Icons.sports_esports_rounded,SN.cyan),
    _Badge('الاستراتيجيات','شارك 10 نصائح مفيدة',Icons.psychology_rounded,SN.pink),
  ];
  @override void dispose() { pulse.dispose(); super.dispose(); }
  void toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      appBar: AppBar(title: const Text('التكنولوجيا والألعاب', style: TextStyle(fontWeight: FontWeight.w900)), actions: [
        IconButton(onPressed: () => setState(() => safeMode = !safeMode), icon: Icon(safeMode ? Icons.shield_rounded : Icons.shield_outlined, color: safeMode ? SN.cyan : SN.textMut)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16,8,16,110), children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              ScaleTransition(scale: Tween(begin: .96, end: 1.04).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)), child: Container(width:68,height:68,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.white.withValues(alpha:.18)),child:const Icon(Icons.devices_other_rounded,color:Colors.white,size:36))),
              const SizedBox(width:15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tech × Gaming', style: TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),SizedBox(height:5),Text(L10n.t('أخبار ومراجعات وبرمجة وألعاب في مكان واحد',),style:TextStyle(color:Colors.white70))])),
            ]),
          ),
        ),
        const SizedBox(height:16),
        SegmentedButton<int>(segments: [ButtonSegment(value:0,label:Text(L10n.t('التقنية')),icon:const Icon(Icons.memory_rounded)),ButtonSegment(value:1,label:Text(L10n.t('الألعاب')),icon:const Icon(Icons.sports_esports_rounded)),ButtonSegment(value:2,label:Text(L10n.t('الإنجازات')),icon:const Icon(Icons.emoji_events_rounded))], selected:{section}, onSelectionChanged:(s)=>setState(()=>section=s.first)),
        const SizedBox(height:16),
        if (section == 0) _techView() else if (section == 1) _gamesView() else _achievementsView(),
        const SizedBox(height:14),
        GlassCard(child: Row(children: [Icon(Icons.security_rounded,color:SN.cyan),SizedBox(width:10),Expanded(child:Text(safeMode?'فلترة الأمان مفعّلة للمحتوى المناسب للعمر.':'فلترة الأمان متوقفة.'))])),
      ],),
    );
  }
  Widget _techView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('اختر اهتمامك', style: TextStyle(fontSize:20,fontWeight:FontWeight.w900)), const SizedBox(height:10),
    SingleChildScrollView(scrollDirection:Axis.horizontal, child:Row(children:['الكل','هواتف','حواسيب','AI','برمجة','مستقبل'].map((f)=>Padding(padding:const EdgeInsets.only(left:8),child:ChoiceChip(label:Text(f),selected:techFilter==f,onSelected:(_)=>setState(()=>techFilter=f)))).toList())),
    const SizedBox(height:14),
    ...tech.where((x)=>techFilter=='الكل'||x.category==techFilter).map((x)=>_contentCard(x.category,x.title,x.icon,x.description)),
    _featureTile(Icons.newspaper_rounded,'أخبار تقنية يومية','خلاصة مختصرة عند ربط مزود الأخبار.'),
    _featureTile(Icons.rate_review_rounded,'مراجعات الأجهزة','بطاقات للمواصفات وتجربة الاستخدام.'),
  ]);
  Widget _gamesView() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('عالم الألعاب',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:10),...games.map((x)=>_contentCard(x.category,x.title,x.icon,x.description)),GlassCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('تحدي الأسبوع',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('شارك إنجازًا أو تصميمًا أو نصيحة مرتبطة بلعبتك المفضلة.'),const SizedBox(height:12),FilledButton.icon(onPressed:()=>toast('سيتم ربط التحدي بنظام المشاركات والإنجازات'),icon:const Icon(Icons.add_rounded),label:const Text('شارك في التحدي'))]))]);
  Widget _achievementsView() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('إنجازات التقنية والألعاب',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:10),...achievements.map((a)=>Padding(padding:EdgeInsets.only(bottom:10),child:GlassCard(child:Row(children:[Container(width:54,height:54,decoration:BoxDecoration(shape:BoxShape.circle,color:a.color.withValues(alpha:.12)),child:Icon(a.icon,color:a.color)),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a.title,style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),SizedBox(height:3),Text(a.subtitle,style:TextStyle(color:SN.textSec,fontSize:13)),SizedBox(height:8),LinearProgressIndicator(value:.35,minHeight:6)])),SizedBox(width:4),Icon(Icons.lock_outline_rounded,color:SN.textMut)])))),GlassCard(child:Row(children:[Icon(Icons.privacy_tip_outlined,color:SN.cyan),SizedBox(width:10),Expanded(child:Text(L10n.t('الأوسمة تُكتسب من النشاط الفعلي داخل التطبيق.')))]))]);
  Widget _contentCard(String category,String title,IconData icon,String description)=>Padding(padding:EdgeInsets.only(bottom:10),child:GlassCard(child:Row(children:[Container(width:52,height:52,decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),color:SN.violet.withValues(alpha:.10)),child:Icon(icon,color:SN.violet,size:28)),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Text(category,style:TextStyle(color:SN.cyan,fontSize:12,fontWeight:FontWeight.w800)),Spacer(),Icon(Icons.chevron_left_rounded,color:SN.textMut)]),SizedBox(height:3),Text(title,style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),SizedBox(height:3),Text(description,style:TextStyle(color:SN.textSec,height:1.3))]))])));
  Widget _featureTile(IconData icon,String title,String text)=>Padding(padding:EdgeInsets.only(bottom:10),child:GlassCard(child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(icon,color:SN.cyan,size:30),title:Text(title,style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(text))));
}
class _TechItem{final String category,title,description;final IconData icon;const _TechItem(this.category,this.title,this.icon,this.description);}
class _GameItem{final String category,title,description;final IconData icon;const _GameItem(this.category,this.title,this.icon,this.description);}
class _Badge{final String title,subtitle;final IconData icon;final Color color;const _Badge(this.title,this.subtitle,this.icon,this.color);}

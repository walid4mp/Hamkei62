import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'nova_tv.dart';

class CreatorContentCenterPage extends StatefulWidget {
  const CreatorContentCenterPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<CreatorContentCenterPage> createState() => _CreatorContentCenterPageState();
}

class _CreatorContentCenterPageState extends State<CreatorContentCenterPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab < 0 ? 0 : widget.initialTab > 3 ? 3 : widget.initialTab);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استوديو الأفلام والمسلسلات', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: SN.violet,
          tabs: const [
            Tab(icon: Icon(Icons.movie_creation_outlined), text: 'فيلم'),
            Tab(icon: Icon(Icons.live_tv_rounded), text: 'مسلسل وحلقات'),
            Tab(icon: Icon(Icons.workspace_premium_rounded), text: 'اشتراكات'),
            Tab(icon: Icon(Icons.video_library_outlined), text: 'محتواي'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _PublishMovieTab(),
        _SeriesManagerTab(),
        _SubscriptionPlanTab(),
        _MyContentTab(),
      ]),
    );
  }
}

class _PublishMovieTab extends StatefulWidget {
  const _PublishMovieTab();
  @override State<_PublishMovieTab> createState() => _PublishMovieTabState();
}

class _PublishMovieTabState extends State<_PublishMovieTab> {
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController(text: '0');
  final duration = TextEditingController(text: '0');
  String access = 'FREE';
  bool ads = false;
  bool busy = false;
  String posterUrl = '';
  String trailerUrl = '';
  String videoUrl = '';

  @override
  void dispose() { title.dispose(); description.dispose(); price.dispose(); duration.dispose(); super.dispose(); }

  Future<String> _upload(String kind, {required bool video}) async {
    if (busy) return '';
    final result = await FilePicker.platform.pickFiles(type: video ? FileType.video : FileType.image);
    if (result == null) return '';
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return '';
    setState(() => busy = true);
    try {
      final url = await Api.uploadAndGetUrl(path, kind: kind);
      return url;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _publish() async {
    if (busy) return;
    if (title.text.trim().length < 2) { toast(context, 'أدخل عنوان الفيلم'); return; }
    if (videoUrl.isEmpty) { toast(context, 'اختر ملف الفيديو أولاً'); return; }
    setState(() => busy = true);
    try {
      await Api.createCreatorMovie({
        'title': title.text.trim(),
        'description': description.text.trim(),
        'posterUrl': posterUrl,
        'trailerUrl': trailerUrl,
        'videoUrl': videoUrl,
        'durationSec': int.tryParse(duration.text.trim()) ?? 0,
        'accessMode': access,
        'priceCents': int.tryParse(price.text.trim()) ?? 0,
        'currency': 'USD',
        'adSupported': ads,
      });
      if (!mounted) return;
      toast(context, 'تم نشر الفيلم في Nova TV 🎬');
      title.clear(); description.clear(); posterUrl = ''; trailerUrl = ''; videoUrl = ''; price.text = '0'; duration.text = '0';
      setState(() {});
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => _CreatorPageShell(
    title: 'نشر فيلم جديد',
    subtitle: 'ارفع الفيلم والصورة الدعائية وحدد طريقة الوصول والسعر.',
    children: [
      _text(title, 'عنوان الفيلم', Icons.title_rounded),
      _text(description, 'الوصف والقصة', Icons.description_outlined, maxLines: 4),
      _UploadRow(label: 'بوستر الفيلم', icon: Icons.image_outlined, url: posterUrl, onTap: () async { final u = await _upload('IMAGE', video: false); if (u.isNotEmpty) setState(() => posterUrl = u); }),
      _UploadRow(label: 'التريلر (اختياري)', icon: Icons.ondemand_video_rounded, url: trailerUrl, onTap: () async { final u = await _upload('VIDEO', video: true); if (u.isNotEmpty) setState(() => trailerUrl = u); }),
      _UploadRow(label: 'ملف الفيلم — مطلوب', icon: Icons.video_file_rounded, url: videoUrl, onTap: () async { final u = await _upload('VIDEO', video: true); if (u.isNotEmpty) setState(() => videoUrl = u); }),
      Row(children: [Expanded(child: _text(duration, 'المدة بالثواني', Icons.timer_outlined, keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _text(price, 'السعر بالسنت', Icons.payments_outlined, keyboard: TextInputType.number))]),
      _accessSelector(),
      SwitchListTile(value: ads, onChanged: (v) => setState(() => ads = v), title: const Text('السماح بالإعلانات'), subtitle: const Text('المحتوى قد يحقق عائدًا من الإعلانات المؤهلة.'), secondary: const Icon(Icons.campaign_outlined, color: SN.gold)),
      const SizedBox(height: 8),
      GradButton(label: 'نشر الفيلم الآن', icon: Icons.send_rounded, busy: busy, onTap: _publish),
    ],
  );

  Widget _accessSelector() => _Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('طريقة الوصول', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8),
    DropdownButtonFormField<String>(value: access, decoration: const InputDecoration(prefixIcon: Icon(Icons.security_rounded), labelText: 'نوع المحتوى'), items: const [DropdownMenuItem(value: 'FREE', child: Text('مجاني')), DropdownMenuItem(value: 'PAID', child: Text('مدفوع')), DropdownMenuItem(value: 'SUBSCRIBER', child: Text('للمشتركين'))], onChanged: (v) => setState(() => access = v ?? 'FREE')),
  ]));
}

class _SeriesManagerTab extends StatefulWidget { const _SeriesManagerTab(); @override State<_SeriesManagerTab> createState() => _SeriesManagerTabState(); }
class _SeriesManagerTabState extends State<_SeriesManagerTab> {
  final title = TextEditingController(); final desc = TextEditingController(); final pass = TextEditingController(text: '0');
  String poster = '', trailer = ''; bool subscriberOnly = false; bool busy = false;
  List<dynamic> series = [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { title.dispose(); desc.dispose(); pass.dispose(); super.dispose(); }
  Future<void> _load() async { try { final d = await Api.creatorContent(); if (mounted) setState(() => series = List<dynamic>.from(d['series'] ?? const [])); } catch (_) {} }
  Future<void> _uploadImage() async { final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88); if (f == null) return; try { final u = await Api.uploadAndGetUrl(f.path, kind: 'IMAGE'); if (mounted) setState(() => poster = u); } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); } }
  Future<void> _uploadTrailer() async { final f = await FilePicker.platform.pickFiles(type: FileType.video); if (f?.files.single.path == null) return; try { final u = await Api.uploadAndGetUrl(f!.files.single.path!, kind: 'VIDEO'); if (mounted) setState(() => trailer = u); } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); } }
  Future<void> _createSeries() async { if (title.text.trim().length < 2) { toast(context, 'أدخل اسم المسلسل'); return; } setState(() => busy = true); try { await Api.createCreatorSeries({'title':title.text.trim(),'description':desc.text.trim(),'posterUrl':poster,'trailerUrl':trailer,'visibility':'PUBLIC','subscriberOnly':subscriberOnly,'seasonPassPriceCents':int.tryParse(pass.text.trim()) ?? 0,'currency':'USD','creatorSharePct':70}); title.clear(); desc.clear(); poster=''; trailer=''; pass.text='0'; await _load(); if (mounted) toast(context, 'تم إنشاء المسلسل. أضف المواسم والحلقات الآن.'); } catch(e){ if(mounted)toast(context,e.toString().replaceFirst('Exception: ','')); } finally { if(mounted)setState(()=>busy=false); } }
  Future<void> _addSeason(Map<String,dynamic> s) async { final numCtrl=TextEditingController(text:'${((s['seasons'] as List?)?.length ?? 0)+1}'); final titleCtrl=TextEditingController(); final passCtrl=TextEditingController(text:'0'); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إضافة موسم'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:numCtrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'رقم الموسم')),TextField(controller:titleCtrl,decoration:const InputDecoration(labelText:'اسم الموسم')),TextField(controller:passCtrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر Season Pass بالسنت'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إضافة'))])); if(ok!=true)return; try{await Api.createCreatorSeason('${s['id']}',{'number':int.tryParse(numCtrl.text)??1,'title':titleCtrl.text.trim(),'description':'','passPriceCents':int.tryParse(passCtrl.text)??0,'currency':'USD','creatorSharePct':70});await _load();}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));} }
  Future<void> _addEpisode(Map<String, dynamic> season) async {
    final episodeNumber = TextEditingController(
      text: '${((season['episodes'] as List?)?.length ?? 0) + 1}',
    );
    final episodeTitle = TextEditingController();
    final episodeDescription = TextEditingController();
    final price = TextEditingController(text: '0');

    String accessMode = 'FREE';
    String videoUrl = '';
    String thumbnailUrl = '';
    bool uploadingVideo = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة حلقة'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: episodeNumber,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'رقم الحلقة'),
                      ),
                      TextField(
                        controller: episodeTitle,
                        decoration: const InputDecoration(labelText: 'عنوان الحلقة'),
                      ),
                      TextField(
                        controller: episodeDescription,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'الوصف'),
                      ),
                      DropdownButtonFormField<String>(
                        value: accessMode,
                        decoration: const InputDecoration(labelText: 'طريقة الوصول'),
                        items: const [
                          DropdownMenuItem(value: 'FREE', child: Text('مجانية')),
                          DropdownMenuItem(value: 'PAID', child: Text('مدفوعة')),
                          DropdownMenuItem(value: 'SUBSCRIBER', child: Text('للمشتركين')),
                        ],
                        onChanged: (value) {
                          setDialogState(() => accessMode = value ?? 'FREE');
                        },
                      ),
                      TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'السعر بالسنت'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: uploadingVideo
                            ? null
                            : () async {
                                final picked = await FilePicker.platform.pickFiles(
                                  type: FileType.video,
                                );
                                final path = picked?.files.single.path;
                                if (path == null || path.isEmpty) return;

                                setDialogState(() => uploadingVideo = true);
                                try {
                                  videoUrl = await Api.uploadAndGetUrl(
                                    path,
                                    kind: 'VIDEO',
                                  );
                                  if (dialogContext.mounted) {
                                    setDialogState(() {});
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    toast(
                                      dialogContext,
                                      e.toString().replaceFirst('Exception: ', ''),
                                    );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(() => uploadingVideo = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.video_file_rounded),
                        label: Text(
                          videoUrl.isEmpty
                              ? (uploadingVideo
                                  ? 'جارٍ الرفع...'
                                  : 'اختيار فيديو الحلقة')
                              : 'تم رفع الفيديو ✓',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 88,
                          );
                          if (picked == null) return;

                          try {
                            thumbnailUrl = await Api.uploadAndGetUrl(
                              picked.path,
                              kind: 'IMAGE',
                            );
                            if (dialogContext.mounted) {
                              setDialogState(() {});
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              toast(
                                dialogContext,
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          thumbnailUrl.isEmpty
                              ? 'صورة مصغرة'
                              : 'تم اختيار الصورة ✓',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: videoUrl.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('نشر الحلقة'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      episodeNumber.dispose();
      episodeTitle.dispose();
      episodeDescription.dispose();
      price.dispose();
      return;
    }

    try {
      await Api.createCreatorEpisode(
        '${season['id']}',
        {
          'number': int.tryParse(episodeNumber.text) ?? 1,
          'title': episodeTitle.text.trim(),
          'description': episodeDescription.text.trim(),
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'durationSec': 0,
          'accessMode': accessMode,
          'priceCents': int.tryParse(price.text) ?? 0,
          'currency': 'USD',
          'adSupported': false,
          'creatorSharePct': 70,
        },
      );
      await _load();
      if (mounted) toast(context, 'تم نشر الحلقة 🎬');
    } catch (e) {
      if (mounted) {
        toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      episodeNumber.dispose();
      episodeTitle.dispose();
      episodeDescription.dispose();
      price.dispose();
    }
  }

  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[_CreatorPageHeader(title:'مسلسلات + مواسم + حلقات',subtitle:'أنشئ مسلسلًا ثم أضف مواسم وحلقات، مع مجاني/مدفوع/مشتركين.'),_text(title,'اسم المسلسل',Icons.live_tv_rounded),_text(desc,'وصف المسلسل',Icons.description_outlined,maxLines:3),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_uploadImage,icon:const Icon(Icons.image_outlined),label:Text(poster.isEmpty?'بوستر':'بوستر ✓'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:_uploadTrailer,icon:const Icon(Icons.ondemand_video),label:Text(trailer.isEmpty?'تريلر':'تريلر ✓')))]),SwitchListTile(value:subscriberOnly,onChanged:(v)=>setState(()=>subscriberOnly=v),title:const Text('مسلسل للمشتركين فقط'),secondary:const Icon(Icons.workspace_premium_rounded,color:SN.gold)),_text(pass,'سعر Season Pass بالسنت',Icons.payments_outlined,keyboard:TextInputType.number),GradButton(label:'نشر مسلسل',icon:Icons.add_circle_outline,busy:busy,onTap:_createSeries),const SizedBox(height:18),const Text('مسلسلاتي',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),if(series.isEmpty)const EmptyState(text:'لم تنشئ مسلسلًا بعد',icon:Icons.live_tv_outlined),for(final raw in series)if(raw is Map)_seriesCard(Map<String,dynamic>.from(raw))]);
  Widget _seriesCard(Map<String,dynamic> s)=>_Box(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[if('${s['posterUrl']??''}'.isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network('${s['posterUrl']}',width:55,height:72,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:55,height:72))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['title']}',style:const TextStyle(fontWeight:FontWeight.w900)),Text('${(s['seasons'] as List?)?.length ?? 0} موسم',style:TextStyle(color:SN.textMut,fontSize:11))])),IconButton(onPressed:()=>_addSeason(s),icon:const Icon(Icons.playlist_add_rounded,color:SN.violet),tooltip:'إضافة موسم')]),const SizedBox(height:8),for(final seasonRaw in ((s['seasons'] as List?)??const []))if(seasonRaw is Map)_seasonRow(s,Map<String,dynamic>.from(seasonRaw))]));
  Widget _seasonRow(Map<String,dynamic> series,Map<String,dynamic> season)=>Container(margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.035),borderRadius:BorderRadius.circular(14)),child:Row(children:[Expanded(child:Text('الموسم ${season['number']} — ${(season['episodes'] as List?)?.length ?? 0} حلقة')),IconButton(onPressed:()=>_addEpisode(season),icon:const Icon(Icons.add_circle_outline,color:SN.cyan),tooltip:'إضافة حلقة')]));
}

class _SubscriptionPlanTab extends StatefulWidget { const _SubscriptionPlanTab(); @override State<_SubscriptionPlanTab> createState()=>_SubscriptionPlanTabState(); }
class _SubscriptionPlanTabState extends State<_SubscriptionPlanTab>{ final title=TextEditingController(text:'اشتراك SocialNova');final desc=TextEditingController();final product=TextEditingController();final price=TextEditingController(text:'499');final days=TextEditingController(text:'30');bool active=true,busy=false;Map<String,dynamic>? plan;List<dynamic> subscribers=[];@override void initState(){super.initState();_load();}@override void dispose(){title.dispose();desc.dispose();product.dispose();price.dispose();days.dispose();super.dispose();}Future<void> _load()async{try{final d=await Api.creatorContent();plan=d['plan'] is Map?Map<String,dynamic>.from(d['plan']):null;subscribers=List<dynamic>.from(d['subscriptions']??const []);if(plan!=null){title.text='${plan!['title']??title.text}';desc.text='${plan!['description']??''}';product.text='${plan!['productId']??''}';price.text='${plan!['priceCents']??499}';days.text='${plan!['durationDays']??30}';active=plan!['active']!=false;}if(mounted)setState((){});}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}}Future<void> _save()async{if(product.text.trim().isEmpty){toast(context,'أدخل Product ID المنشور في Google Play');return;}setState(()=>busy=true);try{await Api.saveCreatorSubscriptionPlan({'title':title.text.trim(),'description':desc.text.trim(),'productId':product.text.trim(),'priceCents':int.tryParse(price.text)??0,'currency':'USD','durationDays':int.tryParse(days.text)??30,'active':active});await _load();if(mounted)toast(context,'تم حفظ نظام الاشتراك.');}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[_CreatorPageHeader(title:'اشتراك المبدع',subtitle:'أنشئ باقة اشتراك مرتبطة بـ Google Play واستخدم محتوى SUBSCRIBER معها.'),_text(title,'اسم الاشتراك',Icons.workspace_premium_rounded),_text(desc,'وصف الاشتراك',Icons.description_outlined,maxLines:3),_text(product,'Google Play Product ID',Icons.storefront_rounded),Row(children:[Expanded(child:_text(price,'السعر بالسنت',Icons.payments_outlined,keyboard:TextInputType.number)),const SizedBox(width:10),Expanded(child:_text(days,'المدة بالأيام',Icons.calendar_month_rounded,keyboard:TextInputType.number))]),SwitchListTile(value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('تفعيل الاشتراك'),secondary:const Icon(Icons.toggle_on_rounded,color:SN.cyan)),GradButton(label:'حفظ باقة الاشتراك',icon:Icons.save_rounded,busy:busy,onTap:_save),const SizedBox(height:18),Text('المشتركون الحاليون: ${subscribers.length}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),for(final raw in subscribers)if(raw is Map)ListTile(leading:SNav(url:'${(raw['subscriber'] as Map?)?['avatarUrl']??''}',name:'${(raw['subscriber'] as Map?)?['displayName']??'مستخدم'}',size:42),title:Text('${(raw['subscriber'] as Map?)?['displayName']??'مستخدم'}'),subtitle:Text('${raw['status']??''}',style:TextStyle(color:SN.textMut,fontSize:11))) ]);}

class _MyContentTab extends StatefulWidget { const _MyContentTab(); @override State<_MyContentTab> createState()=>_MyContentTabState(); }
class _MyContentTabState extends State<_MyContentTab>{late Future<Map<String,dynamic>> _future=Api.creatorContent();@override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:_future,builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const LoadingBox();final d=s.data??{};final movies=List<dynamic>.from(d['movies']??const []);final series=List<dynamic>.from(d['series']??const []);return RefreshIndicator(onRefresh:()async=>setState(()=>_future=Api.creatorContent()),child:ListView(padding:const EdgeInsets.all(14),children:[_CreatorPageHeader(title:'مكتبة المحتوى',subtitle:'كل الأفلام والمسلسلات والمواسم والحلقات التي نشرتها.'),_Box(child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_stat('الأفلام',movies.length,Icons.movie_creation_outlined),_stat('المسلسلات',series.length,Icons.live_tv),_stat('الحلقات',_episodeCount(series),Icons.video_library_outlined)])),const SizedBox(height:12),for(final raw in movies)if(raw is Map)_contentTile(Map<String,dynamic>.from(raw),true),for(final raw in series)if(raw is Map)_contentTile(Map<String,dynamic>.from(raw),false)]));});int _episodeCount(List<dynamic> rows){var total=0;for(final raw in rows){if(raw is! Map)continue;final seasons=raw['seasons'];if(seasons is! List)continue;for(final season in seasons){if(season is Map&&season['episodes'] is List)total+=(season['episodes'] as List).length;}}return total;}Widget _stat(String t,int n,IconData i)=>Column(children:[Icon(i,color:SN.violet),const SizedBox(height:4),Text('$n',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text(t,style:TextStyle(color:SN.textMut,fontSize:11))]);Widget _contentTile(Map<String,dynamic> x,bool movie)=>Card(color:SN.bg2,child:ListTile(leading:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network('${x['posterUrl']??''}',width:45,height:60,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(width:45,height:60,color:SN.bg3,child:Icon(movie?Icons.movie:Icons.live_tv)))),title:Text('${x['title']??''}',maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text(movie?'فيلم • ${x['accessMode']??'FREE'}':'مسلسل • ${((x['seasons'] as List?)??const []).length} مواسم',style:TextStyle(color:SN.textMut,fontSize:11)),trailing:Icon(movie?Icons.movie_outlined:Icons.live_tv_outlined,color:SN.cyan),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>movie?MovieDetailPage(id:'${x['id']}'):SeriesDetailPage(id:'${x['id']}')))));}

class _CreatorPageShell extends StatelessWidget { const _CreatorPageShell({required this.title,required this.subtitle,required this.children});final String title,subtitle;final List<Widget> children;@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[_CreatorPageHeader(title:title,subtitle:subtitle),...children]); }
class _CreatorPageHeader extends StatelessWidget { const _CreatorPageHeader({required this.title,required this.subtitle});final String title,subtitle;@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:SN.grad,borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:SN.violet.withValues(alpha:.24),blurRadius:24)]),child:Row(children:[Container(width:50,height:50,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.14),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.auto_awesome_rounded,color:Colors.white)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:Colors.white70,fontSize:11,height:1.45))]))]));}
class _Box extends StatelessWidget{const _Box({required this.child});final Widget child;@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:SN.bg2,borderRadius:BorderRadius.circular(20),border:Border.all(color:SN.strokeSoft)),child:child);}
Widget _text(TextEditingController c,String label,IconData icon,{int maxLines=1,TextInputType? keyboard})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,maxLines:maxLines,keyboardType:keyboard,decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon))));
class _UploadRow extends StatelessWidget{const _UploadRow({required this.label,required this.icon,required this.url,required this.onTap});final String label;final IconData icon;final String url;final VoidCallback onTap;@override Widget build(BuildContext context)=>_Box(child:ListTile(contentPadding:EdgeInsets.zero,leading:Icon(icon,color:SN.cyan),title:Text(label,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(url.isEmpty?'لم يتم اختيار ملف':'تم رفع الملف ✓',style:TextStyle(color:url.isEmpty?SN.textMut:SN.cyan,fontSize:11)),trailing:FilledButton(onPressed:onTap,child:Text(url.isEmpty?'اختيار':'تغيير'))));}

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/localization.dart';

class ContentStudio {
  static Future<Map<String, dynamic>?> showOwnerSettings(
    BuildContext context, {
    required String type,
    required String id,
    Map<String, dynamic> initial = const {},
    Future<void> Function()? onEdit,
  }) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OwnerSettingsSheet(type: type, id: id, initial: initial, onEdit: onEdit),
    );
  }

  static Future<Map<String, dynamic>?> showPrePublish(
    BuildContext context, {
    required String type,
    Map<String, dynamic> initial = const {},
  }) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrePublishSheet(type: type, initial: initial),
    );
  }

  static Future<Map<String, dynamic>?> showStoryPublish(
    BuildContext context, {
    Map<String, dynamic> initial = const {},
  }) => showPrePublish(context, type: 'story', initial: initial);

  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = (prefs.getStringList('socialnova_drafts') ?? <String>[]).toList();
    rows.insert(0, jsonEncode({...draft, 'savedAt': DateTime.now().toIso8601String()}));
    await prefs.setStringList('socialnova_drafts', rows.take(30).toList());
  }

  static Future<List<Map<String, dynamic>>> drafts() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('socialnova_drafts') ?? <String>[])
        .map((x) => Map<String, dynamic>.from(jsonDecode(x) as Map))
        .toList();
  }
}


/// زر الثلاث نقاط الخاص بصاحب المحتوى فقط — موحّد للستوري والمنشور والفيديو/الريلز.
class OwnerContentMoreButton extends StatelessWidget {
  const OwnerContentMoreButton({
    super.key,
    required this.type,
    required this.id,
    this.initial = const {},
    this.onEdit,
    this.onChanged,
  });

  final String type;
  final String id;
  final Map<String, dynamic> initial;
  final Future<void> Function()? onEdit;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: SN.bg2.withValues(alpha: .86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SN.violet.withValues(alpha: .55)),
          boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .22), blurRadius: 14)],
        ),
        child: IconButton(
          tooltip: 'إعدادات ${type == 'story' ? 'الستوري' : type == 'post' ? 'المنشور' : 'الريلز'}',
          padding: EdgeInsets.zero,
          icon: Icon(Icons.more_vert_rounded, color: SN.textPri),
          onPressed: () async {
            final result = await ContentStudio.showOwnerSettings(
              context,
              type: type,
              id: id,
              initial: initial,
              onEdit: onEdit,
            );
            if (result != null) onChanged?.call();
          },
        ),
      );
}

class _OwnerSettingsSheet extends StatefulWidget {
  const _OwnerSettingsSheet({required this.type, required this.id, required this.initial, this.onEdit});
  final String type;
  final String id;
  final Map<String, dynamic> initial;
  final Future<void> Function()? onEdit;
  @override State<_OwnerSettingsSheet> createState() => _OwnerSettingsSheetState();
}

class _OwnerSettingsSheetState extends State<_OwnerSettingsSheet> {
  late Map<String, dynamic> values;
  bool busy = false;
  @override void initState() { super.initState(); values = {...widget.initial}; }

  Future<void> _save(Map<String, dynamic> patch) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (widget.type == 'story') {
        await Api.updateStory(widget.id, patch);
      } else if (widget.type == 'post') {
        await Api.updatePost(widget.id, patch);
      } else {
        await Api.updateReel(widget.id, patch);
      }
      values.addAll(patch);
      if (mounted) toast(context, 'تم حفظ إعدادات المحتوى ✨');
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('حذف ${_label()}؟'),
      content: const Text('سيتم حذف المحتوى نهائيًا من الحساب.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف'))],
    ));
    if (ok != true) return;
    try {
      if (widget.type == 'story') await Api.deleteStory(widget.id);
      else if (widget.type == 'post') await Api.deletePost(widget.id);
      else await Api.deleteReel(widget.id);
      if (mounted) { Navigator.pop(context, {'deleted': true}); toast(context, 'تم حذف ${_label()}'); }
    } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
  }

  String _label() => widget.type == 'story' ? 'الستوري' : widget.type == 'post' ? 'المنشور' : 'الريلز';

  Future<void> _audience() async {
    final current = '${values['audienceMode'] ?? values['visibility'] ?? 'PUBLIC'}';
    final v = await showModalBottomSheet<String>(context: context, backgroundColor: SN.bg1, showDragHandle: true, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text(L10n.t('تحديد الجمهور'), style: TextStyle(fontWeight: FontWeight.w900))),
      for (final x in const [
        ['PUBLIC','عام'], ['FOLLOWERS','المتابعون فقط'], ['FRIENDS','أصدقاء محددون'], ['CLOSE_FRIENDS','الأصدقاء المقربون'],
      ]) ListTile(leading: Icon(current == x[0] ? Icons.radio_button_checked : Icons.radio_button_off, color: SN.violet), title: Text(x[1]), onTap: () => Navigator.pop(c, x[0])),
    ])));
    if (v == null) return;
    if (v == 'FRIENDS') {
      final ids = await _pickUsers();
      if (ids == null) return;
      if (widget.type == 'story') {
        await _save({'audienceMode': 'HIDDEN', 'hiddenUserIds': ids});
      } else {
        await _save({'visibility': 'PUBLIC', 'hiddenUserIds': ids});
      }
      return;
    }
    await _save(widget.type == 'story' ? {'audienceMode': v} : {'visibility': v == 'CLOSE_FRIENDS' ? 'FOLLOWERS' : v});
  }

  Future<void> _schedule() async {
    final now = DateTime.now().add(const Duration(hours: 1));
    final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: now);
    if (picked == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    final date = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    await _save({'scheduledAt': date.toUtc().toIso8601String()});
  }

  Future<List<String>?> _pickUsers() async {
    final selected = <String>{};
    final q = TextEditingController();
    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            final query = q.text.trim();
            return AlertDialog(
              title: const Text('اختر أشخاصًا محددين'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: q,
                      onChanged: (_) => setStateDialog(() {}),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث عن شخص'),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: query.length < 2
                          ? Center(child: Text(L10n.t('اكتب حرفين على الأقل')))
                          : FutureBuilder<List<dynamic>>(
                              future: Api.searchUsers(query),
                              builder: (context, snap) {
                                if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
                                final rows = snap.data ?? <dynamic>[];
                                return ListView.builder(
                                  itemCount: rows.length,
                                  itemBuilder: (context, index) {
                                    final u = Map<String, dynamic>.from(rows[index] as Map);
                                    final id = '${u['id'] ?? ''}';
                                    final checked = selected.contains(id);
                                    final name = '${u['displayName'] ?? u['username'] ?? ''}';
                                    return CheckboxListTile(
                                      value: checked,
                                      onChanged: (v) => setStateDialog(() {
                                        if (v == true) { selected.add(id); } else { selected.remove(id); }
                                      }),
                                      secondary: SNav(url: '${u['avatarUrl'] ?? ''}', name: name, size: 40),
                                      title: Text(name),
                                      subtitle: Text('@${u['username'] ?? ''}'),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, selected.toList()), child: Text('حفظ (${selected.length})')),
              ],
            );
          },
        ),
      );
    } finally {
      q.dispose();
    }
  }

  Future<void> _stats() async {
    try {
      final data = await Api.contentAnalytics(widget.type, widget.id);
      if (!mounted) return;
      showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _AnalyticsSheet(type: widget.type, data: data));
    } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _edit() async {
    if (widget.onEdit != null) {
      Navigator.pop(context);
      await widget.onEdit!.call();
      return;
    }
    if (widget.type == 'story') {
      final c = TextEditingController(text: '${values['caption'] ?? ''}');
      final result = await showDialog<String>(context: context, builder: (cxt) => AlertDialog(title: const Text('تعديل الستوري'), content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(labelText: 'النص')), actions: [TextButton(onPressed: () => Navigator.pop(cxt), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(cxt, c.text.trim()), child: const Text('حفظ'))]));
      c.dispose();
      if (result != null) await _save({'caption': result});
    } else {
      toast(context, 'استخدم محرر ${widget.type == 'post' ? 'المنشور' : 'الريلز'} لإعادة ترتيب الوسائط والموسيقى والمؤثرات');
    }
  }

  @override Widget build(BuildContext context) {
    final title = 'إعدادات ${_label()}';
    final items = <Widget>[
      _hero(title, widget.type == 'story' ? Icons.auto_stories_rounded : widget.type == 'post' ? Icons.article_rounded : Icons.movie_creation_rounded),
      _item(Icons.edit_rounded, 'تعديل المحتوى', 'النص، الصور، الوسوم، الموسيقى والمؤثرات', _edit, SN.cyan),
      _item(Icons.visibility_off_rounded, 'إخفاء / الخصوصية', 'قوائم مخصصة وأصدقاء مقربون', _audience, SN.violet),
      _item(Icons.bar_chart_rounded, 'الإحصائيات', 'المشاهدات والتفاعل ووقت الذروة', _stats, SN.green),
      _item(Icons.schedule_rounded, 'الجدولة', 'تحديد تاريخ ووقت النشر', _schedule, SN.cyan),
      _item(Icons.archive_rounded, 'الأرشفة الذكية', values['archived'] == true ? 'المحتوى مؤرشف' : 'نقل المحتوى إلى الأرشيف', () async => _save({'archived': values['archived'] != true}), SN.gold),
    ];
    if (widget.type == 'story') {
      items.addAll([
        _item(Icons.forum_outlined, 'إعدادات الردود', values['replyEnabled'] == false ? 'الردود متوقفة' : 'السماح بالردود', () async => _save({'replyEnabled': values['replyEnabled'] == false}), SN.cyan),
        _item(Icons.remove_red_eye_outlined, 'إخفاء تلقائي', 'بعد عدد مشاهدات أو بعد التفاعل', _autoHide, SN.pink),
        _item(Icons.music_note_rounded, 'الموسيقى', 'إضافة أو تغيير الموسيقى', () => toast(context, 'الموسيقى محفوظة من محرر الستوري'), SN.violet),
      ]);
    } else if (widget.type == 'post') {
      items.addAll([
        _item(Icons.push_pin_rounded, 'تثبيت في البروفايل', values['pinned'] == true ? 'مثبت' : 'تثبيت المنشور', () async => _save({'pinned': values['pinned'] != true}), SN.gold),
        _item(Icons.comment_outlined, 'التعليقات', values['commentsEnabled'] == false ? 'التعليقات متوقفة' : 'السماح بالتعليقات', () async => _save({'commentsEnabled': values['commentsEnabled'] == false}), SN.cyan),
        _item(Icons.repeat_rounded, 'إعادة النشر', values['repostEnabled'] == false ? 'إعادة النشر ممنوعة' : 'السماح بإعادة النشر', () async => _save({'repostEnabled': values['repostEnabled'] == false}), SN.violet),
      ]);
    } else {
      items.addAll([
        _item(Icons.comment_outlined, 'التفاعل', values['commentsEnabled'] == false ? 'الإعجابات فقط' : 'التعليقات والإعجابات', () async => _save({'commentsEnabled': values['commentsEnabled'] == false}), SN.cyan),
        _item(Icons.speed_rounded, 'سرعة الفيديو', 'التحكم من محرر الريلز', () => toast(context, 'التحكم بالسرعة متاح من محرر الريلز'), SN.violet),
        _item(Icons.campaign_rounded, 'ترويج الريلز', 'إعداد حملة ترويجية للمحتوى', () => toast(context, 'الترويج يحتاج ربط بوابة الدفع والإعلانات'), SN.pink),
        _item(Icons.add_to_photos_rounded, 'تحويل إلى ستوري', 'نسخة سريعة من الريلز إلى الستوري', () async { try { await Api.addReelToStory(widget.id); if (mounted) toast(context, 'تم تحويل الريلز إلى ستوري'); } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); } }, SN.green),
      ]);
    }
    items.add(_item(Icons.delete_forever_rounded, 'حذف ${_label()}', 'لا يمكن التراجع عن الحذف', _delete, SN.red));
    return SafeArea(child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .92),
      decoration: BoxDecoration(color: SN.bg1, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: SN.violet.withValues(alpha: .45)), boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .22), blurRadius: 28)]),
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: items),
    ));
  }

  Widget _hero(String title, IconData icon) => Padding(padding: EdgeInsets.fromLTRB(8, 6, 8, 12), child: Row(children: [Container(width:52,height:52,decoration:BoxDecoration(gradient:SN.grad,shape:BoxShape.circle,boxShadow:[BoxShadow(color:SN.violet.withValues(alpha:.35),blurRadius:18)]),child:Icon(icon,color:Colors.white)),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('تحكم كامل بالمحتوى من مكان واحد',style:TextStyle(color:SN.textMut,fontSize:11))])),if(busy)SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2))]));

  Widget _item(IconData icon, String title, String sub, VoidCallback onTap, Color color) => Container(margin:EdgeInsets.symmetric(vertical:4),decoration:BoxDecoration(color:SN.bg2.withValues(alpha:.82),borderRadius:BorderRadius.circular(18),border:Border.all(color:color.withValues(alpha:.25)),boxShadow:[BoxShadow(color:color.withValues(alpha:.06),blurRadius:12)]),child:ListTile(onTap:busy?null:onTap,leading:Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withValues(alpha:.35))),child:Icon(icon,color:color)),title:Text(title,style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(sub,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:SN.textMut,fontSize:11)),trailing:Icon(Icons.chevron_left_rounded,color:SN.textMut)));

  Future<void> _autoHide() async {
    final controller = TextEditingController(text: '${values['autoHideViews'] ?? ''}');
    final enabled = await showDialog<Map<String,dynamic>>(context: context, builder: (c) => AlertDialog(title: const Text('الإخفاء التلقائي'), content: Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:controller,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'بعد عدد مشاهدات (اختياري)')),const SizedBox(height:8),SwitchListTile(value:values['autoHideAfterInteraction']==true,onChanged:(v)=>setState(() => values['autoHideAfterInteraction']=v),title:const Text('بعد التفاعل') )]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,{'autoHideViews':int.tryParse(controller.text.trim())??0,'autoHideAfterInteraction':values['autoHideAfterInteraction']==true}),child:const Text('حفظ'))]));
    controller.dispose();
    if(enabled!=null) await _save(enabled);
  }
}

class _PrePublishSheet extends StatefulWidget {
  const _PrePublishSheet({required this.type, required this.initial});
  final String type;
  final Map<String,dynamic> initial;
  @override State<_PrePublishSheet> createState() => _PrePublishSheetState();
}
class _PrePublishSheetState extends State<_PrePublishSheet> {
  late String audience;
  late bool comments, repost, archive, pinned;
  DateTime? schedule;
  @override void initState(){super.initState(); audience='${widget.initial['audience'] ?? widget.initial['visibility'] ?? (widget.type=='story'?'EVERYONE':'PUBLIC')}';comments=widget.initial['commentsEnabled']!=false;repost=widget.initial['repostEnabled']!=false;archive=widget.initial['archived']==true;pinned=widget.initial['pinned']==true;}
  Future<void> _pickSchedule() async { final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:DateTime.now());if(d==null||!mounted)return;final t=await showTimePicker(context:context,initialTime:TimeOfDay.now());if(t==null)return;setState(()=>schedule=DateTime(d.year,d.month,d.day,t.hour,t.minute)); }
  @override Widget build(BuildContext context)=>SafeArea(child:Container(decoration:BoxDecoration(color:SN.bg1,borderRadius:BorderRadius.vertical(top:Radius.circular(30)),border:Border.all(color:SN.violet.withValues(alpha:.45))),child:Padding(padding:EdgeInsets.fromLTRB(16,10,16,MediaQuery.of(context).viewInsets.bottom+18),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(width:46,height:46,decoration:BoxDecoration(gradient:SN.grad,borderRadius:BorderRadius.circular(15)),child:Icon(widget.type=='story'?Icons.auto_stories_rounded:widget.type=='post'?Icons.article_rounded:Icons.movie_creation_rounded,color:Colors.white)),SizedBox(width:10),Expanded(child:Text(L10n.t('إعدادات النشر'),style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),]),
    const SizedBox(height:14),
    _choice(Icons.groups_rounded,'الجمهور',audience=='PUBLIC'?'عام':audience=='FOLLOWERS'?'المتابعون فقط':audience=='CLOSE_FRIENDS'?'الأصدقاء المقربون':'أصدقاء محددون',()=>_audience()),
    if(widget.type!='story') _switch(Icons.comment_outlined,'السماح بالتعليقات',comments,(v)=>setState(()=>comments=v)),
    _switch(Icons.repeat_rounded,'السماح بإعادة النشر',repost,(v)=>setState(()=>repost=v)),
    if(widget.type=='post') _switch(Icons.push_pin_rounded,'تثبيت بعد النشر',pinned,(v)=>setState(()=>pinned=v)),
    _switch(Icons.archive_outlined,'أرشفة تلقائية',archive,(v)=>setState(()=>archive=v)),
    _choice(Icons.schedule_rounded,'الجدولة',schedule==null?'النشر الآن':DateFormat('yyyy/MM/dd • HH:mm').format(schedule!.toLocal()),_pickSchedule),
    const SizedBox(height:12),
    Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>Navigator.pop(context,{'saveDraft':true}),icon:const Icon(Icons.drafts_outlined),label:const Text('حفظ كمسودة'))),const SizedBox(width:10),Expanded(child:GradButton(label:schedule==null?'نشر الآن':'جدولة النشر',icon:schedule==null?Icons.send_rounded:Icons.schedule_rounded,onTap:()=>Navigator.pop(context,{'audience':audience,'visibility':audience,'commentsEnabled':comments,'repostEnabled':repost,'pinned':pinned,'archived':archive,'scheduledAt':schedule?.toUtc().toIso8601String()})))])
  ])))));
  Future<void> _audience() async {final v=await showModalBottomSheet<String>(context:context,backgroundColor:SN.bg1,showDragHandle:true,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(title:Text(L10n.t('الجمهور'),style:TextStyle(fontWeight:FontWeight.w900))),for(final x in [['PUBLIC','عام'],['FOLLOWERS','المتابعون فقط'],['CLOSE_FRIENDS','الأصدقاء المقربون'],['FRIENDS','أصدقاء محددون']])ListTile(leading:Icon(audience==x[0]?Icons.radio_button_checked:Icons.radio_button_off,color:SN.violet),title:Text(x[1]),onTap:()=>Navigator.pop(c,x[0]))])));if(v==null)return;if(v=='FRIENDS'){setState(()=>audience='FRIENDS');return;}setState(()=>audience=v);}
  Widget _choice(IconData icon,String title,String sub,VoidCallback tap)=>Container(margin:EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:SN.bg2,borderRadius:BorderRadius.circular(18),border:Border.all(color:SN.strokeSoft)),child:ListTile(onTap:tap,leading:Icon(icon,color:SN.cyan),title:Text(title,style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(sub,style:TextStyle(color:SN.textMut,fontSize:11)),trailing:Icon(Icons.chevron_left_rounded)));
  Widget _switch(IconData icon,String title,bool value,ValueChanged<bool> f)=>Container(margin:EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:SN.bg2,borderRadius:BorderRadius.circular(18),border:Border.all(color:SN.strokeSoft)),child:SwitchListTile(value:value,onChanged:f,title:Text(title,style:TextStyle(fontWeight:FontWeight.w700)),secondary:Icon(icon,color:SN.violet),activeColor:SN.violet));
}

class _AnalyticsSheet extends StatelessWidget {
  const _AnalyticsSheet({required this.type, required this.data});
  final String type; final Map<String,dynamic> data;
  @override Widget build(BuildContext context){final metrics=<String,dynamic>{'المشاهدات':data['views']??data['viewCount']??0,'الإعجابات':data['likes']??0,'التعليقات':data['comments']??0,'المشاركات':data['shares']??0,'إعادة النشر':data['reposts']??0};return SafeArea(child:Container(decoration:BoxDecoration(color:SN.bg1,borderRadius:BorderRadius.vertical(top:Radius.circular(30))),child:Padding(padding:EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('إحصائيات ${type=='story'?'الستوري':type=='post'?'المنشور':'الريلز'}',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:14),GridView.count(shrinkWrap:true,crossAxisCount:2,childAspectRatio:2.3,crossAxisSpacing:10,mainAxisSpacing:10,children:[for(final e in metrics.entries)GlassCard(padding:EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.key,style:TextStyle(color:SN.textMut,fontSize:11)),Text('${e.value}',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))]))]),SizedBox(height:12),Text('معدل التفاعل: ${data['engagementRate'] ?? '—'}',style:TextStyle(color:SN.cyan,fontWeight:FontWeight.w800)),Text('وقت الذروة: ${data['peakTime'] ?? '—'}',style:TextStyle(color:SN.textSec)),Text('الأشخاص الأكثر نشاطًا: ${data['topUsersCount'] ?? 0}',style:TextStyle(color:SN.textSec)),SizedBox(height:8)]))));}
}

class ContentStudioPage extends StatelessWidget {
  const ContentStudioPage({super.key});
  Future<void> _showDrafts(BuildContext context) async {
    final rows = await ContentStudio.drafts();
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 480,
          child: rows.isEmpty
              ? const EmptyState(
                  text: 'لا توجد مسودات محفوظة',
                  icon: Icons.drafts_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    const Text(
                      'المسودات المحفوظة',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    for (final d in rows)
                      GlassCard(
                        child: ListTile(
                          leading: Icon(
                            d['type'] == 'reel'
                                ? Icons.movie_creation_rounded
                                : d['type'] == 'story'
                                    ? Icons.auto_stories_rounded
                                    : Icons.article_rounded,
                            color: SN.violet,
                          ),
                          title: Text(
                            '${d['title'] ?? d['caption'] ?? 'مسودة'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${d['savedAt'] ?? ''}',
                            style: TextStyle(color: SN.textMut, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('استوديو المحتوى'),backgroundColor:SN.bg1),body:ListView(padding:EdgeInsets.all(14),children:[GlassCard(gradient:SN.grad,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('SocialNova Content Studio',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:5),Text(L10n.t('إدارة الستوري والمنشورات والريلز والخصوصية والجدولة والإحصائيات من لوحة واحدة.'),style:TextStyle(color:Colors.white70))])),SizedBox(height:12),GlassCard(child:ListTile(leading:Icon(Icons.drafts_outlined,color:SN.gold),title:Text('المسودات',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('مسودات محفوظة على الجهاز'),trailing:Icon(Icons.chevron_left_rounded),onTap:()=>_showDrafts(context))),SizedBox(height:8),for(final x in [['story','إدارة الستوري',Icons.auto_stories_rounded],['post','إدارة المنشورات',Icons.article_rounded],['reel','إدارة الريلز',Icons.movie_creation_rounded]])GlassCard(child:ListTile(leading:Icon(x[2] as IconData,color:SN.cyan),title:Text(x[1] as String,style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('افتح المحتوى من ملفك ثم اضغط ⋮ لإدارة المحتوى'),trailing:Icon(Icons.chevron_left_rounded))) ]));
}

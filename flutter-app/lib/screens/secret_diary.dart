import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/theme.dart';

class SecretDiaryPage extends StatefulWidget {
  const SecretDiaryPage({super.key});
  @override State<SecretDiaryPage> createState() => _SecretDiaryPageState();
}
class _SecretDiaryPageState extends State<SecretDiaryPage> {
  static const storage=FlutterSecureStorage();
  static const key='socialnova_secret_diary_entries_v1', pinKey='socialnova_secret_diary_pin_v1';
  List<Map<String,dynamic>> entries=[]; bool locked=true,busy=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {try{final raw=await storage.read(key:key);if(raw!=null&&raw.isNotEmpty){final d=jsonDecode(raw);if(d is List)entries=d.map((e)=>Map<String,dynamic>.from(e as Map)).toList();}final pin=await storage.read(key:pinKey);locked=pin!=null&&pin.isNotEmpty;}catch(_){}if(mounted)setState(()=>busy=false);}
  Future<void> _save() async=>storage.write(key:key,value:jsonEncode(entries));
  Future<void> _unlock() async {final pin=await storage.read(key:pinKey);if(pin==null||pin.isEmpty){setState(()=>locked=false);return;}final c=TextEditingController();final v=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('فتح المذكرات السرية'),content:TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,maxLength:8,decoration:const InputDecoration(labelText:'الرمز السري')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('فتح'))]));if(v==pin){setState(()=>locked=false);}else if(v!=null&&mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الرمز غير صحيح')));}}
  Future<void> _setPin() async {final c=TextEditingController();final v=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('تعيين رمز المذكرات'),content:TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,maxLength:8,decoration:const InputDecoration(labelText:'4 إلى 8 أرقام')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('حفظ'))]));if(v==null)return;if(v.length<4){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('استخدم 4 أرقام على الأقل')));return;}await storage.write(key:pinKey,value:v);if(mounted)setState(()=>locked=true);}
  Future<void> _add() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String mood = '🙂';
    int days = 0;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('مذكرة جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
            const SizedBox(height: 8),
            TextField(controller: body, minLines: 4, maxLines: 9, decoration: const InputDecoration(labelText: 'اكتب مذكرتك هنا...')),
            const SizedBox(height: 8),
            Wrap(spacing: 4, children: ['🙂','😊','😌','😐','😔','😡'].map((m) => ChoiceChip(label: Text(m), selected: mood == m, onSelected: (_) => set(() => mood = m))).toList()),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(value: days, decoration: const InputDecoration(labelText: 'الحذف التلقائي'), items: const [
              DropdownMenuItem(value: 0, child: Text('لا يوجد')), DropdownMenuItem(value: 1, child: Text('بعد يوم')),
              DropdownMenuItem(value: 7, child: Text('بعد 7 أيام')), DropdownMenuItem(value: 30, child: Text('بعد 30 يومًا')),
            ], onChanged: (v) => set(() => days = v ?? 0)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, body.text.trim().isNotEmpty), icon: const Icon(Icons.lock_rounded), label: const Text('حفظ بشكل خاص'))),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    entries.insert(0, {'id':'${now.microsecondsSinceEpoch}_${Random().nextInt(9999)}','title':title.text.trim().isEmpty?'مذكرتي':title.text.trim(),'body':body.text.trim(),'mood':mood,'createdAt':now.toIso8601String(),'expiresAt':days==0?null:now.add(Duration(days: days)).toIso8601String()});
    await _save();
    if (mounted) setState(() {});
  }
  Future<void> _delete(Map<String,dynamic> e) async {entries.removeWhere((x)=>x['id']==e['id']);await _save();if(mounted)setState((){});}
  void _open(Map<String,dynamic> e)=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>Padding(padding:const EdgeInsets.fromLTRB(20,8,20,30),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${e['mood']??'🙂'}  ${e['title']}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:12),Text('${e['body']}',style:const TextStyle(fontSize:16,height:1.6)),const SizedBox(height:12),Text('مذكرة خاصة على هذا الجهاز',style:TextStyle(color:SN.textMut,fontSize:12))])));
  @override
  Widget build(BuildContext context) {
    if (busy) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('المذكرات السرية')),
        body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: SN.violet.withOpacity(.1), shape: BoxShape.circle), child: const Icon(Icons.lock_rounded, size: 58, color: SN.violet)),
          const SizedBox(height: 18), const Text('مذكراتك خاصة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
          Text('تُخزن محليًا في التخزين الآمن ولا تُرسل إلى مستخدمين آخرين.', textAlign: TextAlign.center, style: TextStyle(color: SN.textMut)),
          const SizedBox(height: 20), FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.lock_open_rounded), label: const Text('فتح المذكرات')),
          const SizedBox(height: 8), TextButton(onPressed: _setPin, child: const Text('تعيين أو تغيير الرمز')),
        ]))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('المذكرات السرية'), actions: [IconButton(onPressed: _setPin, icon: const Icon(Icons.pin_outlined))]),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: entries.isEmpty
          ? const Center(child: Text('لا توجد مذكرات بعد'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16,16,16,100),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = entries[i];
                final ex = e['expiresAt'] == null ? null : DateTime.tryParse('${e['expiresAt']}');
                if (ex != null && ex.isBefore(DateTime.now())) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _delete(e));
                  return const SizedBox.shrink();
                }
                return Card(child: ListTile(
                  onTap: () => _open(e),
                  leading: CircleAvatar(backgroundColor: SN.violet.withOpacity(.12), child: Text('${e['mood'] ?? '🙂'}')),
                  title: Text('${e['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${e['body']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline)),
                ));
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Maximum Privacy Mode: combines server privacy controls with local screen
/// protection and an optional separate PIN. Screenshot protection is best-effort
/// OS security, not a guarantee against every form of copying.
class MaximumPrivacyPage extends StatefulWidget {
  const MaximumPrivacyPage({super.key});
  @override State<MaximumPrivacyPage> createState() => _MaximumPrivacyPageState();
}

class _MaximumPrivacyPageState extends State<MaximumPrivacyPage> {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'sn_max_privacy_enabled';
  static const _pinKey = 'sn_max_privacy_pin';
  static const _aliasKey = 'sn_max_privacy_alias';
  static const _secureChannel = MethodChannel('socialnova/privacy');
  bool enabled=false, hideSearch=false, hideSuggestions=false, hideActivity=false, privateContent=false, blockRequests=false, privateNotifications=true, autoLock=true;
  bool loading=true, saving=false;
  String alias='';

  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    try {
      final me=await Api.me$();
      final stored=await _storage.read(key:_enabledKey);
      final a=await _storage.read(key:_aliasKey);
      if(!mounted)return;
      setState((){enabled=stored=='1'; hideSearch=me['hideFromSearch']==true; hideSuggestions=me['hideFromSuggestions']==true; hideActivity=me['showOnlineStatus']==false; privateContent=me['isPrivate']==true; blockRequests=me['allowMessageRequests']==false; alias=a??''; loading=false;});
    } catch(_){if(mounted)setState(()=>loading=false);}
  }
  Future<void> _saveServer() async {
    setState(()=>saving=true);
    try { await Api.updateSettings({'hideFromSearch':hideSearch,'hideFromSuggestions':hideSuggestions,'showOnlineStatus':!hideActivity,'isPrivate':privateContent,'allowMessageRequests':!blockRequests}); }
    catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> _toggle(bool v) async {
    setState(()=>enabled=v);
    await _storage.write(key:_enabledKey,value:v?'1':'0');
    try{await _secureChannel.invokeMethod('setSecure',{'enabled':v});}catch(_){ }
    if(v){ setState((){hideSearch=true;hideSuggestions=true;hideActivity=true;privateContent=true;blockRequests=true;}); await _saveServer(); }
  }
  Future<void> _setPin() async {
    final c=TextEditingController();
    final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('رمز الوضع الأقصى'),content:TextField(controller:c,keyboardType:TextInputType.number,obscureText:true,maxLength:8,decoration:const InputDecoration(hintText:'4 إلى 8 أرقام')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('حفظ'))]));
    if(value!=null && value.length>=4){await _storage.write(key:_pinKey,value:value);if(mounted)toast(context,'تم حفظ رمز الحماية');}
  }
  Future<void> _setAlias() async {
    final c=TextEditingController(text:alias);
    final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('هوية مؤقتة'),content:TextField(controller:c,maxLength:30,decoration:const InputDecoration(hintText:'مثال: Nova_07')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('حفظ'))]));
    if(value!=null){setState(()=>alias=value);await _storage.write(key:_aliasKey,value:value);}
  }
  Widget _sw(String title,String sub,bool value,ValueChanged<bool> onChanged)=>SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(sub,style:const TextStyle(fontSize:12,color:SN.textMut)),value:value,onChanged:onChanged);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية القصوى'), actions: [if (saving) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))]),
      body: loading ? const LoadingBox() : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [SN.violet.withOpacity(.18), SN.cyan.withOpacity(.10)]), border: Border.all(color: SN.strokeSoft)), child: Row(children: [
            const Icon(Icons.shield_rounded, size: 42, color: SN.violet), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('وضع الخصوصية القصوى', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(enabled ? 'الحماية مفعّلة' : 'فعّلها لتطبيق إعدادات الخصوصية المتقدمة', style: const TextStyle(color: SN.textMut))])),
            Switch.adaptive(value: enabled, onChanged: _toggle),
          ])),
          const SizedBox(height: 18),
          _sw('إخفاء الحساب من البحث','لن يظهر حسابك في نتائج البحث.',hideSearch,(v){setState(()=>hideSearch=v);_saveServer();}),
          _sw('إخفاء الحساب من الاقتراحات','لا يظهر حسابك ضمن اقتراحات المتابعة.',hideSuggestions,(v){setState(()=>hideSuggestions=v);_saveServer();}),
          _sw('إخفاء النشاط','لا يظهر متصل الآن أو آخر ظهور.',hideActivity,(v){setState(()=>hideActivity=v);_saveServer();}),
          _sw('محتوى خاص افتراضيًا','اجعل الحساب خاصًا ولا تعرض المحتوى للعامة.',privateContent,(v){setState(()=>privateContent=v);_saveServer();}),
          _sw('منع طلبات الرسائل','لن تصلك طلبات محادثة جديدة من الغرباء.',blockRequests,(v){setState(()=>blockRequests=v);_saveServer();}),
          _sw('إخفاء الإشعارات الحساسة','يبقى محتوى الرسائل الحساسة داخل التطبيق.',privateNotifications,(v)=>setState(()=>privateNotifications=v)),
          _sw('قفل تلقائي','فعّل حماية الشاشة عند تشغيل الوضع.',autoLock,(v)async{setState(()=>autoLock=v);if(enabled){try{await _secureChannel.invokeMethod('setSecure',{'enabled':v});}catch(_){}}}),
          const SizedBox(height: 12),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.pin_outlined), title: const Text('رمز دخول مستقل'), onTap: _setPin),
            ListTile(leading: const Icon(Icons.person_off_outlined), title: const Text('هوية مخفية مؤقتًا'), subtitle: Text(alias.isEmpty ? 'لم يتم تعيين اسم مستعار' : 'الاسم: $alias'), onTap: _setAlias),
          ])),
          const SizedBox(height: 12),
          const Text('ملاحظة أمنية: منع لقطات الشاشة يعتمد على حماية نظام التشغيل ولا يمنع كل طرق النسخ.', style: TextStyle(fontSize: 12, color: SN.textMut)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

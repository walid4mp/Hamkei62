import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class SocialNovaHubPage extends StatefulWidget {
  const SocialNovaHubPage({super.key});
  @override State<SocialNovaHubPage> createState()=>_SocialNovaHubPageState();
}

class _SocialNovaHubPageState extends State<SocialNovaHubPage> {
  late Future<Map<String,dynamic>> future;
  @override void initState(){super.initState();future=Api.socialHub();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:SN.bg0,
    appBar:AppBar(title:const Text('SocialNova Hub'),backgroundColor:SN.bg1),
    body:FutureBuilder<Map<String,dynamic>>(
      future:future,
      builder:(context,s){
        if(s.connectionState==ConnectionState.waiting)return const LoadingBox();
        if(s.hasError)return Center(child:Text('تعذر تحميل Hub: ${s.error}'));
        final d=s.data??{}; final movies=List<dynamic>.from(d['movies']??[]); final series=List<dynamic>.from(d['series']??[]); final audio=List<dynamic>.from(d['audioRooms']??[]); final teams=List<dynamic>.from(d['creatorTeams']??[]); final academy=List<dynamic>.from(d['academy']??[]);
        return RefreshIndicator(onRefresh:()async=>setState((){future=Api.socialHub();}),child:ListView(padding:const EdgeInsets.all(14),children:[
          _title('🎬','الأفلام'),
          if(movies.isEmpty)const _Empty(text:'لا توجد أفلام منشورة بعد') else ...movies.map((x)=>_movieCard(Map<String,dynamic>.from(x as Map))),
          const SizedBox(height:16),_title('📺','المسلسلات'),
          if(series.isEmpty)const _Empty(text:'لا توجد مسلسلات منشورة بعد') else ...series.map((x)=>_seriesCard(Map<String,dynamic>.from(x as Map))),
          const SizedBox(height:16),_title('🎤','الغرف الصوتية'),
          ...audio.take(8).map((x)=>_simpleCard('🎤 ${x['title']??'غرفة صوتية'}','${x['topic']??''}')),
          const SizedBox(height:16),_title('👥','فرق المبدعين'),
          ...teams.take(8).map((x)=>_simpleCard('👥 ${x['name']??'فريق'}','${x['description']??''}')),
          const SizedBox(height:16),_title('📚','Creator Academy'),
          ...academy.take(8).map((x)=>_simpleCard('📚 ${x['title']??'دورة'}','${x['description']??''}')),
        ]));
      },
    ),
  );
  Widget _title(String emoji,String text)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Text('$emoji  $text',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)));
  Widget _movieCard(Map<String,dynamic> m)=>Card(color:SN.bg1,child:ListTile(leading:_poster('${m['posterUrl']??''}'),title:Text('${m['title']??''}',maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text(_access('${m['accessMode']}',m['priceCents']),maxLines:1),trailing:const Icon(Icons.play_circle_fill_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ContentViewer(kind:'MOVIE',id:'${m['id']}')))));
  Widget _seriesCard(Map<String,dynamic> s){final seasons=List<dynamic>.from(s['seasons']??[]);final eps=seasons.expand((x)=>List<dynamic>.from((x as Map)['episodes']??[])).length;return Card(color:SN.bg1,child:ListTile(leading:_poster('${s['posterUrl']??''}'),title:Text('${s['title']??''}'),subtitle:Text('${seasons.length} مواسم • $eps حلقات'),trailing:const Icon(Icons.chevron_left_rounded),onTap:()=>showModalBottomSheet(context:context,backgroundColor:SN.bg1,showDragHandle:true,builder:(_)=>ListView(padding:const EdgeInsets.all(14),children:[Text('${s['title']??''}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),...seasons.map((se){final sm=Map<String,dynamic>.from(se as Map);return ExpansionTile(title:Text('الموسم ${sm['number']??''}'),children:List<dynamic>.from(sm['episodes']??[]).map((e){final em=Map<String,dynamic>.from(e as Map);return ListTile(title:Text('الحلقة ${em['number']??''} — ${em['title']??''}'),subtitle:Text(_access('${em['accessMode']}',em['priceCents'])),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ContentViewer(kind:'EPISODE',id:'${em['id']}'))));}).toList());})]))));}
  Widget _simpleCard(String a,String b)=>Card(color:SN.bg1,child:ListTile(title:Text(a),subtitle:Text(b,maxLines:2,overflow:TextOverflow.ellipsis)));
  Widget _poster(String url)=>Container(width:52,height:52,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),gradient:SN.grad),child:url.isEmpty?const Icon(Icons.movie,color:Colors.white):ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.movie,color:Colors.white))));
  String _access(String mode,dynamic cents){if(mode=='FREE')return '🆓 مجاني';if(mode=='SUBSCRIBER')return '⭐ للمشتركين فقط';return '🔒 مدفوع • ${(NumberFormatHelper.money(cents))}';}
}

class NumberFormatHelper { static String money(dynamic cents){final n=(num.tryParse('$cents')??0)/100;return '\$${n.toStringAsFixed(2)}';} }
class _Empty extends StatelessWidget{const _Empty({required this.text});final String text;@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.all(12),child:Text(text,style:TextStyle(color:SN.textMut)));}

class ContentViewer extends StatefulWidget{const ContentViewer({super.key,required this.kind,required this.id});final String kind,id;@override State<ContentViewer> createState()=>_ContentViewerState();}
class _ContentViewerState extends State<ContentViewer>{Map<String,dynamic>? data;String? error;VideoPlayerController? controller;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{final a=await Api.contentAccess(widget.kind,widget.id);if(a['allowed']!=true){setState(()=>loading=false);return;}final r=await Api.contentView(widget.kind,widget.id);final url='${r['videoUrl']??''}';if(url.isNotEmpty){controller=VideoPlayerController.networkUrl(Uri.parse(url));await controller!.initialize();controller!.play();}if(mounted)setState(()=>loading=false);}catch(e){if(mounted)setState((){error='$e';loading=false;});}}
  @override void dispose(){controller?.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text(widget.kind=='MOVIE'?'فيلم':'حلقة')),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!,style:const TextStyle(color:Colors.white))):controller==null?const Center(child:Text('هذا المحتوى مقفل. يلزم الشراء أو الاشتراك.',style:TextStyle(color:Colors.white,fontSize:18),textAlign:TextAlign.center)):Center(child:AspectRatio(aspectRatio:controller!.value.aspectRatio,child:VideoPlayer(controller!))));}

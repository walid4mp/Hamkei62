import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../core/localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;

import 'wallet.dart';

import '../core/api.dart';
import '../core/chat_bubbles.dart';
import '../core/socket.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'profile.dart';

// ---------------------------------------------------------------------------
// Helper used across screens: open another user's profile.
// ---------------------------------------------------------------------------
void openProfile(BuildContext context, String userId) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)),
  );
}


Future<void> openMentionProfile(BuildContext context, String username) async {
  final q = username.trim().replaceFirst(RegExp(r'^@'), '');
  if (q.isEmpty) return;
  try {
    final rows = await Api.searchUsers(q);
    final exact = rows.cast<dynamic>().map((e) => Map<String, dynamic>.from(e as Map)).where((u) => '${u['username'] ?? ''}'.toLowerCase() == q.toLowerCase()).toList();
    final u = exact.isNotEmpty ? exact.first : (rows.isNotEmpty ? Map<String, dynamic>.from(rows.first as Map) : <String,dynamic>{});
    final id = '${u['id'] ?? ''}';
    if (id.isNotEmpty && context.mounted) openProfile(context, id);
    else if (context.mounted) toast(context, 'المستخدم غير موجود');
  } catch (_) {
    if (context.mounted) toast(context, 'تعذر فتح الملف الشخصي');
  }
}

Widget mentionText(BuildContext context, String text, {TextStyle? style, TextStyle? mentionStyle, int? maxLines, TextOverflow? overflow}) {
  final base = style ?? const TextStyle(fontSize: 14);
  final ms = mentionStyle ?? base.copyWith(color: SN.cyan, fontWeight: FontWeight.w800);
  final spans = <TextSpan>[];
  final re = RegExp(r'@[A-Za-z0-9_.\u0600-\u06FF]+');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    final token = text.substring(m.start, m.end);
    spans.add(TextSpan(text: token, style: ms, recognizer: TapGestureRecognizer()..onTap = () => openMentionProfile(context, token.substring(1))));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
  return RichText(text: TextSpan(children: spans, style: base), maxLines: maxLines, overflow: overflow ?? TextOverflow.clip);
}

Future<void> shareSocialItemToChats(BuildContext context, {required String title, required String body, required IconData icon}) async {
  try {
    final convos = await Api.conversations();
    if (!context.mounted) return;
    final selected = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: SN.bg1,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .72,
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 10), child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(gradient: SN.grad, shape: BoxShape.circle), child: Icon(icon, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                Text('${selected.length} محدد', style: TextStyle(color: SN.textMut, fontSize: 12)),
              ])),
              Expanded(child: convos.isEmpty ? const EmptyState(text: 'لا توجد محادثات لإرسال المشاركة إليها', icon: Icons.chat_bubble_outline) : ListView.builder(
                itemCount: convos.length,
                itemBuilder: (_, i) {
                  final u = Map<String, dynamic>.from(convos[i] as Map);
                  final id = '${u['id'] ?? ''}';
                  final checked = selected.contains(id);
                  return ListTile(
                    leading: SNav(url: '${u['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? u['username'] ?? ''}', size: 46, ring: true),
                    title: Text('${u['displayName'] ?? u['username'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('@${u['username'] ?? ''}', style: TextStyle(color: SN.textMut, fontSize: 12)),
                    trailing: Checkbox(value: checked, onChanged: (v) => setSheet(() { if (v == true) { selected.add(id); } else { selected.remove(id); } })),
                    onTap: () => setSheet(() { if (checked) { selected.remove(id); } else { selected.add(id); } }),
                  );
                },
              )),
              Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: selected.isEmpty ? null : () async {
                  Navigator.pop(ctx);
                  var sent = 0;
                  for (final id in selected) { try { await Api.sendMessage(id, body); sent++; } catch (_) {} }
                  if (context.mounted) toast(context, 'تمت مشاركة $title مع $sent محادثة');
                },
                icon: const Icon(Icons.send_rounded), label: Text(L10n.t('إرسال المشاركة')),
              ))),
            ]),
          ),
        ),
      ),
    );
  } catch (e) { if (context.mounted) toast(context, 'تعذّر تحميل المحادثات'); }
}

// ---------------------------------------------------------------------------
// Messenger: inbox + per-user chat
// ---------------------------------------------------------------------------
class MessengerPage extends StatefulWidget {
  const MessengerPage({super.key});

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    SocketService.i.connect();
    _future = Api.conversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SN.bg1,
        title: const Text('Messenger'),
        actions: [
          IconButton(tooltip:'طلبات المراسلة',onPressed:()=>showMessageRequests(context),icon:const Icon(Icons.mail_outline_rounded)),
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessengerSearchPage()));
              if (!mounted) return;
              setState(() => _future = Api.conversations());
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: SN.violet,
        onRefresh: () async => setState(() => _future = Api.conversations()),
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
            if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
            final convos = snap.data ?? [];
            if (convos.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(text: 'لا توجد محادثات بعد.\nابحث عن صديق وابدأ الدردشة.', icon: Icons.chat_bubble_outline),
              ]);
            }
            return ListView(
              children: [
                for (final u in convos)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: GestureDetector(onTap: () => openProfile(context, '${(u as Map)['id'] ?? ''}'), child: SNav(url: '${u['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? ''}', size: 50, ring: true)),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text('${u['displayName'] ?? ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 5),
                        VerifiedBadge(
                          tier: '${u['verificationTier'] ?? (u['isVerified'] == true ? 'NORMAL' : 'NONE')}',
                          size: 14,
                        ),
                      ],
                    ),
                    subtitle: Text('@${u['username'] ?? ''}', style: TextStyle(color: SN.textMut, fontSize: 12)),
                    trailing: Icon(Icons.chevron_left, color: SN.textMut),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          userId: '${u['id']}',
                          name: '${u['displayName'] ?? u['username'] ?? ''}',
                          avatar: '${u['avatarUrl'] ?? ''}',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MessengerSearchPage extends StatefulWidget {
  const MessengerSearchPage({super.key});

  @override
  State<MessengerSearchPage> createState() => _MessengerSearchPageState();
}

class _MessengerSearchPageState extends State<MessengerSearchPage> {
  final ctrl = TextEditingController();
  List<dynamic> results = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  Future<void> _loadSuggested() async {
    setState(() => busy = true);
    try {
      final r = await Api.suggestedUsers();
      if (!mounted) return;
      setState(() => results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> run() async {
    if (ctrl.text.trim().length < 2) return;
    setState(() => busy = true);
    try {
      final r = await Api.searchUsers(ctrl.text.trim());
      if (!mounted) return;
      setState(() => results = r);
    } catch (e) {
      if (!mounted) return;
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SN.bg1,
        title: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (_) => run(),
          decoration: const InputDecoration(
            hintText: 'ابحث لبدء محادثة...',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [IconButton(onPressed: run, icon: const Icon(Icons.search))],
      ),
      body: busy
          ? const LoadingBox()
          : ListView(
              children: [
                if (results.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: Text(L10n.t('أشخاص لبدء محادثة'), style: const TextStyle(color: SN.cyan, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                for (final u in results)
                  ListTile(
                    leading: SNav(url: '${(u as Map)['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? ''}', size: 44),
                    title: Text('${u['displayName'] ?? ''}'),
                    subtitle: Text('@${u['username'] ?? ''}', style: TextStyle(color: SN.textMut, fontSize: 12)),
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          userId: '${u['id']}',
                          name: '${u['displayName'] ?? u['username'] ?? ''}',
                          avatar: '${u['avatarUrl'] ?? ''}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> showMessageRequests(BuildContext context) async {
  try {
    final rows = await Api.messageRequests();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: SN.bg1,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const Text(
                'طلبات المراسلة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(child: Text(L10n.t('لا توجد طلبات مراسلة'))),
                ),
              for (final raw in rows)
                Builder(
                  builder: (_) {
                    final x = Map<String, dynamic>.from(raw as Map);
                    final u = Map<String, dynamic>.from(
                      (x['sender'] ?? {}) as Map,
                    );
                    final senderName =
                        '${u['displayName'] ?? u['username'] ?? ''}';
                    return Card(
                      child: ListTile(
                        leading: SNav(
                          url: '${u['avatarUrl'] ?? ''}',
                          name: senderName,
                          size: 44,
                        ),
                        title: Text(senderName),
                        subtitle: Text(
                          '${x['body'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await Api.rejectMessageRequest('${x['id']}');
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  showMessageRequests(context);
                                }
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: SN.red,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await Api.acceptMessageRequest('${x['id']}');
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              icon: const Icon(
                                Icons.check_rounded,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  } catch (e) {
    if (context.mounted) {
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.userId, required this.name, this.avatar = ''});

  final String userId;
  final String name;
  final String avatar;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, dynamic>> msgs = [];
  final Set<String> _viewedMediaMessages = <String>{};
  bool loading = true;
  bool sending = false;
  bool recording = false;
  bool muted = false;
  bool blocked = false;
  String _chatTheme = 'gradient:midnight';

  bool secretMode = false;
  bool selfDestruct = false;
  int secretTtl = 60;
  int viewLimit = 0;
  dynamic _sub;
  dynamic _deliveredSub;
  dynamic _readSub;
  dynamic _requestAcceptedSub;
  final AudioRecorder _recorder = AudioRecorder();
  late final AnimationController _chatFxController;
  NavigatorState? _navigator;
  dynamic _callSub;
  bool _callDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _chatFxController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    SocketService.i.connect();
    _callSub = SocketService.i.callInvites.listen((m) {
      if (!mounted || _callDialogOpen) return;
      if ('${m['fromId']}' != widget.userId) return;
      _showIncomingCall(m);
    });
    _sub = SocketService.i.messages.listen((m) {
      final mine = '${m['senderId']}' == '${Api.me?['id']}';
      if (mine || '${m['senderId']}' == widget.userId) {
        if (!msgs.any((x) => '${x['id']}' == '${m['id']}')) {
          setState(() => msgs.add(m));
          if (!mine && '${m['receiverId']}' == '${Api.me?['id']}') {
            Api.markMessageDelivered('${m['id']}').catchError((_) {});
            Api.markMessageRead('${m['id']}').catchError((_) {});
          }
          _scrollDown();
        }
      }
    });
    _deliveredSub = SocketService.i.messageDelivered.listen((m) {
      final id = '${m['messageId'] ?? ''}';
      if (id.isEmpty || !mounted) return;
      setState(() {
        for (final x in msgs) { if ('${x['id']}' == id) x['deliveredAt'] = m['deliveredAt']; }
      });
    });
    _readSub = SocketService.i.messageRead.listen((m) {
      final id = '${m['messageId'] ?? ''}';
      if (id.isEmpty || !mounted) return;
      setState(() {
        for (final x in msgs) { if ('${x['id']}' == id) { x['read'] = true; x['readAt'] = m['readAt']; } }
      });
    });
    _requestAcceptedSub = SocketService.i.messageRequestAccepted.listen((m) {
      if (!mounted) return;
      _load();
      toast(context, 'تم قبول طلب المراسلة 💬');
    });
    _loadChatTheme();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context, rootNavigator: true);
  }

  Future<void> _load() async {
    try {
      final r = await Api.messages(widget.userId);
      if (!mounted) return;
      final loaded = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        msgs
          ..clear()
          ..addAll(loaded);
        loading = false;
      });
      for (final m in loaded) {
        if ('${m['receiverId']}' == '${Api.me?['id']}' && m['read'] != true) {
          Api.markMessageDelivered('${m['id']}').catchError((_) {});
          Api.markMessageRead('${m['id']}').catchError((_) {});
        }
      }
      _scrollDown();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _loadChatTheme() async {
    try {
      final t = await Api.chatTheme(widget.userId);
      if (!mounted) return;
      setState(() => _chatTheme = '${t['background'] ?? 'gradient:midnight'}');
    } catch (_) {}
  }

  Future<void> _chooseChatTheme() async {
    final choices = <Map<String,String>>[
      {'id':'gradient:midnight','name':'ليلي','a':'#0B1020','b':'#24113F'},
      {'id':'gradient:ocean','name':'محيط','a':'#061826','b':'#0D5261'},
      {'id':'gradient:violet','name':'بنفسجي','a':'#180D2E','b':'#5B21B6'},
      {'id':'gradient:sunset','name':'غروب','a':'#32111A','b':'#7C2D12'},
      {'id':'gradient:forest','name':'غابة','a':'#071A14','b':'#14532D'},
      {'id':'gradient:love','name':'حب ❤️','a':'#3B0A2E','b':'#BE185D'},
      {'id':'gradient:friends','name':'أصدقاء ✨','a':'#052E3A','b':'#2563EB'},
      {'id':'animated:aurora','name':'سينمائي — شفق متحرك'},
      {'id':'animated:stars','name':'سينمائي — نجوم متحركة'},
      {'id':'animated:hearts','name':'سينمائي — قلوب متحركة'},
      {'id':'animated:particles','name':'سينمائي — جزيئات'},
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('خلفية المحادثة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 10),
        for (final c in choices) ListTile(
          leading: Container(width:46,height:46,decoration:BoxDecoration(
            gradient: c['id']!.contains(':') && (c['id']!.startsWith('gradient')) ? LinearGradient(colors:[_hex(c['a']!),_hex(c['b']!)]) : null,
            color: c['id']!.startsWith('solid') ? _hex(c['a']!) : SN.bg3,
            borderRadius: BorderRadius.circular(14)), child: Icon(c['id']!.startsWith('animated') ? Icons.auto_awesome_rounded : Icons.wallpaper_rounded, color: Colors.white70)),
          title: Text(c['name']!),
          trailing: _chatTheme==c['id'] ? Icon(Icons.check_circle_rounded,color:SN.violet) : null,
          onTap: () => Navigator.pop(ctx,c['id']),
        ),
        ListTile(
          leading: Icon(Icons.add_photo_alternate_rounded, color: SN.violet),
          title: const Text('اختيار صورة من الهاتف'),
          subtitle: const Text('تُحفظ كخلفية لهذه المحادثة فقط'),
          onTap: () => Navigator.pop(ctx, 'PICK_IMAGE'),
        ),
      ])),
    );
    if (picked == null) return;
    String background = picked;
    if (picked == 'PICK_IMAGE') {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
      if (file == null) return;
      try {
        final up = await Api.uploadMedia(file.path);
        background = 'image:${up['url']}';
      } catch (e) { if (mounted) toast(context, 'تعذّر رفع صورة الخلفية'); return; }
    }
    try {
      await Api.saveChatTheme(widget.userId, background:background);
      if (mounted) setState(() => _chatTheme=background);
    } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ','')); }
  }

  static Color _hex(String value) {
    final v=value.replaceAll('#','');
    return Color(int.parse('FF$v',radix:16));
  }

  BoxDecoration _chatBackground() {
    if (_chatTheme.startsWith('image:')) return BoxDecoration(color: Colors.black);
    if (_chatTheme.startsWith('solid:')) return BoxDecoration(color:_hex(_chatTheme.substring(6)));
    final map={
      'gradient:midnight':[const Color(0xFF0B1020),const Color(0xFF24113F)],
      'gradient:ocean':[const Color(0xFF061826),const Color(0xFF0D5261)],
      'gradient:violet':[const Color(0xFF180D2E),const Color(0xFF5B21B6)],
      'gradient:sunset':[const Color(0xFF32111A),const Color(0xFF7C2D12)],
      'gradient:forest':[const Color(0xFF071A14),const Color(0xFF14532D)],
      'gradient:love':[const Color(0xFF3B0A2E),const Color(0xFFBE185D)],
      'gradient:friends':[const Color(0xFF052E3A),const Color(0xFF2563EB)],
      'animated:aurora':[const Color(0xFF071A2B),const Color(0xFF4C1D95)],
      'animated:stars':[const Color(0xFF030712),const Color(0xFF172554)],
      'animated:hearts':[const Color(0xFF3B0A2E),const Color(0xFF831843)],
      'animated:particles':[const Color(0xFF111827),const Color(0xFF0F766E)],
    }[_chatTheme] ?? [SN.bg1,SN.bg2];
    return BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:map!));
  }

  Widget _chatBackgroundWidget() {
    if (_chatTheme.startsWith('image:')) {
      return Positioned.fill(child: Image.network(_chatTheme.substring(6), fit: BoxFit.cover, errorBuilder: (_,__,___)=>Container(decoration:_chatBackground())));
    }
    if (_chatTheme.startsWith('animated:')) {
      final mode=_chatTheme.substring(9);
      return Positioned.fill(child: AnimatedBuilder(animation:_chatFxController,builder:(context,child)=>DecoratedBox(decoration:_chatBackground(),child:CustomPaint(painter:_ChatFxPainter(mode,_chatFxController.value)))));
    }
    return Positioned.fill(child: DecoratedBox(decoration:_chatBackground()));
  }

  void _chatSettings() {
    showModalBottomSheet<void>(
      context: context, backgroundColor: SN.bg1, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(L10n.t('إعدادات المحادثة'), style: TextStyle(fontWeight: FontWeight.w900))),
        ListTile(leading: Icon(Icons.palette_outlined, color: SN.violet), title: Text('تغيير خلفية المحادثة'), subtitle: Text('خلفية مستقلة لهذه المحادثة فقط'), onTap: () { Navigator.pop(ctx); _chooseChatTheme(); }),
        SwitchListTile(value: muted, onChanged: (v) { setState(() => muted = v); Navigator.pop(ctx); }, title: Text(muted ? 'إلغاء الكتم' : 'كتم الإشعارات'), secondary: Icon(muted ? Icons.notifications_off : Icons.notifications_none)),
        ListTile(leading: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded, color: SN.red), title: Text(blocked ? 'إلغاء الحظر' : 'حظر المستخدم'), onTap: () { setState(() => blocked = !blocked); Navigator.pop(ctx); toast(context, blocked ? 'تم حظر المستخدم محليًا' : 'تم إلغاء الحظر'); }),
        ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('مسح واجهة المحادثة'), onTap: () { setState(() => msgs.clear()); Navigator.pop(ctx); }),
      ])),
    );
  }

  Future<void> _secretSettings() async {
    int ttl = secretTtl;
    bool vanish = selfDestruct;
    int views = viewLimit;
    final result = await showModalBottomSheet<Map<String,dynamic>>(
      context: context, backgroundColor: SN.bg1, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.shield_rounded, color: SN.violet), title: Text(L10n.t('الوضع السري'), style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(L10n.t('محادثة مؤقتة مع حماية إضافية للخصوصية'))),
        SwitchListTile(value: secretMode, onChanged: (v) => setSheet(() => secretMode = v), title: const Text('تفعيل الوضع السري'), secondary: const Icon(Icons.visibility_off_rounded)),
        SwitchListTile(value: vanish, onChanged: (v) => setSheet(() => vanish = v), title: const Text('حذف الرسالة بعد قراءتها'), secondary: const Icon(Icons.auto_delete_rounded)),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('مدة الرسائل السرية'),
          subtitle: Text(ttl == 10 ? '10 دقائق' : ttl == 60 ? 'ساعة' : ttl == 1440 ? 'يوم' : '$ttl دقيقة'),
          onTap: () async {
            final v = await showDialog<int>(
              context: ctx,
              builder: (_) => SimpleDialog(
                title: const Text('اختر المدة'),
                children: [10, 60, 1440]
                    .map(
                      (x) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, x),
                        child: Text(x == 10 ? '10 دقائق' : x == 60 ? 'ساعة' : 'يوم'),
                      ),
                    )
                    .toList(),
              ),
            );
            if (v != null) setSheet(() => ttl = v);
          },
        ),
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('ملاحظة الخصوصية'), subtitle: const Text('لا نعد بمنع لقطات الشاشة على كل الأجهزة. لا ترسل معلومات حساسة لمجرد وجود الوضع السري.')),
        Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, {'secret': secretMode, 'selfDestruct': vanish, 'ttl': ttl, 'views': views}), icon: const Icon(Icons.check), label: const Text('حفظ الإعدادات'))),
      ]))));
    if (result != null && mounted) { setState(() { secretMode = result['secret'] == true; selfDestruct = result['selfDestruct'] == true; secretTtl = result['ttl'] as int; viewLimit = (result['views'] ?? 0) as int; }); try { await const MethodChannel('socialnova/privacy').invokeMethod('setSecure', {'enabled': secretMode}); } catch (_) {} }
  }

  Future<void> _startCall({required bool video}) async {
    final my = '${Api.me?['id']}';
    final a = my.compareTo(widget.userId) < 0 ? my : widget.userId;
    final b = my.compareTo(widget.userId) < 0 ? widget.userId : my;
    final roomName = 'call_${a}_$b';
    SocketService.i.sendCallInvite(to: widget.userId, roomName: roomName, video: video, name: '${Api.me?['username'] ?? 'مستخدم'}', avatar: '${Api.me?['avatarUrl'] ?? ''}');
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallRoomPage(title: widget.name, roomName: roomName, videoCall: video)));
  }

  void _showIncomingCall(Map<String, dynamic> m) {
    _callDialogOpen = true;
    final video = m['video'] == true;
    final roomName = '${m['roomName'] ?? ''}';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(video ? 'مكالمة فيديو واردة' : 'مكالمة صوتية واردة'),
        content: Text('لديك اتصال من ${widget.name}'),
        actions: [
          TextButton(onPressed: () { SocketService.i.sendCallReject('${m['fromId']}'); Navigator.pop(ctx); }, child: const Text('رفض')),
          FilledButton(onPressed: () { SocketService.i.sendCallAccept('${m['fromId']}', roomName); Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => CallRoomPage(title: widget.name, roomName: roomName, videoCall: video))); }, child: const Text('قبول')),
        ],
      ),
    ).whenComplete(() => _callDialogOpen = false);
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    ctrl.clear();
    try {
      // REST write guarantees persistence; Socket.IO mirrors it in realtime.
      final result = await Api.sendMessage(widget.userId, text, secret: secretMode, selfDestruct: selfDestruct, ttlMinutes: secretTtl, viewLimit: viewLimit);
      await _load();
    } catch (e) {
      if (!mounted) return;
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _sendMedia({required ImageSource source}) async {
    if (sending) return;
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 88, maxWidth: 1800);
      if (file == null) return;
      setState(() => sending = true);
      final up = await Api.uploadMedia(file.path);
      await Api.sendMessage(widget.userId, '[image]${up['url']}', secret: secretMode, selfDestruct: selfDestruct, ttlMinutes: secretTtl, viewLimit: viewLimit);
      await _load();
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _sendVideo() async {
    if (sending) return;
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
      if (file == null) return;
      setState(() => sending = true);
      final up = await Api.uploadMedia(file.path);
      await Api.sendMessage(widget.userId, '[video]${up['url']}', secret: secretMode, selfDestruct: selfDestruct, ttlMinutes: secretTtl, viewLimit: viewLimit);
      await _load();
    } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> _toggleRecording() async {
    try {
      if (recording) {
        final path = await _recorder.stop();
        if (mounted) setState(() => recording = false);
        if (path == null || path.isEmpty) return;
        setState(() => sending = true);
        final up = await Api.uploadMedia(path);
        await Api.sendMessage(widget.userId, '[audio]${up['url']}', secret: secretMode, selfDestruct: selfDestruct, ttlMinutes: secretTtl, viewLimit: viewLimit);
        await _load();
      } else {
        if (!await _recorder.hasPermission()) {
          if (mounted) toast(context, 'اسمح للتطبيق باستخدام الميكروفون لإرسال رسالة صوتية.');
          return;
        }
        final path = '${Directory.systemTemp.path}/sn_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000), path: path);
        if (mounted) setState(() => recording = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { recording = false; sending = false; });
        toast(context, 'تعذّر تسجيل الرسالة الصوتية.');
      }
    } finally {
      if (mounted && !recording) setState(() => sending = false);
    }
  }

  void _emojiPicker() {
    const emojis = ['😀','😂','😍','🥰','😎','😭','😡','👍','❤️','🔥','🎉','👏','✨','💯','🥳','🤍','🙏','😅','🤔','😴','🎁','⭐','🚀','👑'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(18),
          shrinkWrap: true,
          crossAxisCount: 6,
          children: [for (final e in emojis) InkWell(onTap: () { ctrl.text += e; ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length); Navigator.pop(ctx); setState(() {}); }, child: Center(child: Text(e, style: const TextStyle(fontSize: 28))))],
        ),
      ),
    );
  }

  void _moreActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: Icon(Icons.photo_library_outlined, color: SN.violet), title: Text('إرسال صورة من المعرض'), onTap: () { Navigator.pop(ctx); _sendMedia(source: ImageSource.gallery); }),
            ListTile(leading: Icon(Icons.camera_alt_outlined, color: SN.violet), title: Text('التقاط صورة'), onTap: () { Navigator.pop(ctx); _sendMedia(source: ImageSource.camera); }),
            ListTile(leading: Icon(Icons.videocam_outlined, color: SN.violet), title: Text('إرسال فيديو'), onTap: () { Navigator.pop(ctx); _sendVideo(); }),
            ListTile(leading: Icon(Icons.card_giftcard_outlined, color: SN.cyan), title: Text('إرسال هدية'), onTap: () { Navigator.pop(ctx); showGiftPicker(context, receiverId: widget.userId, receiverName: widget.name, contextType: 'MESSAGE'); }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try { const MethodChannel('socialnova/privacy').invokeMethod('setSecure', {'enabled': false}); } catch (_) {}
    _sub?.cancel();
    _deliveredSub?.cancel();
    _readSub?.cancel();
    _requestAcceptedSub?.cancel();
    _callSub?.cancel();
    ctrl.dispose();
    scroll.dispose();
    _recorder.dispose();
    _chatFxController.dispose();
    // Keep a Messenger-style chat head after leaving the conversation.
    ChatBubbleManager.i.showMessenger(onOpen: () {
      final nav = _navigator;
      if (nav != null && nav.mounted) {
        nav.push(MaterialPageRoute(builder: (_) => const MessengerPage()));
      }
    });
    super.dispose();
  }

  Widget _storyMessage(String body, bool mine) {
    final isHeart = body.startsWith('[story_reaction]');
    final text = isHeart ? '❤️ أعجب بقصتك' : '💬 رد على قصتك: ${body.substring('[story_reply]'.length)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .12) : SN.bg3, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isHeart ? Icons.favorite : Icons.reply_rounded, color: isHeart ? Colors.redAccent : SN.violet, size: 22),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(color: mine ? Colors.white : SN.textPri, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Future<void> _messageMenu(Map<String,dynamic> m, bool mine) async {
    final id='${m['id']??''}';
    if (m['request'] == true) {
      if (mounted) toast(context, 'طلب المراسلة قيد الانتظار حتى يقبله الطرف الآخر.');
      return;
    }
    final choice=await showModalBottomSheet<String>(context:context,backgroundColor:SN.bg1,showDragHandle:true,builder:(ctx)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.emoji_emotions_outlined),title:const Text('تفاعل سريع'),onTap:()=>Navigator.pop(ctx,'react')),
      if(!secretMode) ListTile(leading:const Icon(Icons.forward_rounded),title:const Text('إعادة توجيه'),onTap:()=>Navigator.pop(ctx,'forward')),
      ListTile(leading:const Icon(Icons.delete_outline),title:const Text('حذف لدي فقط'),onTap:()=>Navigator.pop(ctx,'mine')),
      if(mine) ListTile(leading:const Icon(Icons.delete_sweep_outlined),title:const Text('حذف للجميع'),onTap:()=>Navigator.pop(ctx,'all')),
    ])));
    if(choice=='mine'||choice=='all'){try{await Api.deleteMessage(id,forEveryone:choice=='all');await _load();}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}}
    if(choice=='react'){ctrl.text='❤️';setState((){});}
    if(choice=='forward'){final conv=await Api.conversations();if(!mounted)return;final target=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(ctx)=>ListView(children:[for(final c in conv) ListTile(title:Text('${c['displayName']??c['username']??''}'),onTap:()=>Navigator.pop(ctx,'${c['id']??''}'))]));if(target!=null&&target.isNotEmpty){await Api.sendMessage(target,'${m['body']??''}');}}
  }

  String _formatTime(String raw) { final d=DateTime.tryParse(raw)?.toLocal(); if(d==null)return ''; final h=d.hour.toString().padLeft(2,'0'); final m=d.minute.toString().padLeft(2,'0'); return '$h:$m'; }

  Widget _messageStatus(Map<String,dynamic> m, bool mine) {
    if (!mine) return const SizedBox.shrink();
    final read=m['read']==true || m['readAt']!=null;
    final delivered=m['deliveredAt']!=null;
    final icon=read ? Icons.done_all_rounded : delivered ? Icons.done_all_rounded : Icons.check_rounded;
    final color=read ? Colors.lightBlueAccent : Colors.white70;
    return Padding(padding:const EdgeInsets.only(left:4),child:Icon(icon,size:15,color:color));
  }

  Widget _messageContent(String body, bool mine, String messageId) {
    if (body.startsWith('[story_reaction]') || body.startsWith('[story_reply]')) return _storyMessage(body, mine);
    if (body.startsWith('[group_share]')) {
      final parts = body.substring('[group_share]'.length).split('|');
      final id = parts.isNotEmpty ? parts[0] : '';
      final name = parts.length > 1 ? parts[1] : 'مجموعة';
      return InkWell(
        onTap: id.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupId: id, name: name))),
        child: Container(
          width: 240, padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha:.12) : SN.bg3, borderRadius: BorderRadius.circular(17)),
          child: Row(children: [
            Container(width:46,height:46,decoration:BoxDecoration(gradient:SN.grad,borderRadius:BorderRadius.circular(14)),child:Icon(Icons.groups_rounded,color:Colors.white)),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('مشاركة مجموعة',style:TextStyle(fontSize:11,color:SN.textMut)),
              Text(name,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
              const SizedBox(height:4),
              Text('اضغط للفتح',style:TextStyle(fontSize:11,color:SN.violet)),
            ])),
          ]),
        ),
      );
    }
    if (body.startsWith('[live_share]')) {
      final parts = body.substring('[live_share]'.length).split('|');
      final room = parts.isNotEmpty ? parts[0] : '';
      final title = parts.length > 1 ? parts[1] : 'بث مباشر';
      return InkWell(
        onTap: room.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomPage(title:title, roomName:room))),
        child: Container(width:240,padding:EdgeInsets.all(13),decoration:BoxDecoration(color:mine?Colors.white.withValues(alpha:.12):SN.bg3,borderRadius:BorderRadius.circular(17)),child:Row(children:[
          Container(width:46,height:46,decoration:BoxDecoration(color:SN.red,borderRadius:BorderRadius.circular(14)),child:Icon(Icons.sensors_rounded,color:Colors.white)),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('مشاركة Live',style:TextStyle(fontSize:11,color:SN.textMut)),Text(title,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:4),Text('اضغط للمشاهدة',style:TextStyle(fontSize:11,color:SN.red))])),
        ])),
      );
    }
    if (body.startsWith('[image]')) {
      final url = body.substring(7);
      if(messageId.isNotEmpty && _viewedMediaMessages.add(messageId)) Future.microtask(()=>Api.viewMessage(messageId)); return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(url, width: 220, height: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Padding(padding: EdgeInsets.all(10), child: Text(L10n.t('تعذّر تحميل الصورة')))));
    }
    if (body.startsWith('[video]')) { final url=body.substring(7); if(messageId.isNotEmpty && _viewedMediaMessages.add(messageId)) Future.microtask(()=>Api.viewMessage(messageId)); return VideoBox(url:url,autoPlay:false,height:220,radius:14); }
    if (body.startsWith('[audio]')) {
      final url = body.substring(7);
      return InkWell(
        onTap: () async { final uri = Uri.tryParse(url); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); },
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_circle_fill_rounded, color: mine ? Colors.white : SN.violet, size: 34), SizedBox(width: 8), Text(L10n.t('رسالة صوتية'), style: TextStyle(color: mine ? Colors.white : SN.textPri, fontWeight: FontWeight.w700))]),
      );
    }
    return mentionText(context, body, style: TextStyle(height: 1.5, fontSize: 14, color: mine ? Colors.white : SN.textPri));
  }

  @override
  Widget build(BuildContext context) {
    final myId = '${Api.me?['id']}';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openProfile(context, widget.userId),
          child: Row(
            children: [
              SNav(url: widget.avatar, name: widget.name, size: 38, ring: true),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        actions: [
          IconButton(tooltip: 'مكالمة صوتية', onPressed: () => _startCall(video: false), icon: const Icon(Icons.call_outlined)),
          IconButton(tooltip: 'مكالمة فيديو', onPressed: () => _startCall(video: true), icon: const Icon(Icons.videocam_outlined)),
          IconButton(tooltip: 'الوضع السري', onPressed: _secretSettings, icon: Icon(secretMode ? Icons.shield_rounded : Icons.shield_outlined, color: secretMode ? SN.violet : null)),
          IconButton(tooltip: 'إعدادات المحادثة', onPressed: _chatSettings, icon: const Icon(Icons.more_vert_rounded)),
          Padding(padding: EdgeInsets.only(right: 6), child: CircleAvatar(radius: 18, backgroundColor: SN.bg3, child: IconButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: 20)))),
        ],
      ),
      body: Stack(children:[
        _chatBackgroundWidget(),
        Positioned(top:-80,right:-50,child:IgnorePointer(child:Container(width:220,height:220,decoration:BoxDecoration(shape:BoxShape.circle,color:SN.violet.withValues(alpha:.10))))),
        Positioned(bottom:120,left:-80,child:IgnorePointer(child:Container(width:240,height:240,decoration:BoxDecoration(shape:BoxShape.circle,color:SN.indigo.withValues(alpha:.10))))),
        Column(
          children: [
          Expanded(
            child: loading
                ? const LoadingBox()
                : msgs.isEmpty
                    ? const EmptyState(text: 'ابدأ المحادثة بإرسال رسالة 👋', icon: Icons.chat_bubble_outline)
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.all(14),
                        itemCount: msgs.length,
                        itemBuilder: (c, i) {
                          final mine = '${msgs[i]['senderId']}' == myId;
                          return Align(
                            alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                            child: GestureDetector(
                              onLongPress: () => _messageMenu(Map<String,dynamic>.from(msgs[i] as Map), mine),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .74),
                                decoration: BoxDecoration(
                                  gradient: mine ? SN.grad : null,
                                  color: mine ? null : SN.bg2,
                                  borderRadius: BorderRadius.circular(18),
                                  border: mine ? null : Border.all(color: SN.strokeSoft),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (msgs[i]['secret'] == true) Padding(padding: EdgeInsets.only(bottom: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shield_rounded, size: 13, color: mine ? Colors.white70 : SN.violet), SizedBox(width: 4), Text(L10n.t('سري • مؤقت'), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : SN.textMut, fontWeight: FontWeight.w700))])),
                                  if (msgs[i]['request'] == true) Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.schedule_rounded, size: 14, color: mine ? Colors.white70 : SN.gold),
                                      const SizedBox(width: 4),
                                      Text(L10n.t('طلب مراسلة • بانتظار القبول'), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : SN.gold, fontWeight: FontWeight.w800)),
                                    ]),
                                  ),
                                  _messageContent('${msgs[i]['body'] ?? ''}', mine, '${msgs[i]['id'] ?? ''}'),
                                  const SizedBox(height: 4),
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text(_formatTime('${msgs[i]['createdAt'] ?? ''}'), style: TextStyle(fontSize: 9, color: mine ? Colors.white70 : SN.textMut)),
                                    _messageStatus(Map<String,dynamic>.from(msgs[i] as Map), mine),
                                  ]),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (secretMode) Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3), child: Row(children: [Icon(Icons.shield_rounded, size: 15, color: SN.violet), SizedBox(width: 5), Text('الوضع السري مفعّل • ${secretTtl == 1440 ? '24 ساعة' : '$secretTtl دقيقة'}', style: TextStyle(fontSize: 11, color: SN.violet, fontWeight: FontWeight.w800)), Spacer(), if(selfDestruct) Icon(Icons.auto_delete_rounded, size: 15, color: SN.violet)])),
          Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F0F7),
              borderRadius: BorderRadius.circular(34),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(gradient: SN.grad, shape: BoxShape.circle),
                    child: IconButton(onPressed: recording ? _toggleRecording : _send, icon: Icon(recording ? Icons.stop_rounded : Icons.send_rounded, color: Colors.white, size: 27)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: recording
                        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(L10n.t('جاري تسجيل رسالة صوتية… اضغط الميكروفون للإرسال'), style: const TextStyle(color: Colors.black54, fontSize: 13)))
                        : TextField(
                            controller: ctrl,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(hintText: 'مراسلة...', border: InputBorder.none, filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12)),
                          ),
                  ),
                  IconButton(onPressed: _toggleRecording, icon: Icon(recording ? Icons.stop_circle_outlined : Icons.mic_none_rounded, color: recording ? SN.pink : Colors.black, size: 32)),
                  IconButton(onPressed: () => _sendMedia(source: ImageSource.gallery), icon: const Icon(Icons.image_outlined, color: Colors.black, size: 30)),
                  IconButton(onPressed: _emojiPicker, icon: const Icon(Icons.sticky_note_2_outlined, color: Colors.black, size: 29)),
                  IconButton(onPressed: _moreActions, icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 32)),
                ],
              ),
            ),
          ),
          ],
        ),
      ],),
    );
  }
}

class _ChatFxPainter extends CustomPainter {
  final String mode;
  final double t;
  _ChatFxPainter(this.mode,this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final p=Paint()..style=PaintingStyle.fill;
    final r=math.Random(7);
    if(mode=='hearts') {
      p.color=Colors.pinkAccent.withValues(alpha:.18);
      for(int i=0;i<18;i++){final x=(r.nextDouble()*size.width + math.sin(t*math.pi*2+i)*28)%size.width;final y=((r.nextDouble()+t*0.12+i*.037)%1)*size.height;canvas.drawCircle(Offset(x,y),6+r.nextDouble()*10,p);}
    } else if(mode=='stars') {
      p.color=Colors.white.withValues(alpha:.22);
      for(int i=0;i<45;i++){final x=r.nextDouble()*size.width;final y=r.nextDouble()*size.height;final a=.3+.7*math.sin((t+i*.13)*math.pi*2).abs();p.color=Colors.white.withValues(alpha:a*.35);canvas.drawCircle(Offset(x,y),1+r.nextDouble()*2,p);}
    } else {
      p.color=Colors.white.withValues(alpha:.10);
      for(int i=0;i<28;i++){final x=(r.nextDouble()*size.width + math.sin(t*math.pi*2+i)*45)%size.width;final y=(r.nextDouble()*size.height + math.cos(t*math.pi*2+i)*25)%size.height;canvas.drawCircle(Offset(x,y),4+r.nextDouble()*14,p);}
    }
  }
  @override bool shouldRepaint(covariant _ChatFxPainter oldDelegate)=>oldDelegate.t!=t||oldDelegate.mode!=mode;
}

// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<List<dynamic>> _future;
  final search = TextEditingController();
  String filter = 'الكل';

  @override
  void initState() {
    super.initState();
    _future = Api.groups();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final rules = TextEditingController();
    String privacy = 'PUBLIC';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء مجموعة احترافية'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المجموعة', prefixIcon: Icon(Icons.groups_rounded))),
            const SizedBox(height: 12),
            TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف المجموعة', prefixIcon: Icon(Icons.info_outline_rounded))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: privacy, decoration: InputDecoration(labelText: 'الخصوصية', prefixIcon: Icon(Icons.lock_outline_rounded)), items: [DropdownMenuItem(value: 'PUBLIC', child: Text(L10n.t('عامة — يمكن للجميع الانضمام'))), DropdownMenuItem(value: 'PRIVATE', child: Text(L10n.t('خاصة — للأعضاء فقط')))], onChanged: (v) => privacy = v ?? 'PUBLIC'),
            const SizedBox(height: 10),
            TextField(controller: rules, maxLines: 3, decoration: const InputDecoration(labelText: 'قواعد المجموعة', hintText: 'مثال: الاحترام وعدم الإزعاج')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.check_rounded), label: const Text('إنشاء')),
        ],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      try {
        await Api.createGroup(name.text.trim(), desc.text.trim(), privacy: privacy, rules: rules.text.trim());
        if (!mounted) return;
        setState(() => _future = Api.groups());
        toast(context, 'تم إنشاء المجموعة');
      } catch (e) {
        if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
    name.dispose(); desc.dispose(); rules.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SN.indigo,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('مجموعة', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(children: [
          const SNHeader(title: 'المجموعات'),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث عن مجموعة...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
              for (final f in const ['الكل', 'العامة', 'الخاصة', 'الأكثر نشاطاً'])
                Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f))),
            ],),
          ),
          Expanded(
            child: RefreshIndicator(
              color: SN.violet,
              onRefresh: () async => setState(() => _future = Api.groups()),
              child: FutureBuilder<List<dynamic>>(
                future: _future,
                builder: (c, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
                  if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
                  final q = search.text.trim().toLowerCase();
                  var groups = (snap.data ?? []).whereType<Map>().where((g) {
                    final name = '${g['name'] ?? ''}'.toLowerCase();
                    final desc = '${g['description'] ?? ''}'.toLowerCase();
                    final privacy = '${g['privacy'] ?? 'PUBLIC'}';
                    if (q.isNotEmpty && !name.contains(q) && !desc.contains(q)) return false;
                    if (filter == 'العامة' && privacy != 'PUBLIC') return false;
                    if (filter == 'الخاصة' && privacy != 'PRIVATE') return false;
                    return true;
                  }).toList();
                  if (filter == 'الأكثر نشاطاً') {
                    groups.sort((a,b) { final bm = int.tryParse('${((b['_count'] ?? {}) as Map)['members'] ?? 0}') ?? 0; final am = int.tryParse('${((a['_count'] ?? {}) as Map)['members'] ?? 0}') ?? 0; return bm.compareTo(am); });
                  }
                  if (groups.isEmpty) return ListView(children: const [SizedBox(height: 90), EmptyState(text: 'لا توجد مجموعات مطابقة\nجرّب بحثاً آخر أو أنشئ مجموعة جديدة', icon: Icons.groups_outlined)]);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: SN.violet.withOpacity(.22), blurRadius: 22)]),
                        child: Row(children: [
                          const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.forum_rounded, color: Colors.white)),
                          SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(L10n.t('مجتمعات SocialNova'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 4), Text(L10n.t('اكتشف مجموعات جديدة، شارك، وتواصل مع الأعضاء.'), style: TextStyle(color: Colors.white70, fontSize: 12))])),
                        ]),
                      ),
                      for (final g in groups)
                        _GroupListCard(group: Map<String,dynamic>.from(g), onOpen: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupId: '${g['id']}', name: '${g['name']}')))),
                    ],
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GroupListCard extends StatelessWidget {
  const _GroupListCard({required this.group, required this.onOpen});
  final Map<String,dynamic> group;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final members = ((group['_count'] ?? {}) as Map)['members'] ?? 0;
    final private = group['privacy'] == 'PRIVATE';
    final avatar = '${group['avatarUrl'] ?? ''}';
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22), onTap: onOpen,
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: SN.grad, image: avatar.isEmpty ? null : DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)), child: avatar.isEmpty ? Icon(Icons.groups_rounded, color: Colors.white, size: 28) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${group['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), Icon(private ? Icons.lock_rounded : Icons.public_rounded, size: 16, color: SN.textMut)]),
            const SizedBox(height: 5),
            Text('${members} عضو • ${private ? 'خاصة' : 'عامة'}', style: TextStyle(color: SN.textMut, fontSize: 12)),
            if ('${group['description'] ?? ''}'.isNotEmpty) ...[SizedBox(height: 3), Text('${group['description']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: SN.textSec, fontSize: 12))],
          ])),
          Icon(Icons.chevron_left_rounded, color: SN.textMut),
        ])),
      ),
    );
  }
}

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key, required this.groupId, required this.name});
  final String groupId;
  final String name;
  @override State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> msgs = [];
  Map<String,dynamic> groupInfo = {};
  bool loading = true, joined = true, muted = false;
  bool compactMode = false;

  @override void initState(){super.initState(); _load();}

  Future<void> _load() async {
    try {
      final g = await Api.group(widget.groupId);
      groupInfo = Map<String,dynamic>.from(g);
      joined = g['joined'] == true;
      if (joined) { final m = await Api.groupMessages(widget.groupId); msgs = m.map((e)=>Map<String,dynamic>.from(e as Map)).toList(); }
      if (!mounted) return;
      setState(() => loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) { if(scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent); });
    } catch(e){if(mounted){setState(()=>loading=false);toast(context,e.toString().replaceFirst('Exception: ',''));}}
  }

  Future<void> _toggleJoin() async { try { await Api.joinGroup(widget.groupId); await _load(); } catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));} }

  Future<void> _editGroup() async {
    final name=TextEditingController(text: '${groupInfo['name'] ?? widget.name}');
    final desc=TextEditingController(text: '${groupInfo['description'] ?? ''}');
    final rules=TextEditingController(text: '${groupInfo['rules'] ?? ''}');
    String privacy='${groupInfo['privacy'] ?? 'PUBLIC'}';
    final ok=await showDialog<bool>(context: context,builder:(ctx)=>AlertDialog(title:Text('إعدادات المجموعة'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:InputDecoration(labelText:'اسم المجموعة')),SizedBox(height:10),TextField(controller:desc,maxLines:3,decoration:InputDecoration(labelText:'الوصف')),SizedBox(height:10),DropdownButtonFormField<String>(value:privacy,decoration:InputDecoration(labelText:'الخصوصية'),items:[DropdownMenuItem(value:'PUBLIC',child:Text(L10n.t('عامة'))),DropdownMenuItem(value:'PRIVATE',child:Text(L10n.t('خاصة')))],onChanged:(v)=>privacy=v??privacy),SizedBox(height:10),TextField(controller:rules,maxLines:4,decoration:InputDecoration(labelText:'قواعد المجموعة'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('حفظ'))]));
    if(ok==true && name.text.trim().length>=2){try{await Api.updateGroup(widget.groupId,name.text.trim(),desc.text.trim(),privacy:privacy,rules:rules.text.trim());await _load();if(mounted)toast(context,'تم حفظ إعدادات المجموعة');}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}}
    name.dispose();desc.dispose();rules.dispose();
  }

  void _showGroupSettings() {
    showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,backgroundColor:SN.bg1,shape:RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28))),builder:(ctx)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,4,16,20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Container(width:48,height:48,decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:SN.grad),child:Icon(Icons.groups_rounded,color:Colors.white)),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${groupInfo['name']??widget.name}',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),Text('${((groupInfo['_count']??{}) as Map)['members']??0} عضو',style:TextStyle(color:SN.textMut,fontSize:12))]))]),
      const SizedBox(height:14),
      ListTile(leading:Icon(Icons.share_rounded,color:SN.violet),title:Text('مشاركة المجموعة في المحادثة'),subtitle:Text('أرسل بطاقة المجموعة إلى أصدقائك'),onTap:(){Navigator.pop(ctx);shareSocialItemToChats(context,title:'مشاركة المجموعة',body:'[group_share]${widget.groupId}|${groupInfo['name'] ?? widget.name}',icon:Icons.groups_rounded);}),
      ListTile(leading:const Icon(Icons.notifications_none_rounded),title:const Text('إشعارات المجموعة'),subtitle:Text(muted?'مكتومة':'مفعلة'),trailing:Switch(value:!muted,onChanged:(v){setState(()=>muted=!v);Navigator.pop(ctx);}),),
      ListTile(leading:const Icon(Icons.image_outlined),title:const Text('الوسائط والملفات'),subtitle:const Text('صور وفيديوهات وملفات المجموعة'),onTap:()=>toast(context,'قسم الوسائط جاهز للربط مع التخزين')), 
      ListTile(leading:const Icon(Icons.rule_rounded),title:const Text('قواعد المجموعة'),subtitle:Text('${groupInfo['rules']??''}'.isEmpty?'لم يحدد المالك قواعد بعد':'عرض قواعد المجموعة'),onTap:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('قواعد المجموعة'),content:Text('${groupInfo['rules']??''}'.isEmpty?'لا توجد قواعد محددة.':'${groupInfo['rules']}'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق'))]))),
      ListTile(leading:const Icon(Icons.tune_rounded),title:const Text('إدارة المجموعة'),subtitle:const Text('الاسم والوصف والخصوصية'),onTap:(){Navigator.pop(ctx);_editGroup();}),
      ListTile(leading:const Icon(Icons.view_agenda_outlined),title:const Text('مظهر المحادثة'),subtitle:Text(compactMode?'الوضع المضغوط':'الوضع العادي'),trailing:Switch(value:compactMode,onChanged:(v){setState(()=>compactMode=v);Navigator.pop(ctx);}),),
      ListTile(leading:Icon(joined?Icons.exit_to_app_rounded:Icons.group_add_rounded,color:joined?Colors.redAccent:SN.violet),title:Text(joined?'مغادرة المجموعة':'الانضمام للمجموعة',style:TextStyle(color:joined?Colors.redAccent:SN.textPri)),onTap:(){Navigator.pop(ctx);_toggleJoin();}),
    ]))));
  }

  Future<void> _send() async {final t=ctrl.text.trim();if(t.isEmpty||!joined)return;ctrl.clear();try{await Api.sendGroupMessage(widget.groupId,t);await _load();}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}}

  @override void dispose(){ctrl.dispose();scroll.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    final myId='${Api.me?['id']}';
    return Scaffold(
      appBar: AppBar(backgroundColor:SN.bg1,titleSpacing:4,title:InkWell(onTap:_showGroupSettings,child:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),gradient:SN.grad),child:Icon(Icons.groups_rounded,color:Colors.white)),SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${groupInfo['name']??widget.name}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:15,fontWeight:FontWeight.w800)),Text('${((groupInfo['_count']??{}) as Map)['members']??0} عضو',style:TextStyle(fontSize:10,color:SN.textMut))]))])),actions:[IconButton(tooltip:'بحث',onPressed:()=>toast(context,'بحث الرسائل سيكون متاحاً قريباً'),icon:Icon(Icons.search_rounded)),IconButton(tooltip:'إعدادات المجموعة',onPressed:_showGroupSettings,icon:Icon(Icons.more_vert_rounded))]),
      body:loading?const LoadingBox():Column(children:[
        if(!joined) Container(margin:EdgeInsets.all(12),padding:EdgeInsets.all(14),decoration:BoxDecoration(gradient:SN.grad,borderRadius:BorderRadius.circular(18)),child:Row(children:[Expanded(child:Text(L10n.t('هذه المجموعة خاصة بك. انضم لرؤية المحادثة.'),style:TextStyle(fontWeight:FontWeight.w700))),FilledButton(onPressed:_toggleJoin,child:Text('انضمام'))])),
        Expanded(child:msgs.isEmpty?EmptyState(text:'لا توجد رسائل بعد\nابدأ أول محادثة في المجموعة',icon:Icons.forum_outlined):ListView.builder(controller:scroll,padding:EdgeInsets.fromLTRB(14,12,14,18),itemCount:msgs.length,itemBuilder:(c,i){final mine='${msgs[i]['senderId']}'==myId;final sender=Map<String,dynamic>.from((msgs[i]['sender']??{}) as Map);return Align(alignment:mine?Alignment.centerLeft:Alignment.centerRight,child:Column(crossAxisAlignment:mine?CrossAxisAlignment.end:CrossAxisAlignment.start,children:[if(!mine)Padding(padding:EdgeInsets.only(bottom:2,right:8),child:Text('${sender['displayName']??sender['username']??''}',style:TextStyle(color:SN.textMut,fontSize:11,fontWeight:FontWeight.w600))),Container(margin:EdgeInsets.symmetric(vertical:compactMode?2:5),padding:EdgeInsets.symmetric(horizontal:compactMode?11:14,vertical:compactMode?7:10),constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*.78),decoration:BoxDecoration(gradient:mine?SN.grad:null,color:mine?null:SN.bg2,borderRadius:BorderRadius.only(topLeft:Radius.circular(18),topRight:Radius.circular(18),bottomLeft:Radius.circular(mine?18:4),bottomRight:Radius.circular(mine?4:18)),border:mine?null:Border.all(color:SN.strokeSoft)),child:Text('${msgs[i]['body']??''}',style:TextStyle(height:1.45,fontSize:compactMode?13:14))) ]));})),
        if(joined)Container(padding:EdgeInsets.fromLTRB(10,8,10,10),decoration:BoxDecoration(color:SN.bg1,border:Border(top:BorderSide(color:SN.strokeSoft))),child:Row(children:[IconButton(onPressed:()=>toast(context,'إرسال الصور والملفات سيكون متاحاً قريباً'),icon:Icon(Icons.add_circle_outline_rounded,color:SN.violet)),Expanded(child:TextField(controller:ctrl,onSubmitted:(_)=>_send(),textInputAction:TextInputAction.send,decoration:InputDecoration(hintText:'اكتب رسالة...',contentPadding:EdgeInsets.symmetric(horizontal:14,vertical:11))),),SizedBox(width:7),Container(decoration:BoxDecoration(gradient:SN.grad,shape:BoxShape.circle),child:IconButton(onPressed:_send,icon:Icon(Icons.send_rounded,color:Colors.white))) ])),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Live
// ---------------------------------------------------------------------------

class CallRoomPage extends StatefulWidget {
  const CallRoomPage({super.key, required this.title, required this.roomName, this.videoCall = false});
  final String title, roomName;
  final bool videoCall;
  @override State<CallRoomPage> createState() => _CallRoomPageState();
}

class _CallRoomPageState extends State<CallRoomPage> {
  final Room room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
  bool connected=false, micOn=true, cameraOn=false, speakerOn=true;
  String? error;
  @override void initState(){super.initState();room.addListener(_changed);_connect();}
  void _changed(){if(mounted)setState((){});}
  Future<void> _connect() async {
    try {
      final c=await Api.liveToken(widget.roomName); final url='${c['url']??''}'; final token='${c['token']??''}';
      if(url.isEmpty||token.isEmpty) throw Exception('LIVEKIT_NOT_CONFIGURED');
      await room.prepareConnection(url, token); await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if(widget.videoCall){try{await room.localParticipant?.setCameraEnabled(true);cameraOn=true;}catch(_){}}
      if(mounted)setState(()=>connected=true);
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
  }
  Future<void> _mic() async {try{micOn=!micOn;await room.localParticipant?.setMicrophoneEnabled(micOn);if(mounted)setState((){});}catch(_){}}
  Future<void> _camera() async {try{cameraOn=!cameraOn;await room.localParticipant?.setCameraEnabled(cameraOn);if(mounted)setState((){});}catch(_){}}
  Future<void> _speaker() async {try{speakerOn=!speakerOn;await webrtc.Helper.setSpeakerphoneOn(speakerOn);if(mounted)setState((){});}catch(_) {}}
  Future<void> _showSharedReel(String url) async {
    if(url.isEmpty || !mounted)return;
    await showDialog(context:context,builder:(_)=>Dialog(backgroundColor:Colors.black,child:AspectRatio(aspectRatio:9/16,child:VideoBox(url:url,autoPlay:true,playbackActive:true,height:620,radius:0))));
  }

  Future<void> _watchReelTogether() async {
    try {
      final rows=await Api.reels();
      if(!mounted)return;
      await showModalBottomSheet(context:context,backgroundColor:SN.bg1,showDragHandle:true,builder:(ctx)=>SizedBox(height:520,child:ListView(padding:EdgeInsets.all(12),children:[Text('مشاهدة Reels معًا',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),SizedBox(height:8),...rows.take(20).map((raw){final r=Map<String,dynamic>.from(raw as Map);final a=Map<String,dynamic>.from((r['author']??{}) as Map);return ListTile(leading:SNav(url:'${a['avatarUrl']??''}',name:'${a['displayName']??a['username']??''}',size:48),title:Text('${r['title']??r['caption']??'Reels'}',maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text('@${a['username']??''}'),trailing:Icon(Icons.play_circle_fill_rounded),onTap:()async{Navigator.pop(ctx);final url='${r['videoUrl']??''}';SocketService.i.sendLiveChat(widget.roomName,'[watch_reel]$url');if(mounted)await _showSharedReel(url);});})])));
    }catch(e){if(mounted)toast(context,'تعذّر تحميل الريلز');}
  }

  Widget _video(Participant p){
    VideoTrack? t;
    for(final pub in p.videoTrackPublications){if(pub.track is VideoTrack&&!pub.muted&&!pub.isScreenShare){t=pub.track as VideoTrack;break;}}
    return t==null?Container(color:Colors.black,alignment:Alignment.center,child:CircleAvatar(radius:42,child:Text(p.name.isNotEmpty?p.name[0].toUpperCase():'S',style:const TextStyle(fontSize:32)))):ClipRRect(borderRadius:BorderRadius.circular(18),child:VideoTrackRenderer(t));
  }
  @override Widget build(BuildContext context){
    final rem=room.remoteParticipants.values.toList(); final local=room.localParticipant;
    return Scaffold(
      backgroundColor:Colors.black,
      appBar:AppBar(backgroundColor:Colors.black,title:Text(widget.videoCall?'مكالمة فيديو':'مكالمة صوتية'),actions:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),
      body:error!=null?Center(child:Text(error!,style:const TextStyle(color:Colors.white))):Stack(children:[
        Positioned.fill(child:rem.isNotEmpty?_video(rem.first):Container(color:Colors.black,alignment:Alignment.center,child:Column(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius:55,child:Text(widget.title.isNotEmpty?widget.title[0].toUpperCase():'S',style:const TextStyle(fontSize:42))),const SizedBox(height:16),Text(connected?'في انتظار اتصال الطرف الآخر…':'جاري الاتصال…',style:const TextStyle(color:Colors.white70))]))),
        if(widget.videoCall&&local!=null)Positioned(right:16,top:16,width:120,height:170,child:ClipRRect(borderRadius:BorderRadius.circular(16),child:_video(local))),
        Positioned(left:0,right:0,bottom:25,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[CircleAvatar(radius:28,child:IconButton(onPressed:_mic,icon:Icon(micOn?Icons.mic:Icons.mic_off))),const SizedBox(width:10),CircleAvatar(radius:27,child:IconButton(onPressed:_speaker,icon:Icon(speakerOn?Icons.volume_up_rounded:Icons.volume_off_rounded))),const SizedBox(width:10),CircleAvatar(radius:27,child:IconButton(onPressed:_watchReelTogether,icon:const Icon(Icons.movie_filter_rounded))),const SizedBox(width:12),if(widget.videoCall)CircleAvatar(radius:28,child:IconButton(onPressed:_camera,icon:Icon(cameraOn?Icons.videocam:Icons.videocam_off))),const SizedBox(width:18),CircleAvatar(radius:30,backgroundColor:Colors.red,child:IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.call_end,color:Colors.white))) ])),
      ]),
    );
  }
  @override void dispose(){room.removeListener(_changed);room.disconnect();room.dispose();super.dispose();}
}

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late Future<List<dynamic>> _future;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _future = Api.live();
    _liveTimer = Timer.periodic(const Duration(seconds: 8), (_) { if (mounted) setState(() => _future = Api.live()); });
  }

  @override
  void dispose() { _liveTimer?.cancel(); super.dispose(); }

  Future<void> _start() async {
    final t = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بدء بث مباشر'),
        content: TextField(controller: t, decoration: const InputDecoration(labelText: 'عنوان البث')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
        ],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      try {
        final room = await Api.createLive(t.text.trim());
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomPage(
              title: '${room['title']}',
              roomName: '${room['roomName']}',
              roomId: '${room['id'] ?? ''}',
              hostId: '${Api.me?['id'] ?? ''}',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
    t.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SN.red,
        onPressed: _start,
        icon: const Icon(Icons.videocam, color: Colors.white),
        label: const Text('بث مباشر', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SNHeader(title: 'Live'),
            Expanded(
              child: RefreshIndicator(
                color: SN.violet,
                onRefresh: () async => setState(() => _future = Api.live()),
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
                    if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
                    final rooms = snap.data ?? [];
                    if (rooms.isEmpty) {
                      return ListView(children: const [
                        SizedBox(height: 120),
                        EmptyState(text: 'لا يوجد بث مباشر الآن.\nابدأ بثك الخاص!', icon: Icons.sensors_off_outlined),
                      ]);
                    }
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final r in rooms)
                          GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    SNav(url: '${(r as Map)['host']?['avatarUrl'] ?? ''}', name: '${r['host']?['displayName'] ?? ''}', size: 54, ring: true),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: SN.red, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('LIVE', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${r['title']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Row(children: [Expanded(child: Text('${r['host']?['displayName'] ?? ''} • ${r['viewerCount'] ?? 0} مشاهد', style: TextStyle(color: SN.textMut, fontSize: 12))), if (r['demoViewers'] == true) Text('DEMO', style: TextStyle(color: SN.cyan, fontSize: 9, fontWeight: FontWeight.w800))]),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: SN.red),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LiveRoomPage(title: '${r['title']}', roomName: '${r['roomName']}', hostId: '${r['host']?['id'] ?? ''}'),
                                    ),
                                  ),
                                  child: const Text('مشاهدة'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key, required this.title, required this.roomName, this.roomId, this.hostId});

  final String title;
  final String roomName;
  final String? roomId;
  final String? hostId;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

/// TikTok-style live room backed by LiveKit. The REST API issues a short-lived
/// room token; LiveKit carries the actual audio/video/screen-share media.
class _LiveRoomPageState extends State<LiveRoomPage> {
  final ctrl = TextEditingController();
  final List<Map<String, dynamic>> chat = [];
  final Room room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  dynamic _chatSub;
  dynamic _giftSub;
  bool connecting = true;
  bool connected = false;
  bool micOn = true;
  bool cameraOn = true;
  bool screenOn = false;
  bool ending = false;
  String? error;
  Map<String, dynamic>? _giftFx;
  String? _liveCoverImage;
  bool _frontCamera = true;
  String? _challengeId;
  int _scoreA = 0;
  int _scoreB = 0;
  Timer? _giftFxTimer;
  bool get _isHost => widget.hostId != null && widget.hostId!.isNotEmpty && '${Api.me?['id']}' == widget.hostId;
  Future<void> _showSharedReel(String url) async {
    if (url.isEmpty || !mounted) return;
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: VideoBox(
            url: url,
            autoPlay: true,
            playbackActive: true,
            height: 620,
            radius: 0,
          ),
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    room.addListener(_onRoomChanged);
    SocketService.i.connect();
    SocketService.i.joinLive(widget.roomName);
    _chatSub = SocketService.i.liveChat.listen((m) {
      final body='${m['body'] ?? ''}';
      if(body.startsWith('[live_image]')) { if(mounted)setState(()=>_liveCoverImage=body.substring('[live_image]'.length)); return; }
      if(body.startsWith('[watch_reel]')) { final url=body.substring('[watch_reel]'.length); if(mounted){ Future.microtask(()=>_showSharedReel(url)); } return; }
      if (mounted) setState(() => chat.add(m));
    });
    _giftSub = SocketService.i.liveGifts.listen((m) {
      if (!mounted) return;
      final gift = m['gift'] is Map ? Map<String, dynamic>.from(m['gift'] as Map) : <String, dynamic>{};
      setState(() { chat.add({'body': '🎁 ${gift['emoji'] ?? '🎁'} ${gift['name'] ?? 'هدية'}'}); _giftFx = gift; });
      _giftFxTimer?.cancel();
      _giftFxTimer = Timer(const Duration(milliseconds: 2400), () { if (mounted) setState(() => _giftFx = null); });
    });
    _connectLiveKit();
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _connectLiveKit() async {
    try {
      final credentials = await Api.liveToken(widget.roomName);
      final url = '${credentials['url'] ?? ''}'.trim();
      final token = '${credentials['token'] ?? ''}'.trim();
      if (url.isEmpty || token.isEmpty) {
        throw Exception('LIVEKIT_NOT_CONFIGURED');
      }
      await room.prepareConnection(url, token);
      await room.connect(url, token);
      if (_isHost) {
        try { await room.localParticipant?.setCameraEnabled(true); } catch (_) { cameraOn = false; }
        try { await room.localParticipant?.setMicrophoneEnabled(true); } catch (_) { micOn = false; }
      } else {
        cameraOn = false;
        micOn = false;
        try { await room.localParticipant?.setCameraEnabled(false); } catch (_) {}
        try { await room.localParticipant?.setMicrophoneEnabled(false); } catch (_) {}
      }
      if (!mounted) return;
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        connected = true;
        connecting = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        connected = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _flipCamera() async {
    if (!connected || !cameraOn) { toast(context, 'شغّل الكاميرا أولًا'); return; }
    try {
      final pubs = room.localParticipant?.videoTrackPublications ?? const [];
      for (final pub in pubs) {
        final track = pub.track;
        if (track is LocalVideoTrack) {
          _frontCamera = !_frontCamera;
          await track.setCameraPosition(_frontCamera ? CameraPosition.front : CameraPosition.back);
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (e) { if (mounted) toast(context, 'تعذّر تبديل الكاميرا'); }
  }

  Future<void> _uploadLiveImage() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f == null) return;
      final out = await Api.uploadMedia(f.path, kind: 'IMAGE');
      final url = '${out['url'] ?? out['secureUrl'] ?? ''}';
      if (url.isEmpty) throw Exception('UPLOAD_FAILED');
      if (mounted) setState(() => _liveCoverImage = url);
      SocketService.i.sendLiveChat(widget.roomName, '[live_image]$url');
      if (mounted) toast(context, 'تم وضع الصورة كواجهة للبث');
    } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _startChallenge() async {
    if(!_isHost || _remoteParticipants.isEmpty){toast(context,'يجب وجود مشارك آخر في البث');return;}
    try{final opponent=_remoteParticipants.first.identity;final c=await Api.createLiveChallenge(widget.roomName,opponent);if(!mounted)return;setState(()=>_challengeId='${c['id']}');SocketService.i.sendLiveChat(widget.roomName,'🏆 بدأت جولة تحدي');toast(context,'بدأت الجولة');}catch(e){if(mounted)toast(context,'تعذّر بدء الجولة');}
  }
  Future<void> _challengeScore(bool host) async {
    if(_challengeId==null)return;
    try{if(host)_scoreA++;else _scoreB++;await Api.updateLiveChallenge(_challengeId!,scoreA:_scoreA,scoreB:_scoreB);if(mounted)setState((){});}catch(_){}
  }
  Future<void> _finishChallenge(bool hostWinner) async {
    if(_challengeId==null)return;try{final winner=hostWinner?'${Api.me?['id']}':'${_remoteParticipants.isNotEmpty?_remoteParticipants.first.identity:''}';final r=await Api.finishLiveChallenge(_challengeId!,winner);if(mounted){setState(()=>_challengeId=null);toast(context,'الفائز: ${hostWinner?'أنت':'المشارك'} • انتصارات متتالية: ${r['liveWinStreak']??0}');}}catch(e){if(mounted)toast(context,'تعذّر إنهاء الجولة');}
  }

  Future<void> _toggleCamera() async {
    if (!connected) return;
    try {
      cameraOn = !cameraOn;
      await room.localParticipant?.setCameraEnabled(cameraOn);
      setState(() {});
    } catch (e) {
      cameraOn = !cameraOn;
      toast(context, 'تعذّر تشغيل الكاميرا: $e');
    }
  }

  Future<void> _toggleMic() async {
    if (!connected) return;
    try {
      micOn = !micOn;
      await room.localParticipant?.setMicrophoneEnabled(micOn);
      setState(() {});
    } catch (e) {
      micOn = !micOn;
      toast(context, 'تعذّر تشغيل الميكروفون: $e');
    }
  }

  Future<void> _toggleScreenShare() async {
    if (!connected) return;
    try {
      if (screenOn) {
        await room.localParticipant?.setScreenShareEnabled(false);
        if (FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.disableBackgroundExecution();
        }
        if (mounted) setState(() => screenOn = false);
        return;
      }

      final granted = await webrtc.Helper.requestCapturePermission();
      if (!granted) return;

      final config = const FlutterBackgroundAndroidConfig(
        notificationTitle: 'SocialNova Live',
        notificationText: 'مشاركة شاشة الهاتف قيد التشغيل',
        notificationImportance: AndroidNotificationImportance.high,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      );
      await FlutterBackground.initialize(androidConfig: config);
      if (!FlutterBackground.isBackgroundExecutionEnabled) {
        final ok = await FlutterBackground.enableBackgroundExecution();
        if (!ok) throw Exception('تعذّر تشغيل خدمة مشاركة الشاشة.');
      }
      await room.localParticipant?.setScreenShareEnabled(true, captureScreenAudio: true);
      if (mounted) setState(() => screenOn = true);
    } catch (e) {
      if (!mounted) return;
      toast(context, 'تعذّرت مشاركة الشاشة: $e');
    }
  }

  Future<void> _sendChat() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    SocketService.i.sendLiveChat(widget.roomName, text);
    ctrl.clear();
  }

  Future<void> _endLive() async {
    if (ending) return;
    setState(() => ending = true);
    try {
      if (screenOn) {
        await room.localParticipant?.setScreenShareEnabled(false);
        if (FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.disableBackgroundExecution();
        }
      }
      if (widget.roomId != null && widget.roomId!.isNotEmpty) {
        await Api.endLive(widget.roomId!);
      }
    } catch (_) {
      // The room is still closed locally even if the REST end call fails.
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    SocketService.i.leaveLive(widget.roomName);
    _chatSub?.cancel();
    _giftSub?.cancel();
    _giftFxTimer?.cancel();
    ctrl.dispose();
    room.removeListener(_onRoomChanged);
    room.disconnect();
    room.dispose();
    if (FlutterBackground.isBackgroundExecutionEnabled) {
      FlutterBackground.disableBackgroundExecution();
    }
    super.dispose();
  }

  Widget _videoForParticipant(Participant participant, {bool fill = true}) {
    VideoTrack? video;
    VideoTrack? screen;
    for (final pub in participant.videoTrackPublications) {
      if (pub.track == null || pub.muted) continue;
      final track = pub.track;
      if (track is! VideoTrack) continue;
      if (pub.isScreenShare) {
        screen ??= track;
      } else {
        video ??= track;
      }
    }
    final track = screen ?? video;
    if (track == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 34,
          backgroundColor: Colors.white12,
          child: Text(
            participant.name.isNotEmpty ? participant.name.substring(0, 1).toUpperCase() : 'S',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(fill ? 0 : 18),
      child: VideoTrackRenderer(track),
    );
  }

  List<Participant> get _remoteParticipants => room.remoteParticipants.values.toList();

  Widget _buildVideoStage() {
    final remotes = _remoteParticipants;
    final local = room.localParticipant;
    final main = remotes.isNotEmpty ? remotes.first : local;
    final extra = remotes.length > 1 ? remotes.skip(1).take(3).toList() : <RemoteParticipant>[];

    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: _liveCoverImage != null
            ? Stack(children:[Positioned.fill(child:Image.network(_liveCoverImage!,fit:BoxFit.cover)),Positioned.fill(child:Container(color:Colors.black.withValues(alpha:.28))),])
            : main == null
            ? const Center(child: Icon(Icons.person, color: Colors.white38, size: 90))
            : Stack(
                fit: StackFit.expand,
                children: [
                  _videoForParticipant(main),
                  if (extra.isNotEmpty)
                    Positioned(
                      top: 76,
                      right: 12,
                      child: SizedBox(
                        width: 112,
                        height: 76,
                        child: Row(
                          children: [
                            for (final p in extra)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _videoForParticipant(p, fill: false),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (local != null && remotes.isNotEmpty)
                    Positioned(
                      top: 74,
                      left: 12,
                      child: Container(
                        width: 108,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _videoForParticipant(local, fill: false),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _glassButton({required IconData icon, required VoidCallback onTap, bool active = false}) {
    return Material(
      color: Colors.black.withValues(alpha: .45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: active ? SN.cyan : Colors.white, size: 23),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildVideoStage(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _glassButton(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 7),
                _glassButton(icon: Icons.share_rounded, onTap: () => shareSocialItemToChats(context, title:'مشاركة البث', body:'[live_share]${widget.roomName}|${widget.title}', icon:Icons.sensors_rounded)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .42),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sensors_rounded, color: SN.pink, size: 17),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                        const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .42), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_remoteParticipants.length + (connected ? 1 : 0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          if (connecting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: SN.cyan),
                    SizedBox(height: 14),
                    Text(L10n.t('جاري فتح البث بجودة عالية...',), style: TextStyle(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          if (_giftFx != null)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: .55, end: 1), duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) => Center(child: Transform.scale(scale: scale, child: child)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .48), boxShadow: const [BoxShadow(color: Colors.white24, blurRadius: 45, spreadRadius: 12)]), child: Center(child: Text('${_giftFx?['emoji'] ?? '🎁'}', style: const TextStyle(fontSize: 78)))),
                    const SizedBox(height: 12),
                    Text('${_giftFx?['name'] ?? 'هدية'}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    const Text('هدية وصلت 🎉', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          if (error != null && !connecting)
            Positioned(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).size.height * .38,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(22)),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 40),
                    const SizedBox(height: 10),
                    const Text('تعذّر الاتصال بالبث', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () { setState(() { connecting = true; error = null; }); _connectLiveKit(); }, child: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 92,
            child: SizedBox(
              height: 190,
              child: ListView.builder(
                reverse: true,
                itemCount: chat.length,
                itemBuilder: (_, i) {
                  final m = chat[chat.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(18)),
                          child: mentionText(context, '${m['body'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white24)),
                    child: TextField(
                      controller: ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'اكتب تعليقًا...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none, filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
                      onSubmitted: (_) => _sendChat(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isHost) ...[
                  _glassButton(icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded, active: micOn, onTap: _toggleMic),
                  const SizedBox(width: 5),
                  _glassButton(icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, active: cameraOn, onTap: _toggleCamera),
                  const SizedBox(width: 5),
                  _glassButton(icon: Icons.flip_camera_android_rounded, onTap: _flipCamera),
                  const SizedBox(width: 5),
                  _glassButton(icon: Icons.image_outlined, onTap: _uploadLiveImage),
                  const SizedBox(width: 5),
                  _glassButton(icon: screenOn ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded, active: screenOn, onTap: _toggleScreenShare),
                  const SizedBox(width: 5),
                ],
                if (_isHost) ...[
                  _glassButton(icon: Icons.sports_esports_rounded, onTap: _challengeId==null ? _startChallenge : () => showModalBottomSheet(context:context,backgroundColor:SN.bg1,builder:(ctx)=>SafeArea(child:Wrap(children:[ListTile(title:Text('الجولة: $_scoreA - $_scoreB'),subtitle:Text('أضف نقطة للمضيف أو أنهِ الجولة')),ListTile(leading:Icon(Icons.add_circle_outline),title:Text('نقطة لي'),onTap:(){Navigator.pop(ctx);_challengeScore(true);}),ListTile(leading:Icon(Icons.remove_circle_outline),title:Text('نقطة للخصم'),onTap:(){Navigator.pop(ctx);_challengeScore(false);}),ListTile(leading:Icon(Icons.emoji_events_outlined),title:Text('الفوز لي'),onTap:(){Navigator.pop(ctx);_finishChallenge(true);}),ListTile(leading:Icon(Icons.flag_outlined),title:Text('الفوز للخصم'),onTap:(){Navigator.pop(ctx);_finishChallenge(false);})]))),active:_challengeId!=null),
                  const SizedBox(width:5),
                ],
                if (!_isHost) _glassButton(icon: Icons.pan_tool_alt_rounded, onTap: () { SocketService.i.sendLiveChat(widget.roomName, '🙋 طلب الانضمام إلى البث'); toast(context, 'تم إرسال طلب الانضمام للمضيف'); }),
                if (!_isHost) const SizedBox(width: 5),
                _glassButton(icon: Icons.card_giftcard_rounded, onTap: widget.hostId == null || widget.hostId!.isEmpty ? () {} : () => showGiftPicker(context, receiverId: widget.hostId!, receiverName: widget.title, contextType: 'LIVE', contextId: widget.roomName)),
                const SizedBox(width: 5),
                _glassButton(icon: Icons.favorite_rounded, onTap: () => SocketService.i.sendLiveChat(widget.roomName, '❤️')),
              ],
            ),
          ),
          if (widget.roomId != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 62,
              right: 12,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), backgroundColor: Colors.black38),
                onPressed: ending ? null : _endLive,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('إنهاء البث'),
              ),
            ),
        ],
      ),
    );
  }
}


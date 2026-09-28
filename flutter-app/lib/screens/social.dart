import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../core/localization.dart';
import 'call_history.dart';

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
import '../core/message_effects.dart';
import '../core/nova_audio.dart';
import '../core/nova_gifts.dart';
import '../core/nova_ui.dart';
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
  final TextEditingController _search = TextEditingController();
  final Map<String, Timer> _typingPeers = <String, Timer>{};
  dynamic _typingSub;
  String _query = '';
  String _tab = 'all'; // all | unread | groups

  @override
  void initState() {
    super.initState();
    SocketService.i.connect();
    _future = Api.conversations();
    // Realtime typing: the peer's "يكتب الآن…" is driven by socket events, and
    // expires on its own so a lost stop-event can never stick a row.
    _typingSub = SocketService.i.typing.listen((m) {
      final from = '${m['from'] ?? m['fromId'] ?? ''}';
      if (from.isEmpty || !mounted) return;
      _typingPeers[from]?.cancel();
      _typingPeers[from] = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _typingPeers.remove(from));
      });
      setState(() {});
    });
  }

  @override
  void dispose() {
    _typingSub?.cancel();
    for (final t in _typingPeers.values) {
      t.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = Api.conversations());

  /// Backend markers (`[image]`, `[story_reply]`, …) become readable previews.
  String _readableBody(String body) {
    const markers = <String, String>{
      '[story_reaction]': 'أعجب بقصتك',
      '[story_reply]': 'رد على قصتك: ',
      '[live_share]': 'دعوة لبث مباشر',
      '[reel_share]': 'مقطع ريلز',
      '[image]': 'صورة',
      '[voice]': 'رسالة صوتية',
      '[post_share]': 'شارك منشورًا',
      '[gift]': 'هدية',
      '[location]': 'موقع',
    };
    for (final e in markers.entries) {
      if (body.startsWith(e.key)) {
        final rest = body.substring(e.key.length).replaceAll('\n', ' ').trim();
        if (e.key == '[story_reply]') return '${e.value}$rest';
        return e.value;
      }
    }
    if (body.startsWith('[call:video]')) return 'مكالمة فيديو';
    if (body.startsWith('[call:audio]')) return 'مكالمة صوتية';
    return body;
  }

  String _preview(Map<String, dynamic> convo) {
    final last = convo['lastMessage'];
    if (last is! Map) return '';
    final body = '${last['body'] ?? ''}'.trim();
    if (body.isEmpty) return '';
    final text = _readableBody(body);
    final mine = '${last['senderId']}' == '${Api.me?['id']}';
    return mine ? 'أنت: $text' : text;
  }

  /// Compact inbox stamp: today → HH:MM, yesterday → أمس, older → D/M.
  String _stamp(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff <= 0) return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return 'أمس';
    if (diff < 7) return 'قبل $diff أيام';
    return '${d.day}/${d.month}';
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المحادثات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('دردشاتك الفورية مع الأصدقاء', style: TextStyle(color: SN.textMut, fontSize: 11.5)),
                ],
              ),
            ),
            IconButton(tooltip: 'سجل المكالمات', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallHistoryPage())), icon: const Icon(Icons.call_rounded)),
            IconButton(tooltip: 'طلبات المراسلة', onPressed: () => showMessageRequests(context), icon: const Icon(Icons.mail_outline_rounded)),
            IconButton(
              tooltip: 'محادثة جديدة',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessengerSearchPage()));
                if (!mounted) return;
                _reload();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      );

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: NovaGlass(
          radius: NovaTokens.rMd,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          blur: 0,
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 19, color: SN.textMut),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن محادثة أو @مستخدم',
                    filled: false,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                  child: const Icon(Icons.close_rounded, size: 18, color: SN.textMut),
                ),
            ],
          ),
        ),
      );

  Widget _groupsTab() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: SN.grad,
              borderRadius: BorderRadius.circular(NovaTokens.rXl),
              boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .22), blurRadius: 24)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups_rounded, color: Colors.white, size: 38),
                const SizedBox(height: 10),
                const Text('مجموعاتك', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('أنشئ مجموعة أو انضم لواحدة وواصل الحديث مع الجميع', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsPage())),
                    icon: const Icon(Icons.arrow_forward_rounded, color: SN.violet, size: 18),
                    label: const Text('عرض مجموعاتي', style: TextStyle(color: SN.violet, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _inbox(List<dynamic> convos) {
    final rows = convos
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((c) {
      if (_tab == 'unread' && (int.tryParse('${c['unreadCount'] ?? 0}') ?? 0) <= 0) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return '${c['displayName'] ?? ''}'.toLowerCase().contains(q) || '${c['username'] ?? ''}'.toLowerCase().contains(q);
    }).toList();

    if (rows.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 110),
        EmptyState(
          text: _query.isNotEmpty
              ? 'لا نتائج مطابقة لبحثك.'
              : _tab == 'unread'
                  ? 'لا رسائل غير مقروءة. كل شيء تحت السيطرة.'
                  : 'لا توجد محادثات بعد.\nابحث عن صديق وابدأ الدردشة.',
          icon: Icons.chat_bubble_outline,
        ),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 100),
      itemCount: rows.length,
      itemBuilder: (c, i) {
        final u = rows[i];
        final id = '${u['id'] ?? ''}';
        final name = '${u['displayName'] ?? u['username'] ?? ''}';
        final tier = '${u['verificationTier'] ?? (u['isVerified'] == true ? 'NORMAL' : 'NONE')}';
        final last = u['lastMessage'];
        return NovaChatRow(
          name: name,
          username: '${u['username'] ?? ''}',
          avatarUrl: '${u['avatarUrl'] ?? ''}',
          verificationTier: tier,
          preview: _preview(u),
          timeLabel: _stamp(last is Map ? last['createdAt'] : null),
          unread: int.tryParse('${u['unreadCount'] ?? 0}') ?? 0,
          typing: _typingPeers.containsKey(id),
          onAvatarTap: () => openProfile(context, id),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(userId: id, name: name, avatar: '${u['avatarUrl'] ?? ''}'),
              ),
            );
            if (mounted) _reload();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _searchField(),
            NovaTabs<String>(
              values: const ['all', 'unread', 'groups'],
              labels: const ['الكل', 'غير مقروءة', 'مجموعات'],
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _tab == 'groups'
                  ? _groupsTab()
                  : RefreshIndicator(
                      color: SN.violet,
                      onRefresh: () async => _reload(),
                      child: FutureBuilder<List<dynamic>>(
                        future: _future,
                        builder: (c, snap) {
                          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
                          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
                          return _inbox(snap.data ?? []);
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
  /// Effect attached to the next outgoing message (see message_effects.dart).
  String _pendingEffect = '';

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
  dynamic _callAcceptedSub;
  dynamic _callRejectedSub;
  bool _callDialogOpen = false;

  // Typing presence (real socket events; never faked in the UI).
  dynamic _typingSub;
  Timer? _typingStop;
  Timer? _peerTypingTimer;
  bool _typingSent = false;
  bool _peerTyping = false;

  @override
  void initState() {
    super.initState();
    _chatFxController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    SocketService.i.connect();
    _callSub = SocketService.i.callInvites.listen((m) {
      if (!mounted || _callDialogOpen) return;
      final from = '${m['from'] ?? m['fromId'] ?? ''}';
      if (from != widget.userId) return;
      _showIncomingCall(m);
    });
    _callAcceptedSub = SocketService.i.callAccepted.listen((m) {
      if (!mounted) return;
      final from = '${m['from'] ?? m['fromId'] ?? ''}';
      if (from == widget.userId) toast(context, 'تم قبول المكالمة ✓');
    });
    _callRejectedSub = SocketService.i.callRejected.listen((m) {
      if (!mounted) return;
      final from = '${m['from'] ?? m['fromId'] ?? ''}';
      if (from == widget.userId) toast(context, 'تم رفض المكالمة');
    });
    _sub = SocketService.i.messages.listen((m) {
      final mine = '${m['senderId']}' == '${Api.me?['id']}';
      if (mine || '${m['senderId']}' == widget.userId) {
        if (!msgs.any((x) => '${x['id']}' == '${m['id']}')) {
          setState(() => msgs.add(m));
          final fx = '${m['effect'] ?? ''}';
          if (fx.isNotEmpty && mounted) showMessageEffect(context, fx);
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
    _typingSub = SocketService.i.typing.listen((m) {
      final from = '${m['from'] ?? m['fromId'] ?? ''}';
      if (from != widget.userId || !mounted) return;
      final typing = m['typing'] != false;
      _peerTypingTimer?.cancel();
      setState(() => _peerTyping = typing);
      if (typing) {
        _peerTypingTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _peerTyping = false);
        });
      }
    });
    _loadChatTheme();
    _load();
  }

  /// Emits a debounced typing signal to the peer (no-op when the socket is off).
  void _onComposerChanged(String value) {
    final text = value.trim();
    if (text.isNotEmpty && !_typingSent) {
      _typingSent = true;
      SocketService.i.sendTyping(to: widget.userId);
    }
    _typingStop?.cancel();
    _typingStop = Timer(const Duration(milliseconds: 1600), () {
      if (!_typingSent) return;
      _typingSent = false;
      SocketService.i.sendTyping(to: widget.userId, typing: false);
    });
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
    // Ten named themes (static/animated) + three premium animated ones.
    final choices = <Map<String,String>>[
      {'id':'animated:stars','name':'🌌 فضاء'},
      {'id':'gradient:ocean','name':'🌊 محيط'},
      {'id':'animated:sakura','name':'🌸 ساكورا'},
      {'id':'animated:fire','name':'🔥 نار'},
      {'id':'gradient:neon','name':'💜 نيون'},
      {'id':'gradient:midnight','name':'🌙 ليل'},
      {'id':'animated:particles','name':'🎮 ألعاب'},
      {'id':'gradient:diamond','name':'💎 ألماس'},
      {'id':'gradient:love','name':'❤️ حب'},
      {'id':'gradient:dark','name':'🖤 داكن'},
      {'id':'animated:aurora','name':'✨ شفق (مميز)'},
      {'id':'animated:hearts','name':'💗 قلوب (مميز)'},
      {'id':'animated:snow','name':'❄️ ثلج (مميز)'},
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
      'gradient:neon':[const Color(0xFF12002E),const Color(0xFF7C3AED)],
      'gradient:diamond':[const Color(0xFF06202A),const Color(0xFF0E7490)],
      'gradient:dark':[const Color(0xFF0A0A0A),const Color(0xFF1F1F24)],
      'animated:sakura':[const Color(0xFF2B1020),const Color(0xFF9D174D)],
      'animated:fire':[const Color(0xFF2A0A05),const Color(0xFFB91C1C)],
      'animated:snow':[const Color(0xFF0B1220),const Color(0xFF334155)],
      'animated:aurora':[const Color(0xFF071A2B),const Color(0xFF4C1D95)],
      'animated:stars':[const Color(0xFF030712),const Color(0xFF172554)],
      'animated:hearts':[const Color(0xFF3B0A2E),const Color(0xFF831843)],
      'animated:particles':[const Color(0xFF111827),const Color(0xFF0F766E)],
    }[_chatTheme] ?? [SN.bg1,SN.bg2];
    return BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:map));
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallRoomPage(title: widget.name, roomName: roomName, videoCall: video, peerUserId: widget.userId, isCaller: true)));
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
          TextButton(onPressed: () { SocketService.i.sendCallReject('${m['from'] ?? m['fromId'] ?? ''}'); Navigator.pop(ctx); }, child: const Text('رفض')),
          FilledButton(onPressed: () { SocketService.i.sendCallAccept('${m['from'] ?? m['fromId'] ?? ''}', roomName); Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => CallRoomPage(title: widget.name, roomName: roomName, videoCall: video, peerUserId: widget.userId, isCaller: false))); }, child: const Text('قبول')),
        ],
      ),
    ).whenComplete(() => _callDialogOpen = false);
  }

  /// Picks the effect (celebration/hearts/fire/stars/snow/fireworks) attached
  /// to the next message.
  Future<void> _pickMessageEffect() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Wrap(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 2), child: Align(alignment: AlignmentDirectional.centerStart, child: Text('تأثير الرسالة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))),
        ListTile(leading: const Icon(Icons.block, color: SN.textSec), title: const Text('بدون تأثير'), trailing: _pendingEffect.isEmpty ? const Icon(Icons.check_circle, color: SN.violet) : null, onTap: () => Navigator.pop(ctx, '')),
        for (final e in kMessageEffects)
          ListTile(
            leading: Text(e.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(e.label),
            trailing: _pendingEffect == e.id ? const Icon(Icons.check_circle, color: SN.violet) : null,
            onTap: () { Navigator.pop(ctx, e.id); showMessageEffect(context, e.id); },
          ),
      ])),
    );
    if (picked == null) return;
    if (mounted) setState(() => _pendingEffect = picked);
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    _typingStop?.cancel();
    if (_typingSent) {
      _typingSent = false;
      SocketService.i.sendTyping(to: widget.userId, typing: false);
    }
    try {
      // REST write guarantees persistence; Socket.IO mirrors it in realtime.
      final effect = _pendingEffect;
      await Api.sendMessage(widget.userId, text, secret: secretMode, selfDestruct: selfDestruct, ttlMinutes: secretTtl, viewLimit: viewLimit, effect: effect);
      if (effect.isNotEmpty && mounted) {
        showMessageEffect(context, effect);
        setState(() => _pendingEffect = '');
      }
      ctrl.clear();
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
    _callAcceptedSub?.cancel();
    _callRejectedSub?.cancel();
    _typingSub?.cancel();
    _typingStop?.cancel();
    _peerTypingTimer?.cancel();
    if (_typingSent) {
      _typingSent = false;
      SocketService.i.sendTyping(to: widget.userId, typing: false);
    }
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
    final read = m['read'] == true || m['readAt'] != null;
    final delivered = m['deliveredAt'] != null;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: NovaTicks(read: read, delivered: delivered, mine: mine),
    );
  }

  Widget _messageContent(String body, bool mine, String messageId) {
    if (body.startsWith('[call:audio]') || body.startsWith('[call:video]')) {
      final video = body.startsWith('[call:video]');
      final raw = body.substring(video ? '[call:video]'.length : '[call:audio]'.length);
      final seconds = int.tryParse(raw) ?? 0;
      final mm = (seconds ~/ 60).toString().padLeft(2, '0');
      final ss = (seconds % 60).toString().padLeft(2, '0');
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .16) : SN.violet.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(video ? Icons.videocam_rounded : Icons.call_rounded, color: mine ? Colors.white : SN.violet)),
        const SizedBox(width: 9),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(video ? 'مكالمة فيديو' : 'مكالمة صوتية', style: TextStyle(color: mine ? Colors.white : SN.textPri, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('المدة $mm:$ss', style: TextStyle(color: mine ? Colors.white70 : SN.textMut, fontSize: 11)),
        ]),
      ]);
    }
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (_peerTyping)
                      const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('يكتب الآن…', style: TextStyle(fontSize: 10.5, color: SN.cyan, fontWeight: FontWeight.w800)),
                        SizedBox(width: 5),
                        NovaTypingDots(),
                      ]),
                  ],
                ),
              ),
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
                        itemCount: msgs.length + (_peerTyping ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i >= msgs.length) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: NovaBubble(
                                  mine: false,
                                  tail: false,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: const NovaTypingDots(),
                                ),
                              ),
                            );
                          }
                          final mine = '${msgs[i]['senderId']}' == myId;
                          return Align(
                            alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                            child: GestureDetector(
                              onLongPress: () => _messageMenu(Map<String,dynamic>.from(msgs[i] as Map), mine),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: NovaBubble(
                                  mine: mine,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
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
                                      Text(_formatTime('${msgs[i]['createdAt'] ?? ''}'), style: TextStyle(fontSize: 9.5, color: mine ? Colors.white70 : SN.textMut)),
                                      _messageStatus(Map<String,dynamic>.from(msgs[i] as Map), mine),
                                    ]),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (secretMode) Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3), child: Row(children: [Icon(Icons.shield_rounded, size: 15, color: SN.violet), SizedBox(width: 5), Text('الوضع السري مفعّل • ${secretTtl == 1440 ? '24 ساعة' : '$secretTtl دقيقة'}', style: TextStyle(fontSize: 11, color: SN.violet, fontWeight: FontWeight.w800)), Spacer(), if(selfDestruct) Icon(Icons.auto_delete_rounded, size: 15, color: SN.violet)])),
          NovaComposer(
            primaryIcon: recording ? Icons.stop_rounded : Icons.send_rounded,
            onPrimary: recording ? _toggleRecording : _send,
            busy: sending && !recording,
            recordingNote: recording ? L10n.t('جاري تسجيل رسالة صوتية… اضغط لإرسالها') : null,
            field: TextField(
              controller: ctrl,
              onChanged: _onComposerChanged,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'رسالة…',
                hintStyle: TextStyle(color: SN.textMut),
                filled: false,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              ),
            ),
            leading: [
              IconButton(tooltip: 'تأثيرات الرسالة', onPressed: _pickMessageEffect, icon: Icon(_pendingEffect.isEmpty ? Icons.auto_awesome_outlined : Icons.auto_awesome, size: 26, color: _pendingEffect.isEmpty ? SN.textSec : SN.violet)),
              IconButton(tooltip: 'المزيد', onPressed: _moreActions, icon: const Icon(Icons.add_circle_outline, size: 26, color: SN.textSec)),
              IconButton(tooltip: 'صورة', onPressed: () => _sendMedia(source: ImageSource.gallery), icon: const Icon(Icons.image_outlined, size: 26, color: SN.textSec)),
              IconButton(tooltip: 'تفاعل', onPressed: _emojiPicker, icon: const Icon(Icons.emoji_emotions_outlined, size: 26, color: SN.textSec)),
            ],
            secondary: IconButton(
              tooltip: recording ? 'إيقاف التسجيل' : 'رسالة صوتية',
              onPressed: _toggleRecording,
              icon: Icon(recording ? Icons.stop_circle_outlined : Icons.mic_none_rounded, size: 27, color: recording ? SN.pink : SN.textSec),
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
    } else if(mode=='sakura') {
      // Soft falling petals.
      for(int i=0;i<22;i++){final x=(r.nextDouble()*size.width + math.sin(t*math.pi*2+i)*30)%size.width;final y=((r.nextDouble()+t*0.09+i*.041)%1)*size.height;p.color=const Color(0xFFF9A8D4).withValues(alpha:.35);canvas.drawOval(Rect.fromCenter(center:Offset(x,y),width:8+r.nextDouble()*7,height:5+r.nextDouble()*5),p);}
    } else if(mode=='fire') {
      // Rising embers.
      for(int i=0;i<26;i++){final x=(r.nextDouble()*size.width + math.sin(t*math.pi*2+i)*18)%size.width;final y=(1-((r.nextDouble()+t*0.22+i*.031)%1))*size.height;p.color=(i.isEven?const Color(0xFFFF7A18):const Color(0xFFFFC53D)).withValues(alpha:.30);canvas.drawCircle(Offset(x,y),3+r.nextDouble()*9,p);}
    } else if(mode=='snow') {
      for(int i=0;i<40;i++){final x=(r.nextDouble()*size.width + math.sin(t*math.pi*2+i)*22)%size.width;final y=((r.nextDouble()+t*0.07+i*.023)%1)*size.height;p.color=Colors.white.withValues(alpha:.28);canvas.drawCircle(Offset(x,y),1.5+r.nextDouble()*3,p);}
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
  @override State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<List<dynamic>> _future;
  final search = TextEditingController();
  String filter = 'الكل';

  @override
  void initState() { super.initState(); _future = Api.groups(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> _create() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final rules = TextEditingController();
    String privacy = 'PUBLIC';
    bool comments = true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Container(
        height: MediaQuery.of(ctx).size.height * .86,
        decoration: BoxDecoration(color: SN.bg1, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: SN.strokeSoft)),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 14, 12, 8), child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.groups_rounded, color: Colors.white)),
            const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مجموعة جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 2), Text('أنشئ مجتمعًا بطابعك الخاص', style: TextStyle(color: SN.textMut, fontSize: 12))])),
            IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close_rounded)),
          ])),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
            Container(height: 132, decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(24)), child: Stack(children: [
              const Positioned(right: 20, top: 18, child: Icon(Icons.auto_awesome_rounded, color: Colors.white24, size: 64)),
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), shape: BoxShape.circle), child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 26)), const SizedBox(height: 8), const Text('صورة غلاف المجموعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]))
            ])),
            const SizedBox(height: 18),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المجموعة', prefixIcon: Icon(Icons.title_rounded))),
            const SizedBox(height: 12),
            TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف المجموعة', prefixIcon: Icon(Icons.description_outlined))),
            const SizedBox(height: 16),
            const Text('الخصوصية', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _choiceCard('عامة', 'الجميع يستطيع الانضمام', Icons.public_rounded, privacy == 'PUBLIC', () => setSheet(() => privacy = 'PUBLIC'))),
              const SizedBox(width: 10),
              Expanded(child: _choiceCard('خاصة', 'للأعضاء فقط', Icons.lock_outline_rounded, privacy == 'PRIVATE', () => setSheet(() => privacy = 'PRIVATE'))),
            ]),
            const SizedBox(height: 14),
            TextField(controller: rules, maxLines: 3, decoration: const InputDecoration(labelText: 'قواعد المجتمع', hintText: 'الاحترام، عدم الإزعاج، المحتوى المسموح... ', prefixIcon: Icon(Icons.rule_rounded))),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: SN.bg2, borderRadius: BorderRadius.circular(18), border: Border.all(color: SN.strokeSoft)), child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: SN.violet.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.forum_outlined, color: SN.violet)),
              const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('مساحة نقاش جاهزة', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('يمكن للأعضاء نشر الرسائل والوسائط داخل المجموعة', style: TextStyle(color: SN.textMut, fontSize: 11))])),
              Switch(value: comments, onChanged: (v) => setSheet(() => comments = v)),
            ])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.check_rounded), label: const Text('إنشاء المجموعة', style: TextStyle(fontWeight: FontWeight.w800)))))
        ]))
      )),
    );
    if (ok == true && name.text.trim().length >= 2) {
      try { await Api.createGroup(name.text.trim(), desc.text.trim(), privacy: privacy, rules: rules.text.trim()); if (!mounted) return; setState(() => _future = Api.groups()); toast(context, 'تم إنشاء المجموعة'); }
      catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
    }
    name.dispose(); desc.dispose(); rules.dispose();
  }

  Widget _choiceCard(String title, String sub, IconData icon, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(18), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: selected ? SN.violet.withValues(alpha: .12) : SN.bg2, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? SN.violet : SN.strokeSoft, width: selected ? 1.4 : 1),
    ), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: selected ? SN.violet : SN.textMut), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: SN.textMut, fontSize: 10))]))
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SN.violet,
        elevation: 8,
        onPressed: _create,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إنشاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.groups_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('المجتمعات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        Text('اكتشف، انضم وشارك اهتماماتك', style: TextStyle(color: SN.textMut, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _future = Api.groups()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث عن مجتمع أو اهتمام...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in const ['الكل', 'العامة', 'الخاصة', 'الأكثر نشاطاً'])
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: filter == f,
                        onSelected: (_) => setState(() => filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: SN.violet,
                onRefresh: () async => setState(() => _future = Api.groups()),
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const LoadingBox();
                    }
                    if (snap.hasError) {
                      return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
                    }

                    final q = search.text.trim().toLowerCase();
                    final groups = (snap.data ?? [])
                        .whereType<Map>()
                        .where((g) {
                          final name = '${g['name'] ?? ''}'.toLowerCase();
                          final description = '${g['description'] ?? ''}'.toLowerCase();
                          final privacy = '${g['privacy'] ?? 'PUBLIC'}';
                          if (q.isNotEmpty && !name.contains(q) && !description.contains(q)) return false;
                          if (filter == 'العامة' && privacy != 'PUBLIC') return false;
                          if (filter == 'الخاصة' && privacy != 'PRIVATE') return false;
                          return true;
                        })
                        .toList();

                    if (filter == 'الأكثر نشاطاً') {
                      groups.sort(
                        (a, b) => '${((b['_count'] ?? {}) as Map)['members'] ?? 0}'
                            .compareTo('${((a['_count'] ?? {}) as Map)['members'] ?? 0}'),
                      );
                    }

                    if (groups.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 90),
                          EmptyState(
                            text: 'لا توجد مجتمعات مطابقة\nأنشئ مجتمعك الأول الآن',
                            icon: Icons.groups_outlined,
                          ),
                        ],
                      );
                    }

                    final cards = <Widget>[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: SN.grad,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(color: SN.violet.withValues(alpha: .18), blurRadius: 24),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .16),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'مكانك بين الناس',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'ابحث عن مجتمع يناسبك أو ابدأ واحدًا من الصفر.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ];

                    for (final raw in groups) {
                      final group = Map<String, dynamic>.from(raw);
                      cards.add(
                        _GroupListCard(
                          group: group,
                          onOpen: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatPage(
                                groupId: '${group['id']}',
                                name: '${group['name']}',
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                      children: cards,
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
  const CallRoomPage({super.key, required this.title, required this.roomName, this.videoCall = false, this.peerUserId, this.isCaller = false, this.callId = ''});
  final String title, roomName;
  final bool videoCall;
  final String? peerUserId;
  final bool isCaller;
  /// V93: the persisted Call row, so hang-up records the real duration.
  final String callId;
  @override State<CallRoomPage> createState() => _CallRoomPageState();
}

class _CallRoomPageState extends State<CallRoomPage> {
  final Room room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
  bool connected=false, micOn=true, cameraOn=false, speakerOn=true;
  String? error;
  DateTime? _startedAt;
  Timer? _durationTimer;
  int _callSeconds = 0;
  bool _sawRemote = false;
  bool _callLogged = false;
  bool _ending = false;
  dynamic _reelSub;
  @override void initState(){super.initState();room.addListener(_changed);SocketService.i.connect();_reelSub=SocketService.i.callReels.listen((m){if(!mounted)return;final from='${m['from']??''}';if(widget.peerUserId!=null&&from.isNotEmpty&&from!=widget.peerUserId)return;final url='${m['url']??''}';if(url.isNotEmpty)_showSharedReel(url,title:'${m['title']??''}');});_connect();}
  void _changed(){
    if (!mounted) return;
    final hasRemote = room.remoteParticipants.isNotEmpty;
    if (hasRemote) _sawRemote = true;
    if (connected && _sawRemote && !hasRemote && !_ending) {
      _ending = true;
      _finishCallLog();
      Future.microtask(() { if (mounted) Navigator.pop(context); });
      return;
    }
    setState((){});
  }

  Future<void> _finishCallLog() async {
    if (_callLogged || widget.peerUserId == null || widget.peerUserId!.isEmpty) return;
    _callLogged = true;
    final seconds = _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds.clamp(0, 86400);
    if (seconds == 0 && !connected) return; // never answered: let the ring-timeout mark it MISSED
    // V93: write the real record (status + duration) and tell the peer.
    try {
      if (widget.callId.isNotEmpty) {
        await Api.endCall(widget.callId);
      } else {
        SocketService.i.sendCallEnd(to: widget.peerUserId!, roomName: widget.roomName);
      }
    } catch (_) {}
    if (widget.isCaller) {
      try {
        await Api.sendMessage(widget.peerUserId!, '[call:${widget.videoCall ? 'video' : 'audio'}]$seconds');
      } catch (_) {}
    }
  }

  String get _durationLabel {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
  Future<void> _connect() async {
    try {
      final c=await Api.callToken(widget.roomName); final url='${c['url']??''}'; final token='${c['token']??''}';
      if(url.isEmpty||token.isEmpty) throw Exception('LIVEKIT_NOT_CONFIGURED');
      await room.prepareConnection(url, token); await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if(widget.videoCall){try{await room.localParticipant?.setCameraEnabled(true);cameraOn=true;}catch(_){}}
      if(mounted)setState(()=>connected=true);
      _startedAt ??= DateTime.now();
      _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _callSeconds = DateTime.now().difference(_startedAt!).inSeconds);
      });
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
  }
  Future<void> _mic() async {try{micOn=!micOn;await room.localParticipant?.setMicrophoneEnabled(micOn);if(mounted)setState((){});}catch(_){}}
  Future<void> _camera() async {try{cameraOn=!cameraOn;await room.localParticipant?.setCameraEnabled(cameraOn);if(mounted)setState((){});}catch(_){}}
  Future<void> _speaker() async {try{speakerOn=!speakerOn;await webrtc.Helper.setSpeakerphoneOn(speakerOn);if(mounted)setState((){});}catch(_) {}}
  Future<void> _showSharedReel(String url, {String title=''}) async {
    if (url.isEmpty || !mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            color: const Color(0xFF090A10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                  child: Row(children: [
                    const Icon(Icons.movie_filter_rounded, color: SN.cyan),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title.isEmpty ? 'Reels مشتركة' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                  ]),
                ),
                AspectRatio(aspectRatio: 9 / 16, child: VideoBox(url: url, autoPlay: true, playbackActive: true, height: 620, radius: 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _watchReelTogether() async {
    try {
      final rows=await Api.reels();
      if(!mounted)return;
      await showModalBottomSheet(context:context,backgroundColor:SN.bg1,showDragHandle:true,builder:(ctx)=>SizedBox(height:520,child:ListView(padding:EdgeInsets.all(12),children:[Text('مشاهدة Reels معًا',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),SizedBox(height:8),...rows.take(20).map((raw){final r=Map<String,dynamic>.from(raw as Map);final a=Map<String,dynamic>.from((r['author']??{}) as Map);return ListTile(leading:SNav(url:'${a['avatarUrl']??''}',name:'${a['displayName']??a['username']??''}',size:48),title:Text('${r['title']??r['caption']??'Reels'}',maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text('@${a['username']??''}'),trailing:Icon(Icons.play_circle_fill_rounded),onTap:()async{Navigator.pop(ctx);final url='${r['videoUrl']??''}';final title='${r['title']??r['caption']??'Reels'}';if(widget.peerUserId!=null&&widget.peerUserId!.isNotEmpty)SocketService.i.sendCallReel(to:widget.peerUserId!,url:url,title:title);if(mounted)await _showSharedReel(url,title:title);});})])));
    }catch(e){if(mounted)toast(context,'تعذّر تحميل الريلز');}
  }

  Widget _video(Participant p){
    VideoTrack? t;
    for(final pub in p.videoTrackPublications){if(pub.track is VideoTrack&&!pub.muted&&!pub.isScreenShare){t=pub.track as VideoTrack;break;}}
    return t==null?Container(color:Colors.black,alignment:Alignment.center,child:CircleAvatar(radius:42,child:Text(p.name.isNotEmpty?p.name[0].toUpperCase():'S',style:const TextStyle(fontSize:32)))):ClipRRect(borderRadius:BorderRadius.circular(18),child:VideoTrackRenderer(t));
  }
  Widget _callButton({required IconData icon, required VoidCallback onTap, bool danger=false, bool active=true, String? label}) => Column(mainAxisSize:MainAxisSize.min,children:[Material(color:danger?Colors.redAccent.withValues(alpha: .95):Colors.white.withValues(alpha: active ? .14 : .07),shape:const CircleBorder(),child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:SizedBox(width:58,height:58,child:Icon(icon,color:Colors.white,size:24)))),if(label!=null)Padding(padding:const EdgeInsets.only(top:6),child:Text(label,style:const TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w700)))]);

  @override Widget build(BuildContext context){
    final rem=room.remoteParticipants.values.toList(); final local=room.localParticipant;
    return Scaffold(
      backgroundColor:Colors.black,
      body:error!=null?Center(child:Container(margin:const EdgeInsets.all(24),padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(24)),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.call_end_rounded,color:Colors.white70,size:48),const SizedBox(height:12),Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white)),const SizedBox(height:16),FilledButton(onPressed:_connect,child:const Text('إعادة الاتصال'))]))):Stack(children:[
        Positioned.fill(child:rem.isNotEmpty?_video(rem.first):Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF151A2A),Color(0xFF05060A)])),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:112,height:112,decoration:BoxDecoration(shape:BoxShape.circle,gradient:SN.grad,boxShadow:const [BoxShadow(color:Colors.black54,blurRadius:35,spreadRadius:6)]),padding:const EdgeInsets.all(4),child:CircleAvatar(backgroundColor:Colors.black,child:Text(widget.title.isNotEmpty?widget.title[0].toUpperCase():'S',style:const TextStyle(color:Colors.white,fontSize:42,fontWeight:FontWeight.w900)))),const SizedBox(height:18),Text(widget.title,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(connected?'في انتظار اتصال الطرف الآخر…':'جاري الاتصال…',style:const TextStyle(color:Colors.white60))]))),
        Positioned(top:MediaQuery.of(context).padding.top+12,left:16,right:16,child:Row(children:[Material(color:Colors.black.withValues(alpha: .38),shape:const CircleBorder(),child:IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.arrow_back_rounded,color:Colors.white))),const SizedBox(width:10),Expanded(child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),decoration:BoxDecoration(color:Colors.black.withValues(alpha: .35),borderRadius:BorderRadius.circular(20)),child:Row(children:[const Icon(Icons.lock_rounded,color:Colors.white54,size:14),const SizedBox(width:7),Expanded(child:Text(widget.videoCall?'مكالمة فيديو مشفرة':'مكالمة صوتية',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))),if(connected)Text(_durationLabel,style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w700,fontFeatures:[FontFeature.tabularFigures()]))])))])),
        if(widget.videoCall&&local!=null)Positioned(right:16,top:MediaQuery.of(context).padding.top+78,width:112,height:158,child:Container(decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white24),boxShadow:const [BoxShadow(color:Colors.black54,blurRadius:18)]),clipBehavior:Clip.antiAlias,child:_video(local))),
        Positioned(left:16,right:16,bottom:MediaQuery.of(context).padding.bottom+18,child:Container(padding:const EdgeInsets.fromLTRB(12,14,12,12),decoration:BoxDecoration(color:Colors.black.withValues(alpha: .62),borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white12)),child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_callButton(icon:micOn?Icons.mic_rounded:Icons.mic_off_rounded,onTap:_mic,active:micOn,label:micOn?'صوت':'مكتوم'),_callButton(icon:speakerOn?Icons.volume_up_rounded:Icons.volume_off_rounded,onTap:_speaker,active:speakerOn,label:'مكبر'),_callButton(icon:Icons.movie_filter_rounded,onTap:_watchReelTogether,label:'Reels معًا'),if(widget.videoCall)_callButton(icon:cameraOn?Icons.videocam_rounded:Icons.videocam_off_rounded,onTap:_camera,active:cameraOn,label:'كاميرا'),_callButton(icon:Icons.call_end_rounded,onTap:()=>Navigator.pop(context),danger:true,label:'إنهاء')]))),
      ]),
    );
  }
  @override void dispose(){_durationTimer?.cancel();_finishCallLog();_reelSub?.cancel();room.removeListener(_changed);room.disconnect();room.dispose();super.dispose();}
}

class LivePage extends StatefulWidget {
  const LivePage({super.key});
  @override State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late Future<List<dynamic>> _future;
  Timer? _liveTimer;
  String liveFilter = 'رائج';
  @override void initState() { super.initState(); _future = Api.live(); _liveTimer = Timer.periodic(const Duration(seconds: 8), (_) { if(mounted) setState(()=>_future=Api.live()); }); }
  @override void dispose() { _liveTimer?.cancel(); super.dispose(); }

  Future<void> _start() async {
    final t=TextEditingController(); String category='عام'; String privacy='عام';
    final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      decoration: BoxDecoration(color:SN.bg1,borderRadius:const BorderRadius.vertical(top:Radius.circular(30)),border:Border.all(color:SN.strokeSoft)),
      child: SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,12,20,20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:SN.strokeSoft,borderRadius:BorderRadius.circular(4)))), const SizedBox(height:16),
        Row(children:[Container(width:46,height:46,decoration:BoxDecoration(gradient:SN.grad,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.live_tv_rounded,color:Colors.white)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('ابدأ بثك الآن',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('شارك لحظتك مع مجتمع SocialNova',style:TextStyle(color:SN.textMut,fontSize:12))]))]),
        const SizedBox(height:18),
        TextField(controller:t,autofocus:true,maxLength:80,decoration:const InputDecoration(labelText:'عنوان البث',prefixIcon:Icon(Icons.title_rounded))),
        const SizedBox(height:14), const Text('التصنيف',style:TextStyle(fontWeight:FontWeight.w800)), const SizedBox(height:8),
        SizedBox(height:42,child:ListView(scrollDirection:Axis.horizontal,children:[for(final c in const ['عام','ألعاب','موسيقى','دردشة','رياضة'])Padding(padding:const EdgeInsets.only(left:8),child:ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setSheet(()=>category=c)))])),
        const SizedBox(height:12), const Text('الخصوصية',style:TextStyle(fontWeight:FontWeight.w800)), const SizedBox(height:8),
        Row(children:[Expanded(child:_liveOption('عام','الجميع',Icons.public_rounded,privacy=='عام',()=>setSheet(()=>privacy='عام'))),const SizedBox(width:10),Expanded(child:_liveOption('خاص','بالدعوة',Icons.lock_outline_rounded,privacy=='خاص',()=>setSheet(()=>privacy='خاص')))]),
        const SizedBox(height:14),
        Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:SN.bg2,borderRadius:BorderRadius.circular(17),border:Border.all(color:SN.strokeSoft)),child:Row(children:[Icon(Icons.tips_and_updates_outlined,color:SN.cyan),const SizedBox(width:10),Expanded(child:Text('يمكنك دعوة ضيف، مشاركة البث وإضافة تحديات وهدايا من داخل غرفة البث.',style:TextStyle(color:SN.textSec,fontSize:11,height:1.4)))])),
        const SizedBox(height:16), SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:()=>Navigator.pop(ctx,true),icon:const Icon(Icons.videocam_rounded),label:const Text('بدء البث',style:TextStyle(fontWeight:FontWeight.w900))))
      ])))
    )));
    if(ok==true&&t.text.trim().isNotEmpty){try{final room=await Api.createLive(t.text.trim());if(!mounted)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>LiveRoomPage(title:'${room['title']}',roomName:'${room['roomName']}',roomId:'${room['id']??''}',hostId:'${Api.me?['id']??''}')));}catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}}
    t.dispose();
  }

  Widget _liveOption(String title,String sub,IconData icon,bool selected,VoidCallback tap)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(17),child:AnimatedContainer(duration:const Duration(milliseconds:160),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:selected?SN.red.withValues(alpha: .10):SN.bg2,borderRadius:BorderRadius.circular(17),border:Border.all(color:selected?SN.red:SN.strokeSoft)),child:Row(children:[Icon(icon,color:selected?SN.red:SN.textMut),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),Text(sub,style:TextStyle(color:SN.textMut,fontSize:10))])])));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SN.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            NovaTabs<String>(
              values: const ['رائج', 'الجديد'],
              labels: const ['رائج', 'الجديد'],
              selected: liveFilter,
              onChanged: (v) => setState(() => liveFilter = v),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: RefreshIndicator(
                color: SN.violet,
                onRefresh: () async => setState(() => _future = Api.live()),
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
                    if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
                    return _liveBody(snap.data ?? []);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SN.red,
        onPressed: _start,
        icon: const Icon(Icons.videocam_rounded, color: Colors.white),
        label: const Text('بث مباشر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.sensors_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('البث المباشر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('شاهد وتفاعل مع اللحظات الآن', style: TextStyle(color: SN.textMut, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: () => setState(() => _future = Api.live()),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );

  Widget _heroBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: SN.grad,
          borderRadius: BorderRadius.circular(NovaTokens.rXl),
          boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .20), blurRadius: 24)],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لحظات حية', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('تفاعل، أرسل هدايا وشارك أصدقاءك', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            FilledButton(
              onPressed: _start,
              style: FilledButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('ابدأ', style: TextStyle(color: SN.violet, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );

  Widget _emptyRooms() => ListView(
        children: [
          const SizedBox(height: 90),
          Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(28)),
            child: Column(
              children: [
                const Icon(Icons.sensors_off_outlined, color: Colors.white, size: 46),
                const SizedBox(height: 12),
                const Text('لا يوجد بث مباشر الآن', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('كن أول من يبدأ البث ويصنع اللحظة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _start, child: const Text('ابدأ أول بث')),
              ],
            ),
          ),
        ],
      );

  /// Ordering is client-side only: the API already returns live rooms by
  /// featured priority, so the tabs re-rank what is loaded without a refetch.
  List<Map<String, dynamic>> _ordered(List<dynamic> raw) {
    final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (liveFilter == 'الجديد') {
      rows.sort((a, b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    } else {
      rows.sort((a, b) => (int.tryParse('${b['viewerCount'] ?? 0}') ?? 0).compareTo(int.tryParse('${a['viewerCount'] ?? 0}') ?? 0));
    }
    return rows;
  }

  /// Opens the reels-style live viewer: swipe up/down to move from one live
  /// to the next without going back to the discovery grid.
  void _watchRooms(List<Map<String, dynamic>> rooms, int index) {
    if (rooms.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveSwipeViewer(rooms: rooms, startIndex: index.clamp(0, rooms.length - 1)),
      ),
    );
  }

  Widget _liveBody(List<dynamic> raw) {
    final rooms = _ordered(raw);
    if (rooms.isEmpty) return _emptyRooms();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
      children: [
        _heroBanner(),
        NovaSectionTitle(title: 'مذيعون نشطون الآن', action: 'تحديث', onAction: () => setState(() => _future = Api.live())),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (c, i) {
              final r = rooms[i];
              final host = Map<String, dynamic>.from((r['host'] ?? {}) as Map);
              final name = '${host['displayName'] ?? host['username'] ?? ''}';
              return GestureDetector(
                onTap: () => _watchRooms(rooms, i),
                child: SizedBox(
                  width: 60,
                  child: Column(
                    children: [
                      SNav(url: '${host['avatarUrl'] ?? ''}', name: name, size: 50, ring: true),
                      const SizedBox(height: 5),
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: SN.textSec)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const NovaSectionTitle(title: 'بث مباشر الآن'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .80,
          children: [
            for (var i = 0; i < rooms.length; i++)
              GestureDetector(
                onLongPress: () => shareSocialItemToChats(
                  context,
                  title: 'مشاركة بث مباشر',
                  body: '[live_share]${rooms[i]['roomName']}|${rooms[i]['title']}',
                  icon: Icons.live_tv_rounded,
                ),
                child: NovaLiveTile(
                  title: '${rooms[i]['title'] ?? 'بث مباشر'}',
                  hostName: '${(rooms[i]['host'] is Map ? (rooms[i]['host'] as Map)['displayName'] : '') ?? ''}',
                  hostAvatar: '${(rooms[i]['host'] is Map ? (rooms[i]['host'] as Map)['avatarUrl'] : '') ?? ''}',
                  viewers: int.tryParse('${rooms[i]['viewerCount'] ?? 0}') ?? 0,
                  gradientSeed: i,
                  onTap: () => _watchRooms(rooms, i),
                ),
              ),
          ],
        ),
      ],
    );
  }

}
/// Reels-style navigation between live rooms: a vertical [PageView] where each
/// page is a full [LiveRoomPage]. Swiping up/down moves to the next/previous
/// live; there is no "back to grid" step. Pages off-screen are disposed so only
/// the visible room keeps a LiveKit connection.
class LiveSwipeViewer extends StatefulWidget {
  const LiveSwipeViewer({super.key, required this.rooms, this.startIndex = 0});
  final List<Map<String, dynamic>> rooms;
  final int startIndex;

  @override
  State<LiveSwipeViewer> createState() => _LiveSwipeViewerState();
}

class _LiveSwipeViewerState extends State<LiveSwipeViewer> {
  late final PageController _controller;
  late int _index;
  bool _showHint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _controller = PageController(initialPage: widget.startIndex);
    _hintTimer = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _showHint = false); });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _page(Map<String, dynamic> r) {
    final host = Map<String, dynamic>.from((r['host'] ?? {}) as Map);
    return LiveRoomPage(
      key: ValueKey('live-${r['roomName']}'),
      title: '${r['title'] ?? 'بث مباشر'}',
      roomName: '${r['roomName']}',
      hostId: '${host['id'] ?? ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: widget.rooms.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _page(widget.rooms[i]),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showHint ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(20)),
                      child: Text('${_index + 1} / ${widget.rooms.length}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.swipe_vertical_rounded, color: Colors.white70, size: 15),
                        SizedBox(width: 6),
                        Text('اسحب للأعلى للبث التالي', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  dynamic _tapSub;
  dynamic _liveMuteSub;
  dynamic _liveRemovedSub;
  dynamic _liveMutedNoticeSub;
  dynamic _liveCommentSub;
  dynamic _livePinSub;
  dynamic _liveDeleteSub;
  dynamic _liveModeratorSub;
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
  int _tapCount = 0;
  int _giftCount = 0;
  int _giftScore = 0;
  bool _paused = false;
  String _liveEffect = 'none';
  bool _pauseBusy = false;
  int _scoreB = 0;
  Timer? _giftFxTimer;
  /// Pending gift animations, played one after another by the Gift Manager.
  final List<Map<String, dynamic>> _giftQueue = [];
  /// Alert banner shown when a gift arrives: «خالد أرسل تاجاً ملكياً». 
  Map<String, dynamic>? _giftAlert;
  Timer? _giftAlertTimer;
  Map<String,dynamic>? _hostProfile;
  /// Bumped for every gift so the effect widget is rebuilt fresh (and its
  /// animation restarts) even when the same gift arrives twice in a combo.
  int _giftFxSeq = 0;
  /// Viewer count persisted on the server, merged with the LiveKit estimate.
  int _serverViewers = 0;
  /// Drives the rising-hearts layer; a burst counter keeps the painter cheap.
  final ValueNotifier<int> _hearts = ValueNotifier<int>(0);
  Map<String, dynamic>? _replyingTo;
  String? _pinnedCommentId;
  final Set<String> _moderatorIds = <String>{};
  final Set<String> _mutedIds = <String>{};
  String _moderatorRole = '';
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
    _liveCommentSub = SocketService.i.liveComments.listen((m) { if (!mounted) return; final id='${m['id'] ?? ''}'; setState(() { chat.removeWhere((x) => '${x['id'] ?? ''}' == id && id.isNotEmpty); chat.add(m); }); });
    _livePinSub = SocketService.i.liveCommentPins.listen((m) { if (!mounted) return; setState(() { _pinnedCommentId = m['pinned'] == false ? null : '${m['commentId'] ?? ''}'; for (final x in chat) { x['pinned'] = '${x['id']}' == _pinnedCommentId; } }); });
    _liveDeleteSub = SocketService.i.liveCommentDeletes.listen((m) { if (!mounted) return; final id='${m['commentId'] ?? ''}'; setState(() { chat.removeWhere((x) => '${x['id'] ?? ''}' == id); }); });
    _liveModeratorSub = SocketService.i.liveModerators.listen((m) { if (!mounted) return; final id='${m['userId'] ?? ''}'; setState(() { if ('${m['action']}' == 'removed') _moderatorIds.remove(id); else _moderatorIds.add(id); }); });
    _liveMuteSub = SocketService.i.liveMuted.listen((m) { if (!mounted) return; final id='${m['userId'] ?? ''}'; if (id.isEmpty) return; if (m['value'] == false) { setState(() => _mutedIds.remove(id)); } else { setState(() => _mutedIds.add(id)); final myId='${Api.me?['id']}'; if (id == myId) toast(context, 'تم كتمك في هذا البث بواسطة الإشراف'); } });
    _liveRemovedSub = SocketService.i.liveRemoved.listen((m) { if (!mounted) return; if ('${m['userId'] ?? ''}' == '${Api.me?['id']}') { toast(context, 'تم إخراجك من البث'); Navigator.maybePop(context); } });
    _liveMutedNoticeSub = SocketService.i.liveMutedNotice.listen((_) { if (mounted) toast(context, 'أنت مكتوم في هذا البث ولا يمكنك التعليق'); });
    _loadLiveComments();
    _loadLiveModerators();
    _loadLiveStats();
    _tapSub = SocketService.i.liveTaps.listen((m) { if (!mounted) return; if ('${m['userId']}' == '${Api.me?['id']}') return; setState(() => _tapCount++); });
    _giftSub = SocketService.i.liveGifts.listen((m) {
      if (!mounted) return;
      final gift = m['gift'] is Map ? Map<String, dynamic>.from(m['gift'] as Map) : <String, dynamic>{};
      final effect='${gift['effectKey'] ?? 'pulse'}';
      final resolved = NovaGiftCatalog.resolve(gift);
      playGiftSound(gift['soundKey'] == null ? '' : '${gift['soundKey']}', resolved.tier);
      final value = m['coins'] is num ? (m['coins'] as num).toInt() : (gift['priceCoins'] is num ? (gift['priceCoins'] as num).toInt() : 0);
      setState(() { _giftCount++; _giftScore += value; if (_challengeId != null) _scoreA += value; chat.add({'body': '🎁 ${gift['emoji'] ?? '🎁'} ${gift['name'] ?? 'هدية'}', 'displayName': '${m['username'] ?? ''}'}); });
      _enqueueGift({...gift, 'sender': '${m['username'] ?? ''}', 'coins': value, 'effectKey': effect});
      _showGiftAlert('${m['username'] ?? ''}', resolved.name, resolved.emoji);
    });
    if (widget.hostId != null && widget.hostId!.isNotEmpty) {
      Api.profile(widget.hostId!).then((v) { if (mounted) setState(() => _hostProfile = v); }).catchError((_) {});
    }
    _connectLiveKit();
  }

  Future<void> _loadLiveComments() async {
    if (widget.roomId == null || widget.roomId!.isEmpty) return;
    try { final rows = await Api.liveComments(widget.roomId!); if (mounted) setState(() { chat.clear(); chat.addAll(rows.map((e) => Map<String,dynamic>.from(e as Map))); final pinned = chat.where((x) => x['pinned'] == true).map((x) => '${x['id']}').toList(); _pinnedCommentId = pinned.isEmpty ? null : pinned.first; }); } catch (_) {}
  }
  /// Restores the room's tap/gift totals so leaving and re-entering does not
  /// reset them.
  Future<void> _loadLiveStats() async {
    try {
      final s = await Api.liveStats(widget.roomName);
      if (!mounted) return;
      setState(() {
        _tapCount = (s['tapCount'] as num?)?.toInt() ?? _tapCount;
        _giftCount = (s['giftCount'] as num?)?.toInt() ?? _giftCount;
        _giftScore = (s['giftScore'] as num?)?.toInt() ?? _giftScore;
        _serverViewers = (s['viewerCount'] as num?)?.toInt() ?? _serverViewers;
      });
    } catch (_) {}
  }

  /// Admin/live.manage growth tool: raise the room's viewer counter so it
  /// ranks higher in discovery.
  Future<void> _boostViewers() async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.isEmpty) return;
    final controller = TextEditingController(text: '1000');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دعم المشاهدين'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد المشاهدين')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())), child: const Text('تطبيق')),
        ],
      ),
    );
    controller.dispose();
    if (n == null || n <= 0 || !mounted) return;
    try {
      await Api.adminBoostContent('LIVE', roomId, viewers: n);
      if (mounted) setState(() => _serverViewers = n);
      toast(context, 'تم رفع عدد المشاهدين إلى $n');
    } catch (e) {
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Top supporters (gifters) and top tappers for this room, in order.
  Future<void> _showTopSheet() async {
    Map<String, dynamic> data = const {};
    try { data = await Api.liveTop(widget.roomName); } catch (_) {}
    if (!mounted) return;
    final gifters = (data['topGifters'] as List?) ?? const [];
    final tappers = (data['topTappers'] as List?) ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.fromLTRB(18, 4, 18, 8), child: Text('لوحة الدعم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              const _BoardTitle(icon: Icons.card_giftcard_rounded, color: Colors.amberAccent, text: 'أفضل الداعمين بالهدايا'),
              if (gifters.isEmpty) const _BoardEmpty(text: 'لا توجد هدايا بعد'),
              for (var i = 0; i < gifters.length; i++) _BoardRow(index: i, row: Map<String, dynamic>.from(gifters[i] as Map), trailing: '${(gifters[i] as Map)['coins'] ?? 0} NVC'),
              const SizedBox(height: 10),
              const _BoardTitle(icon: Icons.touch_app_rounded, color: SN.pink, text: 'أكثر المكبّسين'),
              if (tappers.isEmpty) const _BoardEmpty(text: 'لا يوجد تكبيس بعد'),
              for (var i = 0; i < tappers.length; i++) _BoardRow(index: i, row: Map<String, dynamic>.from(tappers[i] as Map), trailing: '${(tappers[i] as Map)['taps'] ?? 0} ❤'),
            ])),
          ]),
        ),
      ),
    );
  }

  Future<void> _loadLiveModerators() async {
    if (widget.roomId == null || widget.roomId!.isEmpty) return;
    try { final rows = await Api.liveModerators(widget.roomId!); if (mounted) setState(() { _moderatorIds..clear()..addAll(rows.map((e) => '${(e as Map)['userId']}')); final me=rows.cast<dynamic>().map((e)=>Map<String,dynamic>.from(e as Map)).where((e)=>'${e['userId']}'=='${Api.me?['id']}').toList(); _moderatorRole = me.isEmpty ? '' : '${me.first['role'] ?? ''}'; }); } catch (_) {}
  }
  // Live staff capabilities (see backend LIVE_ROLE_PERMISSIONS). A Moderator
  // can pin/mute/remove; an Assistant can only delete and report.
  bool get _isFullModerator => _isHost || _moderatorRole == 'MODERATOR';
  bool get _canPinComments => _isFullModerator;
  bool get _canDeleteComments => _isHost || _moderatorRole.isNotEmpty;
  bool get _canMuteViewer => _isFullModerator;
  bool get _canRemoveViewer => _isFullModerator;
  bool get _canReportComment => _isHost || _moderatorRole.isNotEmpty;

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
      NovaAudio.i.playSfx('join');
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

  Future<void> _toggleLivePause() async {
    if (!_isHost || widget.roomId == null || _pauseBusy) return;
    setState(() => _pauseBusy = true);
    try {
      if (!_paused) {
        await room.localParticipant?.setCameraEnabled(false);
        await room.localParticipant?.setMicrophoneEnabled(false);
        await Api.pauseLive(widget.roomId!);
        if (mounted) setState(() { _paused = true; cameraOn = false; micOn = false; });
      } else {
        await Api.resumeLive(widget.roomId!);
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) setState(() { _paused = false; cameraOn = true; micOn = true; });
      }
    } catch (e) { if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _pauseBusy = false); }
  }

  void _chooseLiveEffect() async {
    final picked = await showModalBottomSheet<String>(context: context, backgroundColor: SN.bg1, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ListTile(title: Text('مؤثرات سينمائية للبث', style: TextStyle(fontWeight: FontWeight.w900))),
      for (final x in const [
        ['none','طبيعي',Icons.videocam_rounded],['cinema','سينمائي',Icons.movie_filter_rounded],['noir','Noir',Icons.contrast_rounded],['dream','Dream',Icons.auto_awesome_rounded],['warm','Warm',Icons.wb_sunny_rounded],['cool','Cool',Icons.ac_unit_rounded]
      ]) ListTile(leading: Icon(x[2] as IconData, color: SN.violet), title: Text(x[1] as String), trailing: _liveEffect == x[0] ? const Icon(Icons.check_circle_rounded, color: SN.violet) : null, onTap: () => Navigator.pop(ctx, x[0] as String)),
    ])));
    if (picked != null && mounted) setState(() => _liveEffect = picked);
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
    SocketService.i.sendLiveChat(widget.roomName, text, replyToId: '${_replyingTo?['id'] ?? ''}');
    ctrl.clear();
    if (mounted) setState(() => _replyingTo = null);
  }
  void _replyTo(Map<String,dynamic> comment) { setState(() => _replyingTo = comment); }
  Future<void> _deleteComment(Map<String,dynamic> comment) async {
    final id='${comment['id'] ?? ''}'; if(id.isEmpty)return;
    try { await Api.deleteLiveComment(widget.roomId ?? '', id); } catch (_) { SocketService.i.deleteLiveComment(widget.roomName, id); }
  }
  Future<void> _pinComment(Map<String,dynamic> comment) async {
    final id='${comment['id'] ?? ''}'; if(id.isEmpty)return;
    try { await Api.pinLiveComment(widget.roomId ?? '', id); } catch (_) { SocketService.i.pinLiveComment(widget.roomName, id); }
  }
  void _commentActions(Map<String,dynamic> comment) {
    final author = comment['author'] is Map ? Map<String,dynamic>.from(comment['author'] as Map) : <String,dynamic>{};
    final authorId = '${comment['authorId'] ?? author['id'] ?? ''}';
    final mine = authorId == '${Api.me?['id']}';
    final isMuted = _mutedIds.contains(authorId);
    showModalBottomSheet(context:context,backgroundColor:SN.bg1,showDragHandle:true,builder:(ctx)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.reply_rounded,color:SN.cyan),title:const Text('الرد على التعليق'),onTap:(){Navigator.pop(ctx);_replyTo(comment);}),
      if(!mine && authorId.isNotEmpty) ListTile(leading:const Icon(Icons.person_outline,color:SN.violet),title:const Text('عرض الملف الشخصي'),onTap:(){Navigator.pop(ctx);openProfile(context, authorId);}),
      if(_canPinComments)ListTile(leading:Icon(comment['pinned']==true?Icons.push_pin:Icons.push_pin_outlined,color:SN.gold),title:Text(comment['pinned']==true?'إلغاء تثبيت التعليق':'تثبيت التعليق'),onTap:(){Navigator.pop(ctx);_pinComment(comment);}),
      if(_canDeleteComments||mine)ListTile(leading:const Icon(Icons.delete_outline,color:Colors.redAccent),title:const Text('حذف التعليق'),onTap:(){Navigator.pop(ctx);_deleteComment(comment);}),
      if(_canMuteViewer && !mine && authorId.isNotEmpty)
        ListTile(leading:Icon(isMuted?Icons.volume_up_rounded:Icons.volume_off_rounded,color:Colors.orangeAccent),title:Text(isMuted?'إلغاء كتم المستخدم':'كتم المستخدم'),onTap:(){Navigator.pop(ctx);_muteUser(authorId, !isMuted);}),
      if(_canRemoveViewer && !mine && authorId.isNotEmpty)
        ListTile(leading:const Icon(Icons.person_remove_alt_1_rounded,color:Colors.redAccent),title:const Text('إخراج من البث'),onTap:(){Navigator.pop(ctx);_removeUser(authorId);}),
      if(_canReportComment && !mine)
        ListTile(leading:const Icon(Icons.flag_outlined,color:Colors.redAccent),title:const Text('إبلاغ عن التعليق'),onTap:(){Navigator.pop(ctx);_reportComment(comment);}),
    ])));
  }

  void _muteUser(String userId, bool value) {
    SocketService.i.muteLiveUser(widget.roomName, userId, value: value);
    if (mounted) setState(() { if (value) { _mutedIds.add(userId); } else { _mutedIds.remove(userId); } });
    toast(context, value ? 'تم كتم المستخدم في البث' : 'تم إلغاء الكتم');
  }

  void _removeUser(String userId) {
    SocketService.i.removeLiveUser(widget.roomName, userId);
    toast(context, 'تم إخراج المستخدم من البث');
  }

  void _reportComment(Map<String,dynamic> comment) {
    final id = '${comment['id'] ?? ''}';
    if (id.isEmpty) return;
    Api.reportLiveComment(id, 'إبلاغ من مشرف البث').catchError((_) {});
    toast(context, 'تم إرسال البلاغ للإدارة 🛡️');
  }

  Future<void> _manageModerators() async {
    if (!_isHost || widget.roomId == null || widget.roomId!.isEmpty) return;
    try {
      final followers = await Api.liveFollowersForModeration(widget.roomId!);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: SN.bg1,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(alignment: AlignmentDirectional.centerStart, child: Text('المشرفون والمساعدون', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(alignment: AlignmentDirectional.centerStart, child: Text('اختر أشخاصًا من متابعيك وحدد دورهم في إدارة التعليقات.', style: TextStyle(color: Colors.white60))),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: followers.length,
                    itemBuilder: (_, i) {
                      final u = Map<String, dynamic>.from(followers[i] as Map);
                      final id = '${u['id'] ?? ''}';
                      final selected = _moderatorIds.contains(id);
                      return Card(
                        color: Colors.white.withValues(alpha: .04),
                        child: ListTile(
                          leading: SNav(url: '${u['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? u['username'] ?? ''}', size: 44, ring: selected),
                          title: Text('${u['displayName'] ?? u['username'] ?? ''}'),
                          subtitle: Text('@${u['username'] ?? ''}'),
                          trailing: selected
                              ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () async { await Api.removeLiveModerator(widget.roomId!, id); if (mounted) setState(() => _moderatorIds.remove(id)); })
                              : PopupMenuButton<String>(
                                  icon: const Icon(Icons.shield_outlined, color: SN.cyan),
                                  onSelected: (role) async { await Api.addLiveModerator(widget.roomId!, id, role: role); if (mounted) setState(() => _moderatorIds.add(id)); },
                                  itemBuilder: (_) => const [PopupMenuItem(value: 'MODERATOR', child: Text('مشرف')), PopupMenuItem(value: 'ASSISTANT', child: Text('مساعد'))],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) toast(context, 'تعذر تحميل المتابعين');
    }
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
    _liveCommentSub?.cancel(); _livePinSub?.cancel(); _liveDeleteSub?.cancel(); _liveModeratorSub?.cancel();
    _liveMuteSub?.cancel(); _liveRemovedSub?.cancel(); _liveMutedNoticeSub?.cancel();
    _giftSub?.cancel();
    _tapSub?.cancel();
    _giftFxTimer?.cancel();
    _giftAlertTimer?.cancel();
    ctrl.dispose();
    _hearts.dispose();
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
        color: const Color(0xFF111318),
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 42,
          backgroundColor: Colors.white12,
          child: Text(
            participant.name.isNotEmpty ? participant.name.substring(0, 1).toUpperCase() : 'S',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
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

  Widget _liveParticipantTile(Participant participant, int index, {bool compact = false}) {
    final isLocal = participant == room.localParticipant;
    final name = isLocal
        ? '${Api.me?['displayName'] ?? Api.me?['username'] ?? 'أنت'}'
        : participant.name.isEmpty ? 'مشارك' : participant.name;
    final labels = const ['A1', 'B2', 'A2', 'C1'];
    final label = labels[index % labels.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        _videoForParticipant(participant),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: .62)],
                stops: const [.52, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: compact ? 8 : 12,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: index.isEven ? const Color(0xFFB77916) : const Color(0xFF31558E),
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
            ),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ),
        Positioned(
          bottom: compact ? 8 : 12,
          left: 8,
          right: 8,
          child: Row(
            children: [
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isLocal && micOn ? Icons.mic_rounded : Icons.mic_off_rounded, color: Colors.white70, size: 13),
                  const SizedBox(width: 3),
                  Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoStage() {
    final remotes = _remoteParticipants;
    final local = room.localParticipant;
    final participants = <Participant>[];
    if (_isHost && local != null) participants.add(local);
    participants.addAll(remotes.take(3));

    if (participants.isEmpty) {
      // When the host has uploaded a stage cover image, show it behind the
      // "waiting" state instead of a plain black screen.
      final cover = (_liveCoverImage ?? '').trim();
      return Positioned.fill(
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Stack(fit: StackFit.expand, children: [
            if (cover.isNotEmpty)
              ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.darken),
                child: Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 56, backgroundColor: Colors.white10, child: SNav(url: '${_hostProfile?['avatarUrl'] ?? ''}', name: '${_hostProfile?['displayName'] ?? widget.title}', size: 104)),
            const SizedBox(height: 14),
            const Text('جاري انتظار الفيديو…', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      );
    }

    if (participants.length == 1) {
      return Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque,onTap: _sendScreenTap,onDoubleTap: _sendScreenTap, child: _liveParticipantTile(participants.first, 0)));
    }

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final ratio = (width / math.max(1, height / 2)).clamp(.48, .70);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _sendScreenTap,
        onDoubleTap: _sendScreenTap,
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.only(top: 72),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: participants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
              childAspectRatio: ratio,
            ),
            itemBuilder: (_, i) => _liveParticipantTile(participants[i], i, compact: true),
          ),
        ),
      ),
    );
  }

  void _sendScreenTap() {
    if (!connected) return;
    setState(() => _tapCount++);
    _hearts.value++;
    NovaAudio.i.playSfx('tap');
    SocketService.i.sendLiveTap(widget.roomName);
  }

  Widget _glassButton({required IconData icon, required VoidCallback onTap, bool active = false, double size = 44}) =>
      NovaGlassIcon(icon: icon, onTap: onTap, active: active, size: size, iconSize: 21);

  Widget _hostHeader() {
    final viewers = _remoteParticipants.length + (connected ? 1 : 0);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Row(children: [
        Flexible(
          child: GestureDetector(
            onTap: widget.hostId == null || widget.hostId!.isEmpty ? null : () => openProfile(context, widget.hostId!),
            child: NovaGlass(
              radius: NovaTokens.rPill,
              padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 11, 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SNav(url: '${_hostProfile?['avatarUrl'] ?? ''}', name: '${_hostProfile?['displayName'] ?? widget.title}', size: 34, ring: true),
                const SizedBox(width: 7),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text('${_hostProfile?['displayName'] ?? widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
                      const SizedBox(width: 4),
                      VerifiedBadge(tier: '${_hostProfile?['verificationTier'] ?? (_hostProfile?['isVerified'] == true ? 'NORMAL' : 'NONE')}', size: 13),
                    ]),
                    Text('@${_hostProfile?['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 9)),
                  ]),
                ),
                if (!_isHost && _hostProfile != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(color: SN.red, borderRadius: BorderRadius.circular(NovaTokens.rPill)),
                    child: InkWell(
                      onTap: () async {
                        try {
                          final r = await Api.follow(widget.hostId!);
                          if (!mounted) return;
                          setState(() => _hostProfile = {...?_hostProfile, 'followingMe': r['following'] == true, 'followRequested': r['requested'] == true});
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(NovaTokens.rPill),
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6), child: Text('متابعة +', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const NovaLiveBadge(),
        ...[
          const SizedBox(width: 6),
          NovaStatPill(
            icon: Icons.visibility_rounded,
            text: '${math.max(viewers, _serverViewers) > 0 ? math.max(viewers, _serverViewers) : viewers}',
            iconColor: Colors.white70,
            onTap: _showTopSheet,
          ),
        ],
        const Spacer(),
        NovaGlassIcon(
          icon: Icons.ios_share_rounded,
          size: 36,
          tooltip: 'مشاركة البث',
          onTap: () => shareSocialItemToChats(context, title: 'مشاركة البث', body: '[live_share]${widget.roomName}|${widget.title}', icon: Icons.sensors_rounded),
        ),
        if (widget.roomId != null) ...[
          const SizedBox(width: 6),
          NovaGlassIcon(
            icon: Icons.stop_circle_outlined,
            size: 36,
            tooltip: 'إنهاء البث',
            tint: ending ? Colors.white24 : SN.red.withValues(alpha: .86),
            onTap: ending ? null : _endLive,
          ),
        ],
      ]),
    );
  }

  Widget _battleBar() {
    if (_challengeId == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + 104,
      left: 0,
      right: 0,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF72B78), Color(0xFF13D9E8)]),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        child: Row(children: [
          Expanded(child: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${_scoreA}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), borderRadius: BorderRadius.circular(18)), child: const Text('تحدي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
          Expanded(child: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${_scoreB}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
  }

  Widget _tapHud() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 58,
      left: 14,
      right: 14,
      child: Row(
        children: [
          NovaStatPill(
            icon: Icons.touch_app_rounded,
            text: 'تكبيس $_tapCount',
            gradient: const LinearGradient(colors: [Color(0xFFFF2F78), Color(0xFFFF7A3D)]),
            onTap: _sendScreenTap,
          ),
          const SizedBox(width: 7),
          NovaStatPill(icon: Icons.card_giftcard_rounded, text: '$_giftCount', iconColor: Colors.amberAccent),
          const SizedBox(width: 6),
          NovaStatPill(icon: Icons.stars_rounded, text: '$_giftScore', iconColor: Colors.amberAccent),
          const Spacer(),
          if (_challengeId != null)
            NovaStatPill(icon: Icons.sports_esports_rounded, text: '$_scoreA × $_scoreB'),
        ],
      ),
    );
  }

  Widget _commentRail() {
    return Positioned(
      left: 10, right: 10, bottom: 96,
      child: SizedBox(height: 225, child: ListView.builder(
        reverse: true, itemCount: math.min(chat.length, 45),
        itemBuilder: (_, i) {
          final m = chat[chat.length - 1 - i];
          final body = '${m['body'] ?? ''}';
          final id = '${m['id'] ?? ''}';
          final author = m['author'] is Map ? Map<String,dynamic>.from(m['author'] as Map) : <String,dynamic>{};
          final username = '${author['displayName'] ?? m['displayName'] ?? m['username'] ?? ''}';
          final avatar = '${author['avatarUrl'] ?? m['avatarUrl'] ?? ''}';
          final reply = '${m['replyToName'] ?? ''}';
          final pinned = m['pinned'] == true;
          return NovaCommentTile(
            username: username,
            avatarUrl: avatar,
            body: body,
            pinned: pinned,
            replyToName: reply,
            onTap: () => _replyTo(m),
            onLongPress: id.isEmpty ? null : () => _commentActions(m),
            onAvatarTap: author['id'] == null ? null : () => openProfile(context, '${author['id']}'),
            onReply: () => _replyTo(m),
          );
        },
      )),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: SN.violet.withValues(alpha: .24), borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
                    child: Row(children: [
                      const Icon(Icons.reply_rounded, size: 14, color: SN.cyan),
                      const SizedBox(width: 6),
                      Expanded(child: Text('الرد على ${_replyingTo?['displayName'] ?? _replyingTo?['author']?['displayName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10))),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white54), onPressed: () => setState(() => _replyingTo = null)),
                    ]),
                  ),
                NovaGlass(
                  radius: NovaTokens.rPill,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  blur: 16,
                  child: TextField(
                    controller: ctrl,
                    enabled: !_mutedIds.contains('${Api.me?['id']}'),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(hintText: _mutedIds.contains('${Api.me?['id']}') ? 'أنت مكتوم في هذا البث' : 'اكتب تعليقًا…', hintStyle: const TextStyle(color: Colors.white70), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13)),
                    onSubmitted: (_) => _sendChat(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          NovaStatPill(
            icon: Icons.favorite_rounded,
            text: '$_tapCount',
            iconColor: SN.pink,
            gradient: const LinearGradient(colors: [Color(0xFFFF2F78), Color(0xFFFF7A3D)]),
            onTap: _sendScreenTap,
          ),
          const SizedBox(width: 5),
          _glassButton(icon: Icons.card_giftcard_rounded, onTap: widget.hostId == null || widget.hostId!.isEmpty ? () {} : () => showGiftPicker(context, receiverId: widget.hostId!, receiverName: widget.title, contextType: 'LIVE', contextId: widget.roomName)),
          if (_isHost) ...[
            const SizedBox(width: 5),
            _glassButton(icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded, active: micOn, onTap: _toggleMic),
            const SizedBox(width: 5),
            _glassButton(icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, active: cameraOn, onTap: _toggleCamera),
            const SizedBox(width: 5),
            _glassButton(
              icon: Icons.more_horiz_rounded,
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: SN.bg1,
                showDragHandle: true,
                builder: (_) => SafeArea(child: Wrap(children: [
                  ListTile(leading: const Icon(Icons.flip_camera_android_rounded), title: const Text('تبديل الكاميرا'), onTap: () { Navigator.pop(context); _flipCamera(); }),
                  ListTile(leading: const Icon(Icons.image_outlined), title: const Text('صورة واجهة البث'), onTap: () { Navigator.pop(context); _uploadLiveImage(); }),
                  ListTile(leading: const Icon(Icons.movie_filter_rounded), title: const Text('مؤثرات البث'), onTap: () { Navigator.pop(context); _chooseLiveEffect(); }),
                  ListTile(leading: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded), title: Text(_paused ? 'استئناف البث' : 'إيقاف مؤقت'), onTap: () { Navigator.pop(context); _toggleLivePause(); }),
                  ListTile(leading: Icon(screenOn ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded), title: Text(screenOn ? 'إيقاف مشاركة الشاشة' : 'مشاركة الشاشة'), onTap: () { Navigator.pop(context); _toggleScreenShare(); }),
                  ListTile(leading: const Icon(Icons.shield_rounded, color: SN.cyan), title: const Text('المشرفون والمساعدون'), onTap: () { Navigator.pop(context); _manageModerators(); }),
                  ListTile(leading: const Icon(Icons.sports_esports_rounded), title: Text(_challengeId == null ? 'بدء تحدي' : 'إدارة التحدي'), onTap: () { Navigator.pop(context); if (_challengeId == null) { _startChallenge(); } else { _challengeScore(true); } }),
                  if ((_isHost || Api.can('live.manage')) && widget.roomId != null)
                    ListTile(leading: const Icon(Icons.trending_up_rounded, color: Colors.greenAccent), title: const Text('دعم المشاهدين (إشراف)'), onTap: () { Navigator.pop(context); _boostViewers(); }),
                ])),
              ),
            ),
          ],
          if (!_isHost) ...[
            const SizedBox(width: 5),
            _glassButton(icon: Icons.pan_tool_alt_rounded, onTap: () { SocketService.i.sendLiveChat(widget.roomName, '🙋 طلب الانضمام إلى البث'); toast(context, 'تم إرسال طلب الانضمام للمضيف'); }),
          ],
        ],
      ),
    );
  }

  void _showGiftAlert(String sender, String name, String emoji) {
    if (!mounted) return;
    setState(() => _giftAlert = {'sender': sender, 'name': name, 'emoji': emoji});
    _giftAlertTimer?.cancel();
    _giftAlertTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _giftAlert = null);
    });
  }

  /// «خالد أرسل تاجاً ملكياً» 👑 — appears top-centre on every gift.
  Widget _giftAlertBanner() {
    final a = _giftAlert;
    if (a == null) return const SizedBox.shrink();
    final sender = '${a['sender']}'.isEmpty ? 'مستخدم' : '${a['sender']}';
    return Positioned(
      top: MediaQuery.of(context).padding.top + 132,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: .9 + .1 * t, child: child)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2B1B00), Color(0xFF4A2E00)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: .8), width: 1.4),
              boxShadow: [BoxShadow(color: Colors.amberAccent.withValues(alpha: .28), blurRadius: 18)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${a['emoji']}', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 9),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: sender, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900)),
                    const TextSpan(text: ' أرسل ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    TextSpan(text: '${a['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _giftOverlay() {
    final g = _giftFx;
    if (g == null) return const SizedBox.shrink();
    final gift = NovaGiftCatalog.resolve(g);
    final coins = (g['coins'] ?? g['priceCoins'] ?? gift.price) as num;
    return NovaGiftEffect(
      key: ValueKey('${g['id'] ?? gift.slug}-${_giftFxSeq}'),
      emoji: gift.emoji,
      gift: gift,
      name: gift.name,
      effectKey: gift.effectKey,
      tier: gift.tier,
      rarity: gift.rarity,
      senderName: '${g['sender'] ?? ''}',
      coins: coins.toInt(),
      hostName: widget.title,
      duration: Duration(milliseconds: (g['effectMs'] as num?)?.toInt() ?? 2600),
      onDone: _advanceGift,
    );
  }

  /// Gift Animation Manager: one effect plays at a time; the rest wait in a
  /// queue so a burst of gifts never overlaps or drops an animation.
  void _enqueueGift(Map<String, dynamic> fx) {
    if (_giftFx == null) {
      setState(() { _giftFx = fx; _giftFxSeq++; });
      _armGiftTimer(fx);
    } else {
      _giftQueue.add(fx);
    }
  }

  void _armGiftTimer(Map<String, dynamic> fx) {
    _giftFxTimer?.cancel();
    final ms = (fx['effectMs'] is num ? (fx['effectMs'] as num).toInt() : 2400).clamp(1200, 6000);
    _giftFxTimer = Timer(Duration(milliseconds: ms + 500), _advanceGift);
  }

  void _advanceGift() {
    if (!mounted) return;
    if (_giftQueue.isNotEmpty) {
      final next = _giftQueue.removeAt(0);
      setState(() { _giftFx = next; _giftFxSeq++; });
      _armGiftTimer(next);
    } else if (_giftFx != null) {
      setState(() => _giftFx = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        _buildVideoStage(),
        if (_liveEffect != 'none') Positioned.fill(child: IgnorePointer(child: Container(color: _liveEffect == 'noir' ? Colors.black.withValues(alpha: .24) : _liveEffect == 'cinema' ? Colors.amber.withValues(alpha: .07) : _liveEffect == 'dream' ? Colors.purple.withValues(alpha: .10) : _liveEffect == 'warm' ? Colors.orange.withValues(alpha: .10) : Colors.blue.withValues(alpha: .08)))),
        if (_paused) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .76), alignment: Alignment.center, child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 72), SizedBox(height: 12), Text('البث متوقف مؤقتًا', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('سيعود البث عند استئناف المضيف', style: TextStyle(color: Colors.white70))]))),
        IgnorePointer(child: NovaHeartsOverlay(burst: _hearts)),
        _hostHeader(),
        _battleBar(),
        _tapHud(),
        _giftAlertBanner(),
        if (connecting)
          Positioned.fill(child: ColoredBox(color: Colors.black54, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: SN.cyan), const SizedBox(height: 14), const Text('جاري فتح البث بجودة عالية...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])))),
        if (_giftFx != null) _giftOverlay(),
        if (error != null && !connecting)
          Positioned(left: 20, right: 20, top: MediaQuery.of(context).size.height * .38, child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .76), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)), child: Column(children: [const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 42), const SizedBox(height: 10), const Text('تعذّر الاتصال بالبث', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 12), FilledButton(onPressed: () { setState(() { connecting = true; error = null; }); _connectLiveKit(); }, child: const Text('إعادة المحاولة'))]))),
        _commentRail(),
        _bottomBar(),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Live support leaderboard widgets (top gifters / top tappers).
// ---------------------------------------------------------------------------
class _BoardTitle extends StatelessWidget {
  const _BoardTitle({required this.icon, required this.color, required this.text});
  final IconData icon; final Color color; final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

class _BoardEmpty extends StatelessWidget {
  const _BoardEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(text, style: TextStyle(color: SN.textMut, fontSize: 12)),
      );
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.index, required this.row, required this.trailing});
  final int index; final Map<String, dynamic> row; final String trailing;
  @override
  Widget build(BuildContext context) {
    final name = '${row['displayName'] ?? row['username'] ?? 'مستخدم'}';
    final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: SN.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: SN.strokeSoft)),
      child: Row(children: [
        SizedBox(width: 28, child: Text(medal, style: const TextStyle(fontWeight: FontWeight.w900))),
        SNav(url: '${row['avatarUrl'] ?? ''}', name: name, size: 34),
        const SizedBox(width: 10),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text(trailing, style: const TextStyle(color: SN.cyan, fontWeight: FontWeight.w900, fontSize: 12)),
      ]),
    );
  }
}

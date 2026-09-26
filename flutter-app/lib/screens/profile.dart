import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'digital_id.dart';
import '../models/models.dart';
import 'auth.dart';
import 'home.dart';
import 'social.dart';
import 'wallet.dart';
import 'max_privacy.dart';
import 'content_studio.dart';
import '../core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization.dart';

// ---------------------------------------------------------------------------
// My profile tab
// ---------------------------------------------------------------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.me$();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) {
            return SafeArea(
              child: Column(
                children: [
                  const SNHeader(title: 'حسابي'),
                  Expanded(child: EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''))),
                ],
              ),
            );
          }
          final me = UserM(snap.data ?? {});
          return _ProfileBody(
            user: me,
            isMe: true,
            onRefresh: () => setState(() => _future = Api.me$()),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Another user's profile
// ---------------------------------------------------------------------------
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.profile(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: SN.bg1, title: Text('الملف الشخصي')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
          final u = UserM(snap.data ?? {});
          return _ProfileBody(
            user: u,
            isMe: u.isMe,
            onRefresh: () => setState(() => _future = Api.profile(widget.userId)),
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.user, required this.isMe, required this.onRefresh});

  final UserM user;
  final bool isMe;
  final VoidCallback onRefresh;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late Future<List<dynamic>> _posts;
  late Future<List<dynamic>> _repostedReels;
  late Future<List<dynamic>> _savedPosts;
  late Future<List<dynamic>> _likedPosts;
  late Future<List<dynamic>> _likedReels;
  late Future<List<dynamic>> _savedReels;
  late Future<List<dynamic>> _stories;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _applyProfileSecure(widget.user);
    _posts = Api.userPosts(widget.user.id);
    _repostedReels = Api.userRepostedReels(widget.user.id);
    _savedPosts = Api.userSavedPosts(widget.user.id);
    _likedPosts = Api.userLikedPosts(widget.user.id);
    _likedReels = Api.userReelsLiked(widget.user.id);
    _savedReels = Api.userReelsSaved(widget.user.id);
    _stories = Api.userStories(widget.user.id);
  }

  void _applyProfileSecure(UserM u) { const MethodChannel('socialnova/privacy').invokeMethod('setSecure', {'enabled': u.j['preventProfileScreenshots'] == true}).catchError((_){}); }

  @override
  void didUpdateWidget(covariant _ProfileBody old) {
    super.didUpdateWidget(old);
    _applyProfileSecure(widget.user);
    if (old.user.id != widget.user.id) {
      _posts = Api.userPosts(widget.user.id);
      _repostedReels = Api.userRepostedReels(widget.user.id);
      _savedPosts = Api.userSavedPosts(widget.user.id);
      _likedPosts = Api.userLikedPosts(widget.user.id);
      _likedReels = Api.userReelsLiked(widget.user.id);
      _savedReels = Api.userReelsSaved(widget.user.id);
      _stories = Api.userStories(widget.user.id);
    }
  }

  @override void dispose(){ const MethodChannel('socialnova/privacy').invokeMethod('setSecure', {'enabled': false}).catchError((_){}); super.dispose(); }

  Future<void> _toggleFollow() async {
    try {
      final result = await Api.follow(widget.user.id);
      if (mounted) { toast(context, result['requested']==true ? 'تم إرسال طلب المتابعة' : (result['following']==true ? 'تمت المتابعة' : 'تم إلغاء المتابعة')); setState(() => _posts = Api.userPosts(widget.user.id)); }
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showProfileImage(String url, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const SizedBox(
                      height: 240,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 54),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return RefreshIndicator(
      color: SN.violet,
      onRefresh: () async {
        _posts = Api.userPosts(u.id);
        _stories = Api.userStories(u.id);
        widget.onRefresh();
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Cover
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: u.coverUrl.isEmpty ? null : () => _showProfileImage(u.coverUrl, 'صورة الغلاف'),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: SN.grad,
                    image: u.coverUrl.isEmpty
                        ? null
                        : DecorationImage(image: NetworkImage(u.coverUrl), fit: BoxFit.cover),
                  ),
                  child: u.coverUrl.isNotEmpty
                      ? Align(alignment: AlignmentDirectional.topEnd, child: Padding(padding: const EdgeInsets.all(10), child: CircleAvatar(backgroundColor: Colors.black54, child: const Icon(Icons.open_in_full, color: Colors.white, size: 18))))
                      : null,
                ),
              ),
              Positioned(
                right: 16,
                bottom: -44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Tapping the profile photo always opens the full-size image.
                    // Story viewing is exposed as a separate small button so the
                    // two actions cannot conflict.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: u.avatarUrl.isEmpty ? null : () => _showProfileImage(u.avatarUrl, 'صورة الملف الشخصي'),
                      child: SNav(url: u.avatarUrl, name: u.displayName, size: 96, ring: u.hasActiveStory),
                    ),
                    if (u.hasActiveStory)
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              try {
                                final rows = await Api.userStories(u.id);
                                if (!context.mounted || rows.isEmpty) return;
                                Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewer(story: StoryM(Map<String,dynamic>.from(rows.first as Map)))));
                              } catch (_) {}
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .82),
                                shape: BoxShape.circle,
                                border: Border.all(color: SN.cyan, width: 1.5),
                                boxShadow: [BoxShadow(color: SN.cyan.withValues(alpha: .35), blurRadius: 12)],
                              ),
                              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 19),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.displayName.isEmpty ? u.username : u.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    VerifiedBadge(tier: u.tier, size: 20),
                    if (u.isPrivate) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock, size: 14, color: SN.textMut),
                    ],
                  ],
                ),
                Text('@${u.username}', style: TextStyle(color: SN.textMut, fontSize: 13)),
                if (u.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(u.bio, style: const TextStyle(height: 1.6, fontSize: 14)),
                ],
                const SizedBox(height: 14),
                // Counters
                Row(
                  children: [
                    _counter('منشور', u.posts == null ? '—' : '${u.posts}'),
                    _counter('متابع', u.followers == null ? '—' : '${u.followers}',
                        onTap: u.followers == null
                            ? null
                            : () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => FollowersPage(userId: u.id, mode: 'followers')))),
                    _counter('يتابع', u.following == null ? '—' : '${u.following}',
                        onTap: u.following == null
                            ? null
                            : () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => FollowersPage(userId: u.id, mode: 'following')))),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.isMe)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: SN.bg3,
                            foregroundColor: SN.textPri,
                            minimumSize: const Size(0, 46),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditProfilePage(user: u)),
                          ).then((_) => widget.onRefresh()),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('تعديل الملف'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: SN.bg3),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                if (widget.isMe) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('محفظة NovaCoin • الهدايا والأرباح'),
                    ),
                  ),
                ]
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: u.followingMe || u.followRequested ? SN.bg3 : SN.violet,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 46),
                          ),
                          onPressed: _toggleFollow,
                          icon: Icon(u.followingMe ? Icons.person_remove_outlined : (u.followRequested ? Icons.hourglass_top_rounded : Icons.person_add_alt_1), size: 18),
                          label: Text(u.followingMe ? 'إلغاء المتابعة' : (u.followRequested ? 'تم إرسال الطلب' : 'متابعة')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SN.textPri,
                            side: BorderSide(color: SN.stroke),
                            minimumSize: const Size(0, 46),
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(userId: u.id, name: u.displayName, avatar: u.avatarUrl))),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('رسالة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'اتصال',
                        style: IconButton.styleFrom(backgroundColor: SN.bg3),
                        onPressed: () => _showContactActions(context, u),
                        icon: const Icon(Icons.call_outlined),
                      ),
                    ],
                  ),
                FutureBuilder<List<dynamic>>(
                  future: _stories,
                  builder: (context, snap) {
                    final rows = snap.data ?? [];
                    if (rows.isEmpty) return const SizedBox.shrink();
                    final stories = rows.map((e) => StoryM(Map<String,dynamic>.from(e as Map))).toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('القصص', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 9),
                        SizedBox(height: 86, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: stories.length, separatorBuilder: (_,__) => const SizedBox(width: 12), itemBuilder: (_,i) {
                          final st = stories[i];
                          return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewer(story: st))), child: Column(children: [SNav(url: st.author.avatarUrl, name: st.author.displayName, size: 58, ring: true), SizedBox(height: 4), Text('${i+1}', style: TextStyle(fontSize: 10, color: SN.textMut))]));
                        }))
                      ]),
                    );
                  },
                ),
                if (u.website.isNotEmpty || u.location.isNotEmpty || u.birthDate.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  if (u.website.isNotEmpty)
                    _metaRow(Icons.link, u.website, onTap: () async {
                      final uri = Uri.tryParse(u.website.startsWith('http') ? u.website : 'https://${u.website}');
                      if (uri != null) {
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      }
                    }),
                  if (u.location.isNotEmpty) _metaRow(Icons.location_on_outlined, u.location),
                  if (u.birthDate.isNotEmpty)
                    _metaRow(Icons.cake_outlined,
                        'تاريخ الميلاد: ${u.birthDate.toString().split('T').first}'),
                ],
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: SN.strokeSoft), bottom: BorderSide(color: SN.strokeSoft))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _tabButton('منشورات', 0),
                      _tabButton('إعادة نشر', 1),
                      if (widget.isMe) _tabButton('محفوظات', 2),
                      if (widget.isMe) _tabButton('خاصة', 3),
                      if (widget.isMe) _tabButton('فيديوهات أعجبتني', 4),
                    ]),
                  ),
                ),
                _tabContent(u),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int index) => InkWell(
    onTap: () => setState(() => _tab = index),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: _tab == index ? SN.violet : SN.textMut)),
    ),
  );

  Widget _tabContent(UserM u) {
    if (_tab == 1) {
      return FutureBuilder<List<dynamic>>(future: _repostedReels, builder: (c,snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
        if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
        final rows=snap.data??[];
        if(rows.isEmpty)return const EmptyState(text:'لا توجد إعادات نشر بعد.',icon:Icons.repeat_rounded);
        return Column(children:[for(final item in rows) ProfileRepostedReelCard(reel:ReelM(Map<String,dynamic>.from(item as Map)),onChanged:(){setState(()=>_repostedReels=Api.userRepostedReels(u.id));}),const SizedBox(height:40)]);
      });
    }
    Future<List<dynamic>> future = _posts;
    if (_tab == 2) future = _savedPosts;
    if (_tab == 3) future = Api.userPosts(u.id);
    if (_tab == 4) future = _likedPosts;
    if (_tab == 2 || _tab == 4) {
      final rf = _tab == 2 ? _savedReels : _likedReels;
      return FutureBuilder<List<dynamic>>(future: Future.wait([future,rf]).then((x)=>[x[0],x[1]]), builder:(c,snap){
        if(snap.connectionState==ConnectionState.waiting)return const LoadingBox();
        if(snap.hasError)return EmptyState(text:'${snap.error}'.replaceFirst('Exception: ',''));
        final postRows=List<dynamic>.from((snap.data?[0] as List?)??[]); final reelRows=List<dynamic>.from((snap.data?[1] as List?)??[]);
        if(postRows.isEmpty && reelRows.isEmpty)return EmptyState(text:_tab==2?'لا توجد عناصر محفوظة بعد.':'لا توجد عناصر أعجبت بها بعد.',icon:Icons.bookmark_border_rounded);
        return Column(children:[
          if(postRows.isNotEmpty) ...[Padding(padding:EdgeInsets.fromLTRB(12,12,12,4),child:Align(alignment:Alignment.centerRight,child:Text(L10n.t('منشورات'),style:TextStyle(fontWeight:FontWeight.w900)))), for(final x in postRows) Padding(padding:EdgeInsets.symmetric(horizontal:12),child:PostCard(post:PostM(Map<String,dynamic>.from(x as Map)),onChanged:widget.onRefresh))],
          if(reelRows.isNotEmpty) ...[const Padding(padding:EdgeInsets.fromLTRB(12,18,12,4),child:Align(alignment:Alignment.centerRight,child:Text('Reels',style:TextStyle(fontWeight:FontWeight.w900)))), for(final x in reelRows) ProfileRepostedReelCard(reel:ReelM(Map<String,dynamic>.from(x as Map)),onChanged:widget.onRefresh)],
          const SizedBox(height:40)
        ]);
      });
    }
    return FutureBuilder<List<dynamic>>(future: future, builder: (c,snap) {
      if(snap.connectionState==ConnectionState.waiting)return const LoadingBox();
      if(snap.hasError)return EmptyState(text:'${snap.error}'.replaceFirst('Exception: ',''));
      final posts=snap.data??[];
      final filtered=_tab==3 ? posts.where((x){final m=Map<String,dynamic>.from(x as Map);return '${m['visibility']??'PUBLIC'}'=='PRIVATE';}).toList() : posts;
      if(filtered.isEmpty)return EmptyState(text:_tab==2?'لا توجد منشورات محفوظة بعد.':_tab==3?'لا توجد منشورات خاصة بعد.':_tab==4?'لا توجد فيديوهات أعجبت بها بعد.':(u.isLocked?'هذا الحساب خاص. تابع المستخدم لعرض منشوراته.':'لا توجد منشورات بعد.'),icon:Icons.article_outlined);
      return Column(children:[for(final x in filtered) Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:PostCard(post:PostM(Map<String,dynamic>.from(x as Map)),onChanged:widget.onRefresh)),const SizedBox(height:40)]);
    });
  }

  Future<void> _showContactActions(BuildContext context, UserM u) async {
    final phone = '${u.j['phoneNumber'] ?? ''}'.trim();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.call_outlined), title: const Text('مكالمة صوتية'), subtitle: Text(phone.isEmpty ? 'رقم الهاتف غير متاح لهذا الحساب' : phone), onTap: phone.isEmpty ? null : () async { final uri = Uri.parse('tel:$phone'); await launchUrl(uri); }),
            ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('مكالمة فيديو'), subtitle: const Text('يتطلب تفعيل خدمة الاتصال الآمن على الخادم'), onTap: () => toast(ctx, 'واجهة مكالمة الفيديو جاهزة، وتحتاج إعداد WebRTC على الخادم.'),),
          ]),
        ),
      ),
    );
  }

  Widget _counter(String label, String value, {VoidCallback? onTap}) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(label, style: TextStyle(color: SN.textMut, fontSize: 12)),
              ],
            ),
          ),
        ),
      );

  Widget _metaRow(IconData icon, String text, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(icon, size: 16, color: SN.textMut),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: text.startsWith('http') ? TextDirection.ltr : null,
                  style: TextStyle(color: SN.textSec, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
}

class ProfileRepostedReelCard extends StatefulWidget {
  const ProfileRepostedReelCard({super.key, required this.reel, required this.onChanged});
  final ReelM reel;
  final VoidCallback onChanged;

  @override
  State<ProfileRepostedReelCard> createState() => _ProfileRepostedReelCardState();
}

class _ProfileRepostedReelCardState extends State<ProfileRepostedReelCard> {
  late bool reposted;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reposted = widget.reel.repostedByMe;
  }

  Future<void> _toggleRepost() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await Api.repostReel(widget.reel.id);
      if (!mounted) return;
      setState(() => reposted = result['reposted'] == true);
      toast(context, reposted ? 'تمت إعادة النشر' : 'تم إلغاء إعادة النشر');
      if (!reposted) widget.onChanged();
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                SNav(url: r.author.avatarUrl, name: r.author.displayName, size: 38),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.author.displayName.isEmpty ? r.author.username : r.author.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('ريل معاد نشره', style: TextStyle(color: SN.textMut, fontSize: 12)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _toggleRepost,
                  icon: Icon(reposted ? Icons.repeat_rounded : Icons.repeat_outlined, size: 17),
                  label: Text(reposted ? 'إعادة نشر' : 'إعادة نشر'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            width: double.infinity,
            child: VideoBox(url: r.videoUrl, autoPlay: false, radius: 0, musicUrl: r.musicUrl),
          ),
          Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(children:[Icon(Icons.visibility_outlined,size:15,color:SN.textMut),SizedBox(width:5),Text('${r.views} مشاهدة',style:TextStyle(color:SN.textMut,fontSize:12))])),
          if (r.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(r.caption, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile
// ---------------------------------------------------------------------------
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final UserM user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController bioCtrl;
  late final TextEditingController webCtrl;
  late final TextEditingController locCtrl;
  DateTime? birth;
  String gender = '';
  String avatarUrl = '';
  String coverUrl = '';
  bool busy = false;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    nameCtrl = TextEditingController(text: u.displayName);
    bioCtrl = TextEditingController(text: u.bio);
    webCtrl = TextEditingController(text: u.website);
    locCtrl = TextEditingController(text: u.location);
    gender = u.gender;
    avatarUrl = u.avatarUrl;
    coverUrl = u.coverUrl;
    birth = DateTime.tryParse(u.birthDate);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    bioCtrl.dispose();
    webCtrl.dispose();
    locCtrl.dispose();
    super.dispose();
  }

  Future<void> _upload(bool isCover) async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (f == null) return;
      setState(() => uploading = true);
      final up = await Api.uploadMedia(f.path, kind: 'IMAGE');
      setState(() {
        if (isCover) {
          coverUrl = '${up['url']}';
        } else {
          avatarUrl = '${up['url']}';
        }
        uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birth ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null && mounted) setState(() => birth = picked);
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await Api.updateMe({
        'displayName': nameCtrl.text.trim(),
        'bio': bioCtrl.text.trim(),
        'website': webCtrl.text.trim(),
        'location': locCtrl.text.trim(),
        'gender': gender,
        'birthDate': birth?.toUtc().toIso8601String(),
        'avatarUrl': avatarUrl,
        'coverUrl': coverUrl,
      });
      if (!mounted) return;
      toast(context, 'تم حفظ التعديلات ✓');
      Navigator.pop(context, true);
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
        title: const Text('تعديل الملف الشخصي'),
        actions: [IconButton(tooltip: 'بطاقة الهوية الرقمية', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DigitalIdPage())), icon: Icon(Icons.badge_rounded, color: SN.cyan)),TextButton(onPressed: busy ? null : _save, child: Text('حفظ'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: uploading ? null : () => _upload(true),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: SN.grad,
                image: coverUrl.isEmpty ? null : DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(L10n.t('تغيير الغلاف'), style: TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(onTap: uploading ? null : () => _upload(false), child: SNav(url: avatarUrl, name: nameCtrl.text, size: 78, ring: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(L10n.t('اضغط على الصورة أو الغلاف لاختيار ملف من المعرض.'),
                    style: TextStyle(color: SN.textMut, fontSize: 12, height: 1.6)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
          const SizedBox(height: 12),
          TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة (Bio)')),
          const SizedBox(height: 12),
          TextField(
            controller: webCtrl,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'الموقع الإلكتروني', hintText: 'https://example.com'),
          ),
          const SizedBox(height: 12),
          TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'الموقع الجغرافي')),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickBirth,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'تاريخ الميلاد',
                prefixIcon: Icon(Icons.cake_outlined, color: SN.textSec),
                suffixIcon: Icon(Icons.calendar_month_outlined, color: SN.violet),
              ),
              child: Text(
                birth == null
                    ? 'لم يتم التحديد'
                    : '${birth!.year}/${birth!.month.toString().padLeft(2, '0')}/${birth!.day.toString().padLeft(2, '0')}',
                style: TextStyle(color: birth == null ? SN.textMut : SN.textPri),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GradButton(label: 'حفظ التعديلات', icon: Icons.check_rounded, busy: busy || uploading, onTap: _save),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Followers / following lists
// ---------------------------------------------------------------------------
class FollowersPage extends StatefulWidget {
  const FollowersPage({super.key, required this.userId, required this.mode});

  final String userId;
  final String mode; // followers | following

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.mode == 'followers' ? Api.followers(widget.userId) : Api.following(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SN.bg1,
        title: Text(widget.mode == 'followers' ? 'المتابعون' : 'يتابع'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return EmptyState(
              text: widget.mode == 'followers' ? 'لا يوجد متابعون بعد' : 'لا يتابع أحدًا بعد',
              icon: Icons.people_outline,
            );
          }
          return ListView(
            children: [
              for (final u in list)
                ListTile(
                  leading: SNav(url: '${(u as Map)['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? ''}', size: 46),
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
                  onTap: () => openProfile(context, '${u['id']}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isPrivate = false;
  bool hideFollowers = false;
  bool hideFollowing = false;
  bool showOnline = true;
  bool allowRequests = true;
  bool push = true;
  bool preventProfileScreenshots = false;
  bool loaded = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.me$();
      setState(() {
        isPrivate = me['isPrivate'] == true;
        hideFollowers = me['hideFollowersCount'] == true;
        hideFollowing = me['hideFollowingCount'] == true;
        showOnline = me['showOnlineStatus'] != false;
        allowRequests = me['allowMessageRequests'] != false;
        push = me['pushNotifications'] != false;
        preventProfileScreenshots = me['preventProfileScreenshots'] == true;
        loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loaded = true);
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    setState(() => busy = true);
    try {
      await Api.updateSettings(patch);
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
      appBar: AppBar(backgroundColor: SN.bg1, title: Text('الإعدادات')),
      body: loaded
          ? ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _section('التخصيص الاحترافي'),
                GlassCard(child: ListTile(leading: Icon(Icons.auto_awesome_rounded, color: SN.violet), title: Text('استوديو المحتوى', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('إدارة الستوري والمنشورات والريلز والجدولة والإحصائيات'), trailing: Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentStudioPage())))),
                GlassCard(child: ListTile(leading: Icon(Icons.palette_outlined, color: SN.cyan), title: Text('مظهر SocialNova', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(AppAppearance.mode.value == 'night' ? 'الوضع الداكن الليلي' : 'Neon Glass — مطابق لتصميم SocialNova'), trailing: Icon(Icons.chevron_left), onTap: _appearance)),
                GlassCard(
                  child: ListTile(
                    leading: Icon(Icons.language_rounded, color: SN.cyan),
                    title: Text(L10n.text('language', AppLocale.locale.value.languageCode), style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${AppLocale.flags[AppLocale.locale.value.languageCode] ?? '🌐'}  ${L10n.language(AppLocale.locale.value.languageCode)}'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: _language,
                  ),
                ),
                _section('الخصوصية'),
                ListTile(leading: Icon(Icons.shield_moon_outlined, color: SN.violet), title: Text('الخصوصية القصوى', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('إخفاء الحساب والنشاط وحماية الشاشة'), trailing: Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaximumPrivacyPage()))),
                _switch(
                  'حساب خاص',
                  'عند التفعيل، يرى متابعوك فقط منشوراتك.',
                  isPrivate,
                  (v) {
                    setState(() => isPrivate = v);
                    _save({'isPrivate': v});
                  },
                ),
                _switch(
                  'إخفاء عدد المتابعين',
                  'لن يظهر عدد متابعيك للآخرين.',
                  hideFollowers,
                  (v) {
                    setState(() => hideFollowers = v);
                    _save({'hideFollowersCount': v});
                  },
                ),
                _switch(
                  'إخفاء عدد الذين تتابعهم',
                  'لن يظهر عدد من تتابعهم للآخرين.',
                  hideFollowing,
                  (v) {
                    setState(() => hideFollowing = v);
                    _save({'hideFollowingCount': v});
                  },
                ),
                _switch(
                  'إظهار حالة الاتصال',
                  'السماح للآخرين برؤية أنك متصل.',
                  showOnline,
                  (v) {
                    setState(() => showOnline = v);
                    _save({'showOnlineStatus': v});
                  },
                ),
                _section('حماية الملف'),
                _switch(
                  'منع لقطات الشاشة للملف',
                  'يطلب من التطبيق حماية شاشة الملف الشخصي من لقطات الشاشة على الأجهزة التي تدعم ذلك.',
                  preventProfileScreenshots,
                  (v) { setState(() => preventProfileScreenshots = v); _save({'preventProfileScreenshots': v}); },
                ),
                _section('الرسائل والإشعارات'),
                _switch(
                  'طلبات الرسائل',
                  'السماح باستلام رسائل من أشخاص لا تتابعهم.',
                  allowRequests,
                  (v) {
                    setState(() => allowRequests = v);
                    _save({'allowMessageRequests': v});
                  },
                ),
                _switch(
                  'الإشعارات الفورية',
                  'تنبيهات الإعجابات والتعليقات والمتابعة.',
                  push,
                  (v) {
                    setState(() => push = v);
                    _save({'pushNotifications': v});
                  },
                ),
                _section('الحساب'),
                ListTile(
                  leading: Icon(Icons.verified_outlined, color: SN.gold),
                  title: const Text('التوثيق'),
                  subtitle: Text('توثيق عادي أو احترافي', style: TextStyle(color: SN.textMut, fontSize: 12)),
                  trailing: Icon(Icons.chevron_left, color: SN.textMut),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationPage())),
                ),
                ListTile(
                  leading: Icon(Icons.notifications_none, color: SN.textSec),
                  title: const Text('الإشعارات'),
                  trailing: Icon(Icons.chevron_left, color: SN.textMut),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                ),
                ListTile(
                  leading: Icon(Icons.dns_outlined, color: SN.textSec),
                  title: const Text('عنوان الخادم (API)'),
                  subtitle: Text(Api.baseUrl, style: TextStyle(color: SN.textMut, fontSize: 11), textDirection: TextDirection.ltr),
                  onTap: () async {
                    final c = TextEditingController(text: Api.baseUrl);
                    final r = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('عنوان الخادم'),
                        content: TextField(controller: c, textDirection: TextDirection.ltr),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('حفظ')),
                        ],
                      ),
                    );
                    c.dispose();
                    if (r != null) {
                      await Api.setBaseUrl(r);
                      if (!mounted) return;
                      toast(context, 'تم تحديث العنوان');
                      setState(() {});
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: SN.red),
                  title: Text('تسجيل الخروج', style: TextStyle(color: SN.red)),
                  onTap: () async {
                    await Api.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (_) => false,
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text('SocialNova v3.0.0 • A WHX Labs Product',
                      style: TextStyle(color: SN.textMut, fontSize: 11)),
                ),
                const SizedBox(height: 20),
              ],
            )
          : const LoadingBox(),
    );
  }

  Future<void> _language() async {
    final current = AppLocale.locale.value.languageCode;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.language_rounded, color: SN.cyan),
              title: Text(L10n.text('chooseLanguage', current), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(L10n.text('languageSubtitle', current)),
            ),
            for (final locale in AppLocale.supported)
              ListTile(
                leading: Text(AppLocale.flags[locale.languageCode] ?? '🌐', style: const TextStyle(fontSize: 23)),
                title: Text(AppLocale.names[locale.languageCode] ?? locale.languageCode),
                trailing: current == locale.languageCode ? Icon(Icons.check_circle_rounded, color: SN.violet) : null,
                onTap: () => Navigator.pop(ctx, locale.languageCode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await AppLocale.set(picked);
    if (mounted) setState(() {});
  }

  Future<void> _appearance() async {
    final current = AppAppearance.mode.value;
    final picked = await showModalBottomSheet<String>(context: context, backgroundColor: SN.bg1, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text(L10n.t('اختيار مظهر التطبيق'), style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(L10n.t('يتغير شكل الواجهات فورًا'))),
      ListTile(leading: Icon(Icons.auto_awesome_rounded, color: SN.violet), title: Text('Neon Glass'), subtitle: Text('نفس ألوان وتصميم الصورة: كحلي + بنفسجي + أزرق نيون'), trailing: current == 'neon' ? Icon(Icons.check_circle, color: SN.violet) : null, onTap: () => Navigator.pop(ctx, 'neon')),
      ListTile(leading: Icon(Icons.dark_mode_rounded, color: SN.cyan), title: Text('الوضع الداكن الليلي'), subtitle: Text('أسود ليلي أعمق مع نفس الهوية النيونية'), trailing: current == 'night' ? Icon(Icons.check_circle, color: SN.cyan) : null, onTap: () => Navigator.pop(ctx, 'night')),
    ])));
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_appearance', picked);
    AppAppearance.mode.value = picked;
    if (mounted) setState(() {});
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
        child: Text(t, style: TextStyle(color: SN.cyan, fontWeight: FontWeight.w800, fontSize: 13)),
      );

  Widget _switch(String title, String sub, bool value, ValueChanged<bool> onChanged) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: SN.violet,
          value: value,
          onChanged: busy ? null : onChanged,
          title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: TextStyle(color: SN.textMut, fontSize: 11.5, height: 1.5)),
        ),
      );
}

// ---------------------------------------------------------------------------
// Verification (paid tiers)
// ---------------------------------------------------------------------------
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late Future<Map<String, dynamic>> _future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _future = Api.verificationMe();
  }

  Future<void> _purchase(String tier, String label) async {
    setState(() => busy = true);
    try {
      final res = await Api.requestVerification(tier);
      final req = Map<String, dynamic>.from(res['request'] as Map);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إتمام الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الباقة: $label', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('المرجع: ${req['reference']}', textDirection: TextDirection.ltr),
              const SizedBox(height: 8),
              const Text(
                'اضغط تأكيد لمحاكاة عملية الدفع وإصدار الشارة على حسابك.',
                style: TextStyle(color: SN.textMut, fontSize: 12, height: 1.6),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الدفع')),
          ],
        ),
      );
      if (confirmed == true) {
        await Api.confirmVerification('${req['id']}');
        if (!mounted) return;
        toast(context, 'تم تفعيل التوثيق ✓');
        setState(() => _future = Api.verificationMe());
      }
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
      appBar: AppBar(backgroundColor: SN.bg1, title: Text('توثيق الحساب')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
          final data = snap.data ?? {};
          final activeTier = '${data['tier'] ?? 'NONE'}';
          final requests = (data['requests'] as List?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                gradient: LinearGradient(
                  colors: [SN.violet.withValues(alpha: .25), SN.bg2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, color: SN.gold, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          activeTier == 'NONE'
                              ? 'لا يوجد توثيق نشط'
                              : (activeTier == 'PRO' ? 'توثيق احترافي مُفعّل' : 'توثيق عادي مُفعّل'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeTier == 'NONE'
                          ? 'وثّق حسابك للحصول على شارة بجانب اسمك وزيادة ثقة المتابعين.'
                          : 'ينتهي في: ${'${data['expiresAt'] ?? ''}'.split('T').first}',
                      style: TextStyle(color: SN.textSec, fontSize: 12.5, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _planCard(
                title: 'التوثيق العادي',
                price: r'$4.99 / شهر',
                perks: const [
                  'شارة زرقاء بجانب الاسم',
                  'ثقة أعلى لدى المتابعين',
                  'إحصائيات أساسية',
                  'دعم عبر البريد',
                ],
                gradient: SN.grad,
                onTap: busy ? null : () => _purchase('NORMAL', 'التوثيق العادي'),
              ),
              const SizedBox(height: 14),
              _planCard(
                title: 'التوثيق الاحترافي',
                price: r'$19.99 / شهر',
                perks: const [
                  'شارة ذهبية متحركة',
                  'أولوية الدعم الفني',
                  'إحصائيات متقدمة',
                  'ظهور مميز في نتائج البحث',
                  'تحقق من الهوية',
                  'تخصيص رابط الملف',
                ],
                gradient: SN.gradGold,
                onTap: busy ? null : () => _purchase('PRO', 'التوثيق الاحترافي'),
              ),
              const SizedBox(height: 20),
              if (requests.isNotEmpty) ...[
                const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final r in requests)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      (r as Map)['status'] == 'APPROVED'
                          ? Icons.check_circle
                          : (r['status'] == 'REJECTED' ? Icons.cancel : Icons.hourglass_top),
                      color: r['status'] == 'APPROVED'
                          ? SN.green
                          : (r['status'] == 'REJECTED' ? SN.red : SN.gold),
                    ),
                    title: Text('${r['tier']} • ${r['status']}', style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${r['reference']}', style: TextStyle(color: SN.textMut, fontSize: 11), textDirection: TextDirection.ltr),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required List<String> perks,
    required Gradient gradient,
    required VoidCallback? onTap,
  }) =>
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                ShaderMask(
                  shaderCallback: (r) => gradient.createShader(r),
                  child: Text(price, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final p in perks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 15, color: SN.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p, style: TextStyle(color: SN.textSec, fontSize: 13))),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradButton(
                label: 'اشترك الآن',
                icon: Icons.payments_outlined,
                busy: busy,
                gradient: gradient,
                height: 48,
                onTap: onTap,
              ),
            ),
          ],
        ),
      );
}

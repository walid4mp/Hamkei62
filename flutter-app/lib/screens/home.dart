import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/models.dart';
import 'wallet.dart';
import 'profile.dart';
import 'social.dart';
import 'editor.dart';
import 'secret_diary.dart';
import 'max_privacy.dart';
import 'women_hub.dart';
import 'achievements.dart';
import 'tech_gaming.dart';
import 'fitness_challenges.dart';
import 'music_picker.dart';
import 'store.dart';

/// Main application shell: a 5-tab NavigationBar matching the requested
/// Home / Reels / Live / Groups / Profile layout, plus a messenger entry point.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  void _openCreate() {
    snClick();
    showComposer(context, onDone: () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const FeedPage(),
      const SearchPage(),
      ReelsPage(isVisible: index == 3),
      const ProfilePage(),
    ];
    final pageIndex = index >= 2 ? index - 1 : index;
    return Scaffold(
      backgroundColor: SN.bg0,
      body: IndexedStack(index: pageIndex, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: SN.bg1,
            border: Border(top: BorderSide(color: SN.strokeSoft)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (v) {
              if (v == 2) {
                _openCreate();
                return;
              }
              snClick();
              setState(() => index = v);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'الرئيسية',
              ),
              const NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'استكشاف',
              ),
              NavigationDestination(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: SN.grad,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .20), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 25),
                ),
                selectedIcon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: SN.grad,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
                label: 'إنشاء',
              ),
              const NavigationDestination(
                icon: Icon(Icons.movie_outlined),
                selectedIcon: Icon(Icons.movie_rounded),
                label: 'Reels',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed
// ---------------------------------------------------------------------------
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.feed();
  }

  void reload() => setState(() => _future = Api.feed());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SNHeader(
              title: 'SocialNova',
              trailing: [
                IconButton(
                  tooltip: 'Live',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage())),
                  icon: const Icon(Icons.sensors_rounded, color: SN.pink),
                ),
                IconButton(
                  tooltip: 'الرسائل',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessengerPage())),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: SN.textPri),
                ),
                IconButton(
                  tooltip: 'الإشعارات',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                  icon: const Icon(Icons.notifications_none_rounded, color: SN.textPri),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: SN.textPri),
                  onSelected: (value) {
                    final routes = <String, Widget>{
                      'groups': const GroupsPage(),
                      'wallet': const WalletPage(),
                      'privacy': const MaximumPrivacyPage(),
                      'diary': const SecretDiaryPage(),
                      'achievements': const AchievementsPage(),
                      'tech': const TechGamingPage(),
                      'fitness': const FitnessChallengesPage(),
                      'store': const StorePage(),
                    };
                    final page = routes[value];
                    if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page));
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'groups', child: Text('المجموعات')),
                    PopupMenuItem(value: 'wallet', child: Text('محفظة NovaCoin')),
                    PopupMenuItem(value: 'privacy', child: Text('الخصوصية القصوى')),
                    PopupMenuItem(value: 'diary', child: Text('المذكرات السرية')),
                    PopupMenuItem(value: 'achievements', child: Text('الإنجازات')),
                    PopupMenuItem(value: 'tech', child: Text('التكنولوجيا والألعاب')),
                    PopupMenuItem(value: 'fitness', child: Text('تحديات النشاط')),
                    PopupMenuItem(value: 'store', child: Text('المتجر')),
                  ],
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: SN.violet,
                onRefresh: () async => reload(),
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
                    if (snap.hasError) {
                      return ListView(
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''), icon: Icons.cloud_off_outlined),
                          Center(
                            child: TextButton(onPressed: reload, child: const Text('إعادة المحاولة')),
                          ),
                        ],
                      );
                    }
                    final posts = snap.data ?? [];
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 90),
                      children: [
                        const StoriesRail(),
                        if (posts.isEmpty) const EmptyState(text: 'لا توجد منشورات بعد. ابدأ بمشاركة أول منشور!', icon: Icons.article_outlined),
                        for (final p in posts) PostCard(post: PostM(Map<String, dynamic>.from(p as Map)), onChanged: reload),
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

// ---------------------------------------------------------------------------
// Stories rail + viewer
// ---------------------------------------------------------------------------
class StoriesRail extends StatefulWidget {
  const StoriesRail({super.key});

  @override
  State<StoriesRail> createState() => _StoriesRailState();
}

class _StoriesRailState extends State<StoriesRail> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.stories();
  }

  Future<void> _addStory() async {
    final picker = ImagePicker();
    try {
      final kind = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.image_outlined), title: const Text('قصة صورة'), onTap: () => Navigator.pop(c, 'image')),
        ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('قصة فيديو'), onTap: () => Navigator.pop(c, 'video')),
      ])));
      if (kind == null) return;
      final file = kind == 'image'
          ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 88)
          : await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
      if (file == null) return;

      final caption = TextEditingController();
      final musicTitle = TextEditingController();
      var rotation = 0;
      var emoji = '✨';
      String? musicPath;
      String musicUrl = '';
      String? musicId;
      final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
        title: const Text('تعديل القصة قبل النشر'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: caption, maxLines: 3, decoration: const InputDecoration(labelText: 'النص / هاشتاق')),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.library_music_rounded),
            title: Text(musicUrl.isEmpty ? 'إضافة موسيقى من SocialNova' : (musicTitle.text.isEmpty ? 'تم اختيار موسيقى' : musicTitle.text)),
            subtitle: const Text('اختر أغنية من الكتالوج داخل التطبيق'),
            onTap: () async {
              final picked = await openMusicPicker(c, selectedId: musicId);
              if (picked == null) return;
              set(() {
                musicPath = null;
                musicId = '${picked['id'] ?? ''}';
                musicUrl = '${picked['audioUrl'] ?? ''}';
                musicTitle.text = '${picked['title'] ?? ''} — ${picked['artist'] ?? ''}';
              });
            },
          ),
          if (musicPath == null) ...[
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
              final path = result?.files.single.path;
              if (path == null) return;
              set(() { musicPath = path; musicUrl = ''; musicId = null; if (musicTitle.text.isEmpty) musicTitle.text = result!.files.single.name.replaceFirst(RegExp(r'\.[^.]+$'), ''); });
            }, icon: const Icon(Icons.folder_open_rounded), label: const Text('أو اختر ملفًا من الهاتف'))),
          ],
          const SizedBox(height: 6),
          Row(children: [Expanded(child: Text('تدوير: $rotation°')), IconButton(onPressed: () => set(() => rotation = (rotation + 90) % 360), icon: const Icon(Icons.rotate_right)), IconButton(onPressed: () => set(() => emoji = emoji.isEmpty ? '✨' : ''), icon: const Icon(Icons.emoji_emotions_outlined))]),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('متابعة للنشر'))],
      )));
      if (ok != true) { caption.dispose(); musicTitle.dispose(); return; }

      final up = await Api.uploadMedia(file.path, kind: kind == 'image' ? 'IMAGE' : 'VIDEO');
      final mediaType = '${up['type'] ?? (kind == 'image' ? 'IMAGE' : 'VIDEO')}';
      if (musicPath != null) {
        final mu = await Api.uploadMedia(musicPath!, kind: 'AUDIO');
        musicUrl = '${mu['url']}';
      }
      var finalMediaUrl = '${up['url']}';
      // For video stories, merge the original video audio and selected music
      // into one MP4 on the server. This avoids Android audio-focus conflicts
      // between video_player and just_audio and keeps them perfectly aligned.
      if (mediaType == 'VIDEO' && musicUrl.trim().isNotEmpty) {
        try {
          final mixed = await Api.mixMedia(finalMediaUrl, musicUrl);
          final mixedUrl = '${mixed['url'] ?? ''}'.trim();
          if (mixedUrl.isNotEmpty) {
            finalMediaUrl = mixedUrl;
            musicUrl = '';
          }
        } catch (_) {
          // Keep the original video and music as separate synchronized players
          // if server-side mixing is temporarily unavailable. The story still publishes.
        }
      }
      await Api.createStory(finalMediaUrl, mediaType, caption.text.trim(), rotationDegrees: rotation, overlayEmoji: emoji, musicUrl: musicUrl, musicTitle: musicTitle.text.trim());
      caption.dispose(); musicTitle.dispose();
      if (!mounted) return;
      toast(context, 'تم نشر القصة ✨');
      setState(() => _future = Api.stories());
    } catch (e) {
      if (!mounted) return;
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, snap) {
          final items = (snap.data ?? []).map((e) => StoryM(Map<String, dynamic>.from(e as Map))).toList();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              _addTile(),
              for (final s in items) _storyTile(s, items.indexOf(s)),
            ],
          );
        },
      ),
    );
  }

  Widget _addTile() => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: _addStory,
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SN.bg3,
                  border: Border.all(color: SN.violet.withValues(alpha: .6), width: 1.5),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: SN.violet),
              ),
              const SizedBox(height: 6),
              const Text('قصتك', style: TextStyle(fontSize: 11, color: SN.textSec)),
            ],
          ),
        ),
      );

  Widget _storyTile(StoryM s, int i) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StoryViewer(story: s)),
          ),
          child: Column(
            children: [
              SNav(url: s.author.avatarUrl, name: s.author.displayName, size: 68, ring: true),
              const SizedBox(height: 6),
              SizedBox(
                width: 72,
                child: Text(
                  s.author.displayName.isEmpty ? s.author.username : s.author.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: SN.textSec),
                ),
              ),
            ],
          ),
        ),
      );
}

class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.story});
  final StoryM story;
  @override State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  final _reply = TextEditingController();
  bool _liked = false;
  int _likes = 0;
  bool _sending = false;
  late final ValueNotifier<bool> _storyMuted;
  bool _showStoryMute = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.story.likedByMe;
    _likes = widget.story.reactionCount;
    _storyMuted = ValueNotifier<bool>(false);
  }

  Future<void> _heart() async {
    final old = _liked;
    setState(() { _liked = !old; _likes += old ? -1 : 1; });
    try {
      final r = await Api.reactStory(widget.story.id);
      if (!mounted) return;
      setState(() => _liked = r['liked'] == true);
    } catch (_) {
      if (mounted) setState(() { _liked = old; _likes += old ? 1 : -1; });
    }
  }

  Future<void> _replyToStory() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.replyToStory(widget.story.id, text);
      _reply.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        toast(context, 'تم إرسال الرد إلى المحادثة 💬');
      }
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    _storyMuted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Row(children: [
          SNav(url: story.author.avatarUrl, name: story.author.displayName, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(story.author.displayName.isEmpty ? story.author.username : story.author.displayName, style: const TextStyle(fontSize: 15))),
          if (story.musicUrl.isNotEmpty) const Icon(Icons.music_note_rounded, color: Colors.white70),
        ]),
      ),
      body: Stack(children: [
        Center(child: Transform.rotate(
          angle: story.rotationDegrees * 3.141592653589793 / 180,
          child: story.type == 'VIDEO'
              ? VideoBox(url: story.mediaUrl, autoPlay: true, playbackActive: true, height: 520, radius: 0, musicUrl: story.musicUrl, muteNotifier: _storyMuted, onTap: () => setState(() => _showStoryMute = true))
              : Image.network(story.mediaUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const EmptyState(text: 'تعذّر تحميل القصة', icon: Icons.broken_image_outlined)),
        )),
        if (_showStoryMute && story.type == 'VIDEO')
          Positioned(left: 20, top: MediaQuery.of(context).size.height * .40, child: Material(color: Colors.black54, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: () => setState(() => _storyMuted.value = !_storyMuted.value), child: Padding(padding: const EdgeInsets.all(14), child: Icon(_storyMuted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 28))))) ,
        if (story.overlayEmoji.isNotEmpty) Positioned(top: 28, right: 24, child: Text(story.overlayEmoji, style: const TextStyle(fontSize: 34))),
        if (story.musicTitle.isNotEmpty) Positioned(left: 18, right: 18, bottom: 94, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.music_note, color: Colors.white, size: 18), const SizedBox(width: 7), Expanded(child: Text(story.musicTitle, style: const TextStyle(color: Colors.white, fontSize: 13)))]))),
        if (story.caption.isNotEmpty) Positioned(left: 18, right: 18, bottom: 145, child: Text(story.caption, style: const TextStyle(color: Colors.white, fontSize: 15), textAlign: TextAlign.center)),
        Positioned(left: 10, right: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 10, child: SafeArea(top: false, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Container(constraints: const BoxConstraints(minHeight: 50), padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(27), border: Border.all(color: Colors.white38)), child: TextField(controller: _reply, minLines: 1, maxLines: 4, style: const TextStyle(color: Colors.white), textInputAction: TextInputAction.send, onSubmitted: (_) => _replyToStory(), decoration: const InputDecoration(hintText: 'اكتب ردًا على القصة...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none, prefixIcon: Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20))))),
          const SizedBox(width: 4),
          IconButton(onPressed: _sending ? null : _replyToStory, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 29)),
          InkWell(onTap: _heart, borderRadius: BorderRadius.circular(30), child: Padding(padding: const EdgeInsets.all(6), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? Colors.redAccent : Colors.white, size: 30), Text('$_likes', style: const TextStyle(color: Colors.white, fontSize: 10))]))),
        ]))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Post composer
// ---------------------------------------------------------------------------
Future<void> showComposer(BuildContext context, {VoidCallback? onDone}) async {
  final picker = ImagePicker();
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: SN.bg1,
    builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('إنشاء منشور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      ListTile(leading: const Icon(Icons.text_fields), title: const Text('منشور نصي'), onTap: () => Navigator.pop(ctx, 'text')),
      ListTile(leading: const Icon(Icons.image_outlined), title: const Text('صورة مع تعديل قبل النشر'), onTap: () => Navigator.pop(ctx, 'image')),
      ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('فيديو مع تعديل قبل النشر'), onTap: () => Navigator.pop(ctx, 'video')),
    ])),
  );
  if (choice == null) return;
  if (choice == 'text') {
    final caption = TextEditingController();
    final title = TextEditingController();
    await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: SN.bg1, builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان')),
        const SizedBox(height: 10), TextField(controller: caption, maxLines: 5, decoration: const InputDecoration(hintText: 'بماذا تفكر؟ أضف #هاشتاق')),
        const SizedBox(height: 14), GradButton(label: 'نشر', icon: Icons.send_rounded, onTap: () async { try { await Api.post(caption.text.trim(), title: title.text.trim()); if (ctx.mounted) Navigator.pop(ctx); onDone?.call(); } catch (e) { if (ctx.mounted) toast(ctx, e.toString().replaceFirst('Exception: ', '')); } }),
      ]),
    ));
    caption.dispose(); title.dispose();
    return;
  }
  try {
    final f = choice == 'image'
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 88)
        : await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (f == null || !context.mounted) return;
    await openPublishEditor(context, mediaPath: f.path, mediaType: choice == 'image' ? 'IMAGE' : 'VIDEO');
    onDone?.call();
  } catch (e) {
    if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
  }
}

// ---------------------------------------------------------------------------
// Post card
// ---------------------------------------------------------------------------
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, this.onChanged});

  final PostM post;
  final VoidCallback? onChanged;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool liked;
  late int likeCount;
  late bool bookmarked;
  late bool reposted;
  late int repostCount;
  late int shareCount;

  @override
  void initState() {
    super.initState();
    liked = widget.post.likedByMe;
    likeCount = widget.post.likeCount;
    bookmarked = widget.post.bookmarkedByMe;
    reposted = widget.post.repostedByMe;
    repostCount = widget.post.repostCount;
    shareCount = widget.post.shareCount;
  }

  Widget _actionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    bool active = false,
    Color? activeColor,
  }) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
            const SizedBox(width: 7),
            Icon(icon, size: 28, color: active ? (activeColor ?? SN.violet) : Colors.black87),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => openProfile(context, p.author.id),
                child: SNav(url: p.author.avatarUrl, name: p.author.displayName, size: 44, ring: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => openProfile(context, p.author.id),
                            child: Text(
                              p.author.displayName.isEmpty ? p.author.username : p.author.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        VerifiedBadge(tier: p.author.tier, size: 15),
                      ],
                    ),
                    Text('@${p.author.username} • ${timeAgo(p.createdAt)}',
                        style: const TextStyle(color: SN.textMut, fontSize: 11)),
                  ],
                ),
              ),
              if (p.author.isMe)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final r = await openPublishEditor(context, mediaPath: p.mediaUrl, mediaType: p.type, initialCaption: p.caption, initialTitle: p.title, initialMusic: p.musicTitle, initialMusicUrl: p.musicUrl, initialOverlayText: p.overlayText, initialOverlayEmoji: p.overlayEmoji, initialOverlayImageUrl: p.overlayImageUrl, initialRotation: p.rotationDegrees, existingId: p.id);
                      if (r != null) widget.onChanged?.call();
                    } else {
                      try { await Api.deletePost(p.id); widget.onChanged?.call(); } catch (e) { if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', '')); }
                    }
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل المنشور')), PopupMenuItem(value: 'delete', child: Text('حذف المنشور'))],
                ),
            ],
          ),
          if (p.title.isNotEmpty) ...[const SizedBox(height: 12), Text(p.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))],
          if (p.caption.isNotEmpty) ...[const SizedBox(height: 8), Text(p.caption, style: const TextStyle(height: 1.6))],
          if (p.type == 'IMAGE' && p.mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Transform.rotate(
                angle: p.rotationDegrees * 3.141592653589793 / 180,
                child: Image.network(
                p.mediaUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(height: 160, child: EmptyState(text: 'تعذّر تحميل الصورة', icon: Icons.broken_image_outlined)),
              ),
              ),
            ),
          ],
          if (p.overlayText.isNotEmpty || p.overlayEmoji.isNotEmpty || p.overlayImageUrl.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('${p.overlayEmoji} ${p.overlayText}'.trim(), style: const TextStyle(fontWeight: FontWeight.w700))),
          if (p.type == 'VIDEO' && p.mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Transform.rotate(angle: p.rotationDegrees * 3.141592653589793 / 180, child: VideoBox(url: p.mediaUrl, height: 240, radius: 16)),
          ],
          if (p.musicTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.music_note, size: 15, color: SN.cyan),
                const SizedBox(width: 6),
                Text(p.musicTitle, style: const TextStyle(color: SN.cyan, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    final old = bookmarked;
                    setState(() => bookmarked = !bookmarked);
                    try {
                      final r = await Api.bookmark(p.id);
                      if (mounted) setState(() => bookmarked = r['bookmarked'] == true);
                    } catch (_) {
                      if (mounted) setState(() => bookmarked = old);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 27, color: bookmarked ? SN.violet : Colors.black87),
                  ),
                ),
                const Spacer(),
                _actionButton(
                  icon: Icons.send_rounded,
                  count: shareCount,
                  onTap: () async {
                    try {
                      final r = await Api.sharePost(p.id);
                      if (mounted && r['shareCount'] != null) setState(() => shareCount = (r['shareCount'] as num).toInt());
                    } catch (_) {}
                    await SharePlus.instance.share(ShareParams(text: '${p.caption.isEmpty ? 'شاهد هذا المنشور على SocialNova' : p.caption}\n${p.mediaUrl}'));
                  },
                ),
                const SizedBox(width: 20),
                _actionButton(
                  icon: Icons.repeat_rounded,
                  count: repostCount,
                  active: reposted,
                  onTap: () async {
                    final old = reposted;
                    setState(() { reposted = !reposted; repostCount += reposted ? 1 : -1; });
                    try {
                      final r = await Api.repost(p.id);
                      if (!mounted) return;
                      final now = r['reposted'] == true;
                      setState(() { reposted = now; if (r['repostCount'] != null) repostCount = (r['repostCount'] as num).toInt(); });
                    } catch (_) {
                      if (mounted) setState(() { reposted = old; repostCount += old ? 1 : -1; });
                    }
                  },
                ),
                const SizedBox(width: 20),
                _actionButton(
                  icon: Icons.mode_comment_outlined,
                  count: p.commentCount,
                  onTap: () => showComments(context, p, widget.onChanged),
                ),
                const SizedBox(width: 20),
                _actionButton(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  count: likeCount,
                  active: liked,
                  activeColor: SN.pink,
                  onTap: () async {
                    final old = liked;
                    setState(() { liked = !liked; likeCount += liked ? 1 : -1; });
                    try {
                      final r = await Api.like(p.id);
                      if (mounted) setState(() => liked = r['liked'] == true);
                    } catch (_) {
                      if (mounted) setState(() { liked = old; likeCount += old ? 1 : -1; });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showComments(BuildContext context, PostM post, VoidCallback? onChanged) async {
  final ctrl = TextEditingController();
  var comments = List<Map<String, dynamic>>.from(post.comments);
  var busy = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: SN.bg1,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .68,
          child: Column(
            children: [
              const SizedBox(height: 14),
              const Text('التعليقات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Divider(color: SN.strokeSoft),
              Expanded(
                child: comments.isEmpty
                    ? const EmptyState(text: 'لا توجد تعليقات بعد', icon: Icons.mode_comment_outlined)
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final c in comments)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => openProfile(ctx, '${(c['author'] ?? {})['id'] ?? ''}'),
                                    child: SNav(url: '${(c['author'] ?? {})['avatarUrl'] ?? ''}', name: '${(c['author'] ?? {})['displayName'] ?? ''}', size: 36),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${(c['author'] ?? {})['displayName'] ?? ''}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text('${c['body'] ?? ''}', style: const TextStyle(fontSize: 13, height: 1.5)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      final cid='${c['id'] ?? ''}';
                                      final aid='${(c['author'] ?? {})['id'] ?? ''}';
                                      if(v=='delete' && cid.isNotEmpty){ try { await Api.deleteComment(cid); comments.removeWhere((x)=>'${x['id']??''}'==cid); setLocal((){}); } catch(e){ toast(ctx,e.toString().replaceFirst('Exception: ','')); } }
                                      if(v=='edit' && cid.isNotEmpty && aid=='${Api.me?['id']??''}'){
                                        final ec=TextEditingController(text:'${c['body']??''}');
                                        final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(title:const Text('تعديل التعليق'),content:TextField(controller:ec,maxLines:4),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ'))]));
                                        if(ok==true){try{await Api.editComment(cid,ec.text.trim()); final i=comments.indexWhere((x)=>'${x['id']??''}'==cid);if(i>=0)comments[i]={...comments[i],'body':ec.text.trim()};setLocal((){});}catch(e){toast(ctx,e.toString().replaceFirst('Exception: ',''));}}
                                      }
                                    },
                                    itemBuilder:(_){final mine='${(c['author']??{})['id']??''}'=='${Api.me?['id']??''}';final owner=post.author.id=='${Api.me?['id']??''}';return [if(mine)const PopupMenuItem(value:'edit',child:Text('تعديل')),if(mine||owner)const PopupMenuItem(value:'delete',child:Text('حذف')),];},
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const Divider(color: SN.strokeSoft),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(hintText: 'اكتب تعليقًا...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (ctrl.text.trim().isEmpty) return;
                              setLocal(() => busy = true);
                              try {
                                await Api.comment(post.id, ctrl.text.trim());
                                final me = Api.me ?? {};
                                comments = [
                                  ...comments,
                                  {'body': ctrl.text.trim(), 'author': me},
                                ];
                                ctrl.clear();
                              } catch (e) {
                                toast(ctx, e.toString().replaceFirst('Exception: ', ''));
                              }
                              setLocal(() => busy = false);
                              onChanged?.call();
                            },
                      icon: const Icon(Icons.send_rounded, color: SN.violet),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  ctrl.dispose();
}

// ---------------------------------------------------------------------------
// Reels
// ---------------------------------------------------------------------------
class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key, this.isVisible = true});
  final bool isVisible;
  @override State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  late Future<List<dynamic>> _future;
  bool _showFollowing = false;
  int _activeReel = 0;
  @override void initState(){super.initState();_future=Api.reels();}
  void _switchReels(bool following){
    if (_showFollowing == following) return;
    setState(() { _showFollowing = following; _future = following ? Api.followingReels() : Api.reels(); });
  }

  Future<void> _upload() async {
    final picker=ImagePicker();
    try {
      final f=await picker.pickVideo(source:ImageSource.gallery,maxDuration:const Duration(minutes:3));
      if(f==null)return;
      final result=await openPublishEditor(context,mediaPath:f.path,mediaType:'VIDEO',reel:true);
      if(!mounted)return;
      if(result!=null){toast(context,'تم نشر الريل 🎬');setState(()=>_future=Api.reels());}
    }catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}
  }

  Future<void> _comments(ReelM r) async {
    final ctrl=TextEditingController();
    var comments=r.comments;
    await showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:SN.bg1,builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.of(ctx).viewInsets.bottom),
      child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[
        const Padding(padding:EdgeInsets.all(14),child:Text('التعليقات',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold))),
        Expanded(child:comments.isEmpty?const EmptyState(text:'لا توجد تعليقات بعد',icon:Icons.mode_comment_outlined):ListView.builder(itemCount:comments.length,itemBuilder:(c,i){final x=comments[i];final a=Map<String,dynamic>.from((x['author']??{}) as Map);return ListTile(leading:SNav(url:'${a['avatarUrl']??''}',name:'${a['displayName']??a['username']??'User'}',size:38),title:Text('${a['displayName']??a['username']??''}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),subtitle:Text('${x['body']??''}',style:const TextStyle(color:Colors.white70)),trailing:PopupMenuButton<String>(onSelected:(v)async{final cid='${x['id']??''}';final mine='${a['id']??''}'=='${Api.me?['id']??''}';if(v=='delete'){try{await Api.deleteReelComment(cid);comments.removeWhere((q)=>'${q['id']??''}'==cid);setSheet((){});}catch(e){toast(ctx,e.toString().replaceFirst('Exception: ',''));}}if(v=='edit'&&mine){final ec=TextEditingController(text:'${x['body']??''}');final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(title:const Text('تعديل التعليق'),content:TextField(controller:ec,maxLines:3),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('حفظ'))]));if(ok==true){try{await Api.editReelComment(cid,ec.text.trim());final i=comments.indexWhere((q)=>'${q['id']??''}'==cid);if(i>=0)comments[i]={...comments[i],'body':ec.text.trim()};setSheet((){});}catch(e){toast(ctx,e.toString().replaceFirst('Exception: ',''));}}}},itemBuilder:(_)=>[if('${a['id']??''}'=='${Api.me?['id']??''}')const PopupMenuItem(value:'edit',child:Text('تعديل')),if('${a['id']??''}'=='${Api.me?['id']??''}'||r.author.isMe)const PopupMenuItem(value:'delete',child:Text('حذف'))]));})),
        Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:TextField(controller:ctrl,style:const TextStyle(color:Colors.white),decoration:InputDecoration(hintText:'اكتب تعليقًا...',hintStyle:const TextStyle(color:Colors.white54),filled:true,fillColor:Colors.white10,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(24)),borderSide:BorderSide.none)))),const SizedBox(width:8),IconButton(onPressed:()async{final t=ctrl.text.trim();if(t.isEmpty)return;final x=await Api.commentReel(r.id,t);comments=[x,...comments];ctrl.clear();setSheet((){});},icon:const Icon(Icons.send_rounded,color:Colors.white))]))
      ])),
    )));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Colors.black,
    floatingActionButton:FloatingActionButton(backgroundColor:SN.pink,onPressed:_upload,child:const Icon(Icons.video_call_rounded,color:Colors.white)),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,8,12,6),child:Row(children:[
        Expanded(child:TextButton(onPressed:()=>_switchReels(false),child:Text('لك',style:TextStyle(fontWeight:FontWeight.w800,color:_showFollowing?Colors.white70:SN.violet)))),
        Expanded(child:TextButton(onPressed:()=>_switchReels(true),child:Text('متابعة',style:TextStyle(fontWeight:FontWeight.w800,color:_showFollowing?SN.violet:Colors.white70)))),
      ])),
      Expanded(child:FutureBuilder<List<dynamic>>(future:_future,builder:(c,snap){
        if(snap.connectionState==ConnectionState.waiting)return const LoadingBox();
        if(snap.hasError)return EmptyState(text:'${snap.error}'.replaceFirst('Exception: ',''));
        final reels=snap.data??[];
        if(reels.isEmpty)return EmptyState(text:_showFollowing?'لا توجد ريلز من الحسابات التي تتابعها بعد.':'لا توجد ريلز متاحة بعد. اضغط + لرفع أول فيديو.',icon:Icons.movie_outlined);
        return PageView.builder(scrollDirection:Axis.vertical,itemCount:reels.length,itemBuilder:(c,i){
          final r=ReelM(Map<String,dynamic>.from(reels[i] as Map));
          return _ReelCard(key: ValueKey(r.id), r:r, active:i==_activeReel && widget.isVisible, onChanged:()=>setState(()=>_future=_showFollowing?Api.followingReels():Api.reels()), onComments:()=>_comments(r));
        },onPageChanged:(i){setState(()=>_activeReel=i);try{Api.viewReel(ReelM(Map<String,dynamic>.from(reels[i] as Map)).id);}catch(_){} });
      }))
    ]))
  );
}

class _ReelCard extends StatefulWidget {
  const _ReelCard({super.key, required this.r, required this.active, required this.onChanged, required this.onComments});
  final ReelM r; final bool active; final VoidCallback onChanged; final VoidCallback onComments;
  @override State<_ReelCard> createState()=>_ReelCardState();
}
class _ReelCardState extends State<_ReelCard>{
  late bool liked, following;
  late final ValueNotifier<bool> _muted; late int likes,comments,shares,views;
  bool _showMute = false;
  DateTime? _muteShownAt;
  @override void initState(){super.initState();_muted=ValueNotifier<bool>(false);liked=widget.r.likedByMe;following=widget.r.author.followingMe;likes=widget.r.likeCount;comments=widget.r.commentCount;shares=widget.r.shareCount;views=widget.r.views;}
  Future<void> _like()async{final old=liked;setState(() { liked = !old; likes += liked ? 1 : -1; });try{final x=await Api.likeReel(widget.r.id);if(mounted)setState(() { liked = x['liked'] == true; likes = (x['likeCount'] ?? likes) as int; });}catch(_){if(mounted)setState(() { liked = old; likes += old ? 1 : -1; });}}
  Future<void> _share()async{try{final x=await Api.shareReel(widget.r.id);if(mounted)setState(() => shares = (x['shareCount'] ?? shares) as int);await SharePlus.instance.share(ShareParams(text:'شاهد هذا الريل على SocialNova\n${widget.r.videoUrl}'));}catch(_) {}}
  @override void didUpdateWidget(covariant _ReelCard old){super.didUpdateWidget(old); if(old.active!=widget.active && !widget.active){ setState(() => _showMute = false); } }
  void _tapVideo(){
    setState(() { _showMute = true; _muteShownAt = DateTime.now(); });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted || !_showMute || _muteShownAt == null) return;
      if (DateTime.now().difference(_muteShownAt!).inMilliseconds >= 2800) setState(() => _showMute = false);
    });
  }
  Future<void> _toggleFollow()async{if(widget.r.author.isMe)return;final old=following;setState(()=>following=!old);try{await Api.follow(widget.r.author.id);}catch(_){if(mounted)setState(()=>following=old);}}
  @override void dispose(){_muted.dispose();super.dispose();}
  @override Widget build(BuildContext context){final r=widget.r;return Stack(fit:StackFit.expand,children:[
    Positioned.fill(child:Transform.rotate(angle:r.rotationDegrees*3.141592653589793/180,child:VideoBox(url:r.videoUrl,autoPlay:true,playbackActive:widget.active,radius:0,musicUrl:r.musicUrl,muteNotifier:_muted,onTap:_tapVideo))),
    Positioned.fill(child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black.withOpacity(.75)]))))),
    if (_showMute && widget.active)
      Positioned(
        left: 24,
        top: MediaQuery.of(context).size.height * .40,
        child: Material(
          color: Colors.black.withValues(alpha: .58),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () { _muted.value = !_muted.value; _tapVideo(); },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Icon(_muted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    Positioned(
      left: 14,
      right: 82,
      bottom: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SNav(url: r.author.avatarUrl, name: r.author.displayName, size: 42, ring: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.author.displayName.isEmpty ? r.author.username : r.author.displayName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (r.author.isMe)
                IconButton(
                  onPressed: widget.onChanged,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
            ],
          ),
          if (r.title.isNotEmpty)
            Text(
              r.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          if (r.caption.isNotEmpty)
            Text(
              r.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          if (r.musicTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Flexible(child: Text(r.musicTitle, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ),
    ),

    Positioned(left:0,right:0,bottom:18,child:Center(child:Container(decoration:BoxDecoration(color:Colors.black.withValues(alpha:.62),shape:BoxShape.circle,border:Border.all(color:Colors.white24)),child:PopupMenuButton<String>(tooltip:'المزيد',icon:const Icon(Icons.add_rounded,color:Colors.white,size:32),onSelected:(v){if(v=='share')_share();},itemBuilder:(_)=>const [PopupMenuItem(value:'share',child:ListTile(leading:Icon(Icons.share_rounded),title:Text('مشاركة الريلز')))])))),
    Positioned(right:10,bottom:38,child:Column(children:[_ReelAction(icon:liked?Icons.favorite:Icons.favorite_border,count:likes,color:liked?Colors.redAccent:Colors.white,onTap:_like),_ReelAction(icon:Icons.mode_comment_outlined,count:comments,onTap:widget.onComments),if(!r.author.isMe)_ReelAction(icon:following?Icons.person:Icons.person_add_alt_1,count:0,color:following?SN.violet:Colors.white,label:following?'متابَع':'متابعة',onTap:_toggleFollow),_ReelAction(icon:Icons.card_giftcard_rounded,count:0,onTap:()=>showGiftPicker(context,receiverId:r.author.id,receiverName:r.author.displayName,contextType:'REEL',contextId:r.id))]))
  ]);}
}
class _ReelAction extends StatelessWidget {
  const _ReelAction({required this.icon, required this.count, required this.onTap, this.color = Colors.white, this.label});
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final Color color;
  final String? label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black.withOpacity(.3), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 2),
          Text(label ?? '$count', style: TextStyle(color: label != null ? color : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search + notifications
// ---------------------------------------------------------------------------
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ctrl = TextEditingController();
  List<dynamic> results = [];
  bool busy = false;
  bool searched = false;
  bool isSuggestion = false;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  /// Fills the screen with real accounts so it is never an empty void, and so
  /// a brand-new install can discover other users without knowing a handle.
  Future<void> _loadSuggested() async {
    setState(() => busy = true);
    try {
      final r = await Api.suggestedUsers();
      if (!mounted) return;
      setState(() {
        results = r;
        isSuggestion = true;
      });
    } catch (e) {
      if (!mounted) return;
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> run(String q) async {
    if (q.trim().length < 2) return;
    setState(() => busy = true);
    try {
      final r = await Api.searchUsers(q.trim());
      if (!mounted) return;
      setState(() {
        results = r;
        searched = true;
      });
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
          onSubmitted: run,
          decoration: const InputDecoration(
            hintText: 'ابحث عن مستخدم...',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          IconButton(onPressed: () => run(ctrl.text), icon: const Icon(Icons.search)),
        ],
      ),
      body: busy
          ? const LoadingBox()
          : results.isEmpty
              ? EmptyState(
                  text: searched ? 'لا توجد نتائج' : 'اكتب اسمًا للبحث',
                  icon: Icons.person_search_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                      child: Row(
                        children: [
                          Icon(isSuggestion ? Icons.auto_awesome : Icons.search,
                              size: 16, color: SN.cyan),
                          const SizedBox(width: 8),
                          Text(isSuggestion ? 'أشخاص قد تعرفهم' : 'نتائج البحث',
                              style: const TextStyle(
                                  color: SN.cyan, fontWeight: FontWeight.w800, fontSize: 13)),
                          const Spacer(),
                          if (isSuggestion)
                            TextButton(onPressed: _loadSuggested, child: const Text('تحديث')),
                        ],
                      ),
                    ),
                    for (final u in results)
                      GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => openProfile(context, '${u['id']}'),
                              child: SNav(url: '${(u as Map)['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? ''}', size: 46, ring: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => openProfile(context, '${u['id']}'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Flexible(child: Text('${u['displayName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                                        const SizedBox(width: 5),
                                        VerifiedBadge(tier: '${u['verificationTier'] ?? (u['isVerified'] == true ? 'NORMAL' : 'NONE')}', size: 15),
                                      ]),
                                      Text('@${u['username'] ?? ''}', style: const TextStyle(color: SN.textMut, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'مراسلة',
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(userId: '${u['id']}', name: '${u['displayName'] ?? u['username']}', avatar: '${u['avatarUrl'] ?? ''}'))),
                              icon: const Icon(Icons.chat_bubble_outline, size: 19),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.notifications();
    Api.readNotifications().catchError((_) => null);
  }

  IconData _icon(String t) => switch (t) {
        'LIKE' => Icons.favorite,
        'COMMENT' => Icons.mode_comment,
        'FOLLOW' => Icons.person_add,
        'MESSAGE' => Icons.chat,
        'GROUP' => Icons.groups,
        'LIVE' => Icons.sensors,
        'VERIFICATION' => Icons.verified,
        _ => Icons.notifications,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: SN.bg1, title: const Text('الإشعارات')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
          final items = snap.data ?? [];
          if (items.isEmpty) return const EmptyState(text: 'لا توجد إشعارات', icon: Icons.notifications_off_outlined);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final n in items)
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ((n as Map)['read'] == true ? SN.bg3 : SN.violet.withValues(alpha: .22)),
                        ),
                        child: Icon(_icon('${n['type']}'), color: SN.violet, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${n['text']}', style: const TextStyle(fontSize: 13.5))),
                      Text(timeAgo(n['createdAt']), style: const TextStyle(color: SN.textMut, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

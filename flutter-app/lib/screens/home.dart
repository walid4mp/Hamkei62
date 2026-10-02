import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../core/localization.dart';

import '../core/api.dart';
import '../core/nova_audio.dart';
import '../core/push_notifications.dart';
import '../core/app_update.dart';
import '../core/reels_playback.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/nova_ui.dart';
import '../models/models.dart';
import 'profile.dart';
import 'social.dart';
import 'editor.dart';
import 'music_picker.dart';
import 'content_studio.dart';
import 'creator_content_center.dart';
import 'nova_tv.dart';
import 'store.dart';
import 'wallet.dart';
import 'digital_id.dart';

/// Opens the most relevant live/content surface directly from the profile ring.
/// This is used from Home/Post/Reels so a LIVE or STORY badge is actionable
/// instead of first navigating to the profile and making the user search again.
Future<void> openStatusForUser(BuildContext context, UserM u) async => openUserStatusOrProfile(context, u);

/// Main application shell — matches the supplied SocialNova mobile reference:
/// Home / Explore / Create / Messages / Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  void _openCreate() {
    snClick();
    showCreateChooser(context, onDone: () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const FeedPage(),
      ReelsPage(isVisible: index == 1),
      const SizedBox.shrink(),
      const MessengerPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: SN.bg0,
      body: Stack(
        children: [
          IndexedStack(index: index, children: pages),
          if (index != 1) const _MiniReelOverlay(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _NovaBottomBar(
          selected: index,
          onSelect: (v) {
            if (v == 2) {
              _openCreate();
              return;
            }
            snClick();
            setState(() => index = v);
          },
        ),
      ),
    );
  }
}


class _MiniReelOverlay extends StatefulWidget {
  const _MiniReelOverlay();
  @override State<_MiniReelOverlay> createState() => _MiniReelOverlayState();
}

class _MiniReelOverlayState extends State<_MiniReelOverlay> {
  ReelsPlaybackState? _value;
  @override
  void initState() {
    super.initState();
    _value = ReelsPlaybackController.i.state.value;
    ReelsPlaybackController.i.state.addListener(_changed);
  }
  @override
  void dispose() {
    ReelsPlaybackController.i.state.removeListener(_changed);
    super.dispose();
  }
  void _changed() { if (mounted) setState(() => _value = ReelsPlaybackController.i.state.value); }

  @override
  Widget build(BuildContext context) {
    final r = _value;
    if (r == null || r.videoUrl.trim().isEmpty) return const SizedBox.shrink();
    final bottom = 86.0 + MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: 12,
      bottom: bottom,
      width: 118,
      height: 176,
      child: Material(
        color: Colors.black,
        elevation: 18,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoBox(url: r.videoUrl, autoPlay: true, playbackActive: true, height: 176, radius: 0, musicUrl: r.musicUrl),
            Positioned.fill(child: Material(type: MaterialType.transparency, child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReelsPage(isVisible: true))), child: const SizedBox.expand()))),
            Positioned(left: 7, right: 7, bottom: 7, child: IgnorePointer(child: Text(r.author.isEmpty ? r.title : r.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))),
            Positioned(top: 5, right: 5, child: GestureDetector(onTap: ReelsPlaybackController.i.clear, child: Container(width: 25, height: 25, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)))),
          ],
        ),
      ),
    );
  }
}

class _NovaBottomBar extends StatelessWidget {
  const _NovaBottomBar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, IconData active, String label})>[
      (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'الرئيسية'),
      (icon: Icons.play_circle_outline_rounded, active: Icons.play_circle_fill_rounded, label: 'Reels'),
      (icon: Icons.add_rounded, active: Icons.add_rounded, label: 'إنشاء'),
      (icon: Icons.chat_bubble_outline_rounded, active: Icons.chat_bubble_rounded, label: 'الرسائل'),
      (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'الملف الشخصي'),
    ];
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFF050B1D),
        border: const Border(top: BorderSide(color: SN.strokeSoft)),
        boxShadow: [BoxShadow(color: SN.indigo.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          for (var i = 0; i < items.length; i ++ )
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                child: Center(
                  child: i == 2
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: SN.grad,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .34), blurRadius: 20)],
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  selected == i ? items[i].active : items[i].icon,
                                  size: 27,
                                  color: selected == i ? SN.cyan : SN.textMut,
                                ),
                                if (i == 2)
                                  Positioned(
                                    top: -5, right: -8,
                                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: SN.pink, shape: BoxShape.circle)),
                                  ),
                                if (i == 3)
                                  ValueListenableBuilder<int>(
                                    valueListenable: unreadMessagesNotifier,
                                    builder: (_, count, __) => count > 0
                                        ? Positioned(
                                            top: -8, right: -13,
                                            child: Container(
                                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              decoration: BoxDecoration(color: SN.pink, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF050B1D), width: 2)),
                                              alignment: Alignment.center,
                                              child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[i].label,
                              style: TextStyle(
                                color: selected == i ? SN.cyan : SN.textSec,
                                fontSize: 10.5,
                                fontWeight: selected == i ? FontWeight.w800 : FontWeight.w600,
                              ),
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

// ---------------------------------------------------------------------------
// Feed
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
class _NovaHomeHeader extends StatelessWidget {
  const _NovaHomeHeader();

  @override
  Widget build(BuildContext context) {
    final me = Api.me;
    final avatar = me?['avatarUrl']?.toString() ?? me?['avatar']?.toString() ?? '';
    final name = me?['displayName']?.toString() ?? me?['username']?.toString() ?? '';
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF050A1B),
        border: Border(bottom: BorderSide(color: SN.strokeSoft)),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: SN.grad,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .28), blurRadius: 18)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/socialnova_launcher_reference.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 27),
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Text('SocialNova', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const Spacer(),
          IconButton(
            tooltip: 'بحث',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
            icon: const Icon(Icons.search_rounded, size: 29, color: SN.textPri),
          ),
          IconButton(
            tooltip: 'Nova TV',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NovaTvPage())),
            icon: const Icon(Icons.movie_filter_rounded, size: 27, color: SN.cyan),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'الإشعارات',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                icon: const Icon(Icons.notifications_none_rounded, size: 29, color: SN.textPri),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: SN.pink, shape: BoxShape.circle)),
              ),
            ],
          ),
          IconButton(
            tooltip: 'المزيد',
            onPressed: () => _showHomeMoreMenu(context),
            icon: const Icon(Icons.more_vert_rounded, size: 29, color: SN.textPri),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SNav(url: avatar, name: name, size: 42, ring: true),
                Positioned(right: -1, bottom: 0, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: SN.green, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF050A1B), width: 2)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showHomeMoreMenu(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context, backgroundColor: SN.bg1, showDragHandle: true,
    builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ListTile(title: Text('SocialNova', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), subtitle: Text('كل الأدوات المهمة في مكان واحد')),
      ListTile(leading: const Icon(Icons.search_rounded, color: SN.cyan), title: const Text('البحث'), onTap: () => Navigator.pop(c, 'search')),
      ListTile(leading: const Icon(Icons.storefront_rounded, color: SN.gold), title: const Text('متجر SocialNova'), subtitle: const Text('Marketplace'), onTap: () => Navigator.pop(c, 'store')),
      ListTile(leading: const Icon(Icons.shopping_cart_checkout_rounded, color: SN.violet), title: const Text('متجر العملات / Google Play'), onTap: () => Navigator.pop(c, 'wallet')),
      ListTile(leading: const Icon(Icons.movie_filter_rounded, color: SN.cyan), title: const Text('Nova TV'), onTap: () => Navigator.pop(c, 'tv')),
      ListTile(leading: const Icon(Icons.auto_awesome_rounded, color: SN.pink), title: const Text('استوديو المحتوى'), onTap: () => Navigator.pop(c, 'studio')),
      ListTile(leading: const Icon(Icons.badge_rounded, color: SN.gold), title: const Text('البطاقة الرقمية'), onTap: () => Navigator.pop(c, 'id')),
      ListTile(leading: const Icon(Icons.settings_rounded, color: SN.textSec), title: const Text('الإعدادات والخصوصية'), onTap: () => Navigator.pop(c, 'settings')),
    ])),
  );
  if (!context.mounted || choice == null) return;
  final pages = <String, Widget>{
    'search': const SearchPage(), 'store': const StorePage(), 'wallet': const WalletPage(), 'tv': const NovaTvPage(),
    'studio': const ContentStudioPage(), 'id': const DigitalIdPage(), 'settings': const SettingsPage(),
  };
  final page = pages[choice]; if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _NovaFeedTabs extends StatelessWidget {
  const _NovaFeedTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = ['لك', 'أتابعه', 'الأصدقاء', 'استكشف', 'مباشر'];
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF050A1B),
        border: Border(bottom: BorderSide(color: SN.strokeSoft)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: SizedBox(
              width: 76,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Center(child: Text(tabs[i], style: TextStyle(color: active ? SN.textPri : SN.textSec, fontSize: 14, fontWeight: active ? FontWeight.w900 : FontWeight.w600))),
                  if (active) Container(width: 48, height: 3, decoration: BoxDecoration(color: SN.cyan, borderRadius: BorderRadius.circular(3), boxShadow: [BoxShadow(color: SN.cyan.withValues(alpha: .45), blurRadius: 10)])),
                  if (i == 4) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: SN.pink, borderRadius: BorderRadius.circular(6)), child: const Text('LIVE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white)))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late Future<List<dynamic>> _future;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadFeed(0);
  }

  Future<List<dynamic>> _loadFeed(int tab) async {
    final rows = await Api.feed();
    if (tab == 0) return rows;
    if (tab == 3) return rows;
    if (tab == 4) return rows;
    final me = '${Api.me?['id'] ?? ''}';
    if (me.isEmpty) return rows;
    try {
      final following = (await Api.following(me)).map((e) => '${(e as Map)['id'] ?? ''}').where((e) => e.isNotEmpty).toSet();
      if (tab == 1) return rows.where((e) => following.contains('${(e as Map)['author']?['id'] ?? ''}')).toList();
      final followers = (await Api.followers(me)).map((e) => '${(e as Map)['id'] ?? ''}').where((e) => e.isNotEmpty).toSet();
      final friends = following.intersection(followers);
      return rows.where((e) => friends.contains('${(e as Map)['author']?['id'] ?? ''}')).toList();
    } catch (_) {
      return rows;
    }
  }

  void _selectTab(int tab) {
    snClick();
    if (tab == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
      return;
    }
    if (tab == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage()));
      return;
    }
    setState(() {
      _tab = tab;
      _future = _loadFeed(tab);
    });
  }

  void reload() => setState(() => _future = _loadFeed(_tab));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _NovaHomeHeader(),
            _NovaFeedTabs(selected: _tab, onSelected: _selectTab),
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
                        if (_tab == 0) const _HomeDiscoveryBlocks(),
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

      final me = UserM(await Api.me$());
      final verified = me.isVerified;
      var durationHours = 24;
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
          const SizedBox(height: 8),
          if (verified) ...[
            DropdownButtonFormField<int>(value: durationHours, decoration: const InputDecoration(labelText: 'مدة القصة (للحساب الموثق)'), items: const [6, 12, 24, 48].map((h) => DropdownMenuItem(value: h, child: Text('$h ساعة'))).toList(), onChanged: (v) { if (v != null) set(() => durationHours = v); }),
          ] else
            Align(alignment: AlignmentDirectional.centerStart, child: Text(L10n.t('مدة القصة: 24 ساعة • المدد الأخرى متاحة للحسابات الموثقة فقط'), style: TextStyle(fontSize: 12, color: SN.textMut))),
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
      final publishSettings = await ContentStudio.showStoryPublish(context, initial: {'audience': 'EVERYONE', 'commentsEnabled': true, 'repostEnabled': true});
      if (publishSettings == null) { caption.dispose(); musicTitle.dispose(); return; }
      if (publishSettings['saveDraft'] == true) {
        await ContentStudio.saveDraft({'type': 'story', 'mediaPath': file.path, 'mediaType': mediaType, 'caption': caption.text.trim(), 'musicTitle': musicTitle.text.trim(), 'musicUrl': musicUrl, 'rotationDegrees': rotation, 'overlayEmoji': emoji, 'durationHours': durationHours});
        caption.dispose(); musicTitle.dispose();
        if (mounted) toast(context, 'تم حفظ الستوري كمسودة على الجهاز 📝');
        return;
      }
      await Api.createStory(finalMediaUrl, mediaType, caption.text.trim(), rotationDegrees: rotation, overlayEmoji: emoji, musicUrl: musicUrl, musicTitle: musicTitle.text.trim(), durationHours: durationHours, audienceMode: ({'PUBLIC':'EVERYONE','FOLLOWERS':'FOLLOWERS','CLOSE_FRIENDS':'CLOSE_FRIENDS','FRIENDS':'HIDDEN'}['${publishSettings['audience'] ?? 'PUBLIC'}'] ?? 'EVERYONE'), replyEnabled: publishSettings['commentsEnabled'] != false, archived: publishSettings['archived'] == true, scheduledAt: publishSettings['scheduledAt'] as String?, autoHideViews: 0);
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
    return Container(
      height: 134,
      decoration: const BoxDecoration(
        color: Color(0xFF050A1B),
        border: Border(bottom: BorderSide(color: SN.strokeSoft)),
      ),
      child: SizedBox(
        height: 134,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, snap) {
          final items = (snap.data ?? []).map((e) => StoryM(Map<String, dynamic>.from(e as Map))).toList();
          // Group by author so one ring opens the author's whole sequence with
          // progress bars and auto-advance, instead of a single frozen story.
          final groups = <String, List<StoryM>>{};
          for (final s in items) {
            final key = s.author.id.isEmpty ? s.id : s.author.id;
            groups.putIfAbsent(key, () => <StoryM>[]).add(s);
          }
          final authorGroups = groups.values.toList();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              _addTile(),
              for (var g = 0; g < authorGroups.length; g++) _storyTile(authorGroups[g], g),
            ],
          );
        },
      ),
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
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SN.bg3,
                  border: Border.all(color: SN.violet.withValues(alpha: .6), width: 1.5),
                ),
                child: Icon(Icons.add_a_photo_outlined, color: SN.violet),
              ),
              const SizedBox(height: 6),
              Text('قصتك', style: TextStyle(fontSize: 11, color: SN.textSec)),
            ],
          ),
        ),
      );

  Widget _storyTile(List<StoryM> list, int i) {
    final s = list.first;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoryViewer(story: s, queue: list)),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                StatusAvatar(url: s.author.avatarUrl, name: s.author.displayName, size: 74, status: s.author.statusRings, onSegmentTap: (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewer(story: s, queue: list)))),
                if (list.length > 1)
                  Positioned(
                    left: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: SN.pink, borderRadius: BorderRadius.circular(10), border: Border.all(color: SN.bg0, width: 2)),
                      child: Text('${list.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 78,
              child: Text(
                s.author.displayName.isEmpty ? s.author.username : s.author.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: SN.textSec),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDiscoveryBlocks extends StatefulWidget {
  const _HomeDiscoveryBlocks();
  @override State<_HomeDiscoveryBlocks> createState() => _HomeDiscoveryBlocksState();
}

class _HomeDiscoveryBlocksState extends State<_HomeDiscoveryBlocks> {
  late Future<List<dynamic>> _liveFuture;
  late Future<List<dynamic>> _reelsFuture;
  @override void initState() { super.initState(); _liveFuture = Api.live(); _reelsFuture = Api.reels(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    _promo(),
    FutureBuilder<List<dynamic>>(future: _liveFuture, builder: (_, s) {
      final rows = (s.data ?? []).map((e) => Map<String,dynamic>.from(e as Map)).where((e) => '${e['roomName'] ?? ''}'.isNotEmpty).take(8).toList();
      return rows.isEmpty ? const SizedBox.shrink() : _live(rows);
    }),
    FutureBuilder<List<dynamic>>(future: _reelsFuture, builder: (_, s) {
      final rows = (s.data ?? []).map((e) => Map<String,dynamic>.from(e as Map)).take(10).toList();
      return rows.isEmpty ? const SizedBox.shrink() : _reels(rows);
    }),
  ]);

  Widget _promo() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage())),
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xFF7028FF), Color(0xFF294CFF), Color(0xFF168FEA)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SN.cyan.withValues(alpha: .55)),
          boxShadow: [BoxShadow(color: SN.violet.withValues(alpha: .24), blurRadius: 22)],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Stack(children: [
            Align(alignment: Alignment.centerRight, child: Icon(Icons.card_giftcard_rounded, size: 58, color: Colors.white24)),
            Align(alignment: Alignment.centerLeft, child: Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 24)),
            Center(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اكتشف عالم الهدايا', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('أرسل هدايا للمبدعين المفضلين لديك', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
      ),
    ),
  );

  Widget _live(List<Map<String,dynamic>> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    NovaSectionTitle(title: 'البث المباشر', action: 'عرض الكل', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage()))),
    SizedBox(height: 218, child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14), scrollDirection: Axis.horizontal, itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final r = rows[i]; final h = r['host'] is Map ? Map<String,dynamic>.from(r['host'] as Map) : <String,dynamic>{};
        return SizedBox(width: 170, child: NovaLiveTile(
          title: '${r['title'] ?? 'بث مباشر'}', hostName: '${h['displayName'] ?? h['username'] ?? ''}', hostAvatar: '${h['avatarUrl'] ?? ''}',
          viewers: r['viewerCount'] is num ? (r['viewerCount'] as num).toInt() : (int.tryParse('${r['viewerCount'] ?? 0}') ?? 0), gradientSeed: i,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomPage(title: '${r['title'] ?? 'بث مباشر'}', roomName: '${r['roomName'] ?? ''}', roomId: '${r['id'] ?? ''}', hostId: '${h['id'] ?? ''}'))),
        ));
      },
    )),
  ]);

  Widget _reels(List<Map<String,dynamic>> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    NovaSectionTitle(title: 'مقاطع قصيرة', action: 'عرض الكل', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsPage()))),
    SizedBox(height: 184, child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), scrollDirection: Axis.horizontal, itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) => _HomeReelTile(reel: ReelM(rows[i]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsPage()))),
    )),
    const SizedBox(height: 4),
  ]);
}

class _HomeReelTile extends StatelessWidget {
  const _HomeReelTile({required this.reel, required this.onTap});
  final ReelM reel; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final a = reel.author; final thumb = '${reel.j['thumbnailUrl'] ?? reel.j['coverUrl'] ?? ''}'.trim();
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Container(
      width: 118, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: SN.strokeSoft), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF101C45), Color(0xFF071027)])),
      child: Stack(fit: StackFit.expand, children: [
        if (thumb.isNotEmpty) Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()) else Container(decoration: const BoxDecoration(gradient: SN.grad)),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
        const Positioned(top: 8, left: 8, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 23)),
        Positioned(left: 8, right: 8, bottom: 8, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reel.title.isNotEmpty ? reel.title : (reel.caption.isNotEmpty ? reel.caption : 'مقطع قصير'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 6), Row(children: [SNav(url: a.avatarUrl, name: a.displayName, size: 22), const SizedBox(width: 5), Expanded(child: Text(a.displayName.isNotEmpty ? a.displayName : a.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9)))])
        ])),
      ]),
    ));
  }
}

class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.story, this.queue});
  final StoryM story;

  /// Optional full sequence of stories for the same author. When provided the
  /// viewer becomes a proper story player: progress bars, auto-advance and
  /// tap/swipe navigation instead of a single frozen frame.
  final List<StoryM>? queue;

  @override State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  final _reply = TextEditingController();
  bool _liked = false;
  int _likes = 0;
  bool _sending = false;
  late final ValueNotifier<bool> _storyMuted;
  bool _showStoryMute = false;
  late final AnimationController _progress;
  late List<StoryM> _list;
  int _index = 0;

  StoryM get _story => _list[_index];

  @override
  void initState() {
    super.initState();
    _list = (widget.queue != null && widget.queue!.isNotEmpty) ? List<StoryM>.from(widget.queue!) : <StoryM>[widget.story];
    final startAt = _list.indexWhere((s) => s.id == widget.story.id);
    _index = startAt < 0 ? 0 : startAt;
    _storyMuted = ValueNotifier<bool>(false);
    _progress = AnimationController(vsync: this, duration: _durationFor(_story))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _next(auto: true); });
    _enterStory();
  }

  Duration _durationFor(StoryM s) =>
      s.type == 'VIDEO' ? const Duration(seconds: 15) : const Duration(seconds: 5);

  void _enterStory() {
    _liked = _story.likedByMe;
    _likes = _story.reactionCount;
    _showStoryMute = false;
    Api.viewStory(_story.id).catchError((_) {});
    final music = _story.musicUrl.trim();
    if (music.isNotEmpty) {
      NovaAudio.i.playMusic(music);
    } else {
      NovaAudio.i.stopMusic();
    }
    _progress
      ..duration = _durationFor(_story)
      ..forward(from: 0);
  }

  void _next({bool auto = false}) {
    if (_index < _list.length - 1) {
      setState(() => _index++);
      _enterStory();
    } else if (auto) {
      Navigator.maybePop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _enterStory();
    } else {
      _progress.forward(from: 0);
    }
  }

  Future<void> _heart() async {
    final old = _liked;
    setState(() { _liked = !old; _likes += old ? -1 : 1; });
    try {
      final r = await Api.reactStory(_story.id);
      if (!mounted) return;
      setState(() => _liked = r['liked'] == true);
    } catch (_) {
      if (mounted) setState(() { _liked = old; _likes += old ? 1 : -1; });
    }
  }

  Future<void> _replyToStory() async {
    if (!_story.replyEnabled) { toast(context, 'الردود على هذه الستوري متوقفة'); return; }
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.replyToStory(_story.id, text);
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

  /// Progress bars for the whole author sequence: completed segments are full,
  /// the active one tracks the animation, the rest stay empty.
  Widget _progressBars() {
    return Row(
      children: [
        for (var i = 0; i < _list.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: i == _index
                  ? AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : LinearProgressIndicator(
                      value: i < _index ? 1 : 0,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
            ),
          ),
      ],
    );
  }

  String _remaining(String raw) { final d=DateTime.tryParse(raw)?.toLocal(); if(d==null)return 'غير معروف'; final m=d.difference(DateTime.now()).inMinutes; if(m<=0)return 'انتهت'; if(m<60)return '$m د'; final h=m~/60; if(h<24)return '$h س'; return '${h~/24} يوم'; }

  String _ago(String raw) { final d=DateTime.tryParse(raw)?.toLocal(); if(d==null)return 'غير معروف'; final m=DateTime.now().difference(d).inMinutes; if(m<1)return 'الآن'; if(m<60)return '$m د'; final h=m~/60; if(h<24)return '$h س'; return '${h~/24} يوم'; }

  @override
  void dispose() {
    _progress.dispose();
    NovaAudio.i.stopMusic();
    _reply.dispose();
    _storyMuted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Row(children: [
          GestureDetector(onTap: () => openUserStatusOrProfile(context, story.author), child: SNav(url: story.author.avatarUrl, name: story.author.displayName, size: 34, ring: true)),
          const SizedBox(width: 10),
          Expanded(child: InkWell(onTap: () => openProfile(context, story.author.id), child: Text(story.author.displayName.isEmpty ? story.author.username : story.author.displayName, style: const TextStyle(fontSize: 15)))),
          if (story.musicUrl.isNotEmpty) const Icon(Icons.music_note_rounded, color: Colors.white70),
        ]),
        actions: [
          if (story.author.id == '${Api.me?['id'] ?? ''}') OwnerContentMoreButton(type: 'story', id: story.id, initial: story.j, onChanged: () { if (mounted) setState(() {}); }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _progressBars(),
          ),
        ),
      ),
      body: Stack(children: [
        Center(child: Transform.rotate(
          angle: story.rotationDegrees * 3.141592653589793 / 180,
          key: ValueKey(story.id),
          child: story.type == 'VIDEO'
              ? VideoBox(url: story.mediaUrl, autoPlay: true, playbackActive: true, height: 520, radius: 0, musicUrl: story.musicUrl, muteNotifier: _storyMuted, onTap: () => setState(() => _showStoryMute = true))
              : Image.network(story.mediaUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const EmptyState(text: 'تعذّر تحميل القصة', icon: Icons.broken_image_outlined)),
        )),
        // Tap zones: right two thirds advance, left third goes back.
        // A downward swipe closes the viewer, matching stories/reels muscle memory.
        Positioned.fill(
          bottom: 140,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 350) Navigator.maybePop(context);
            },
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _prev,
                    onLongPress: () => _progress.stop(),
                    onLongPressUp: () => _progress.forward(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _next(),
                    onLongPress: () => _progress.stop(),
                    onLongPressUp: () => _progress.forward(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showStoryMute && story.type == 'VIDEO')
          Positioned(left: 20, top: MediaQuery.of(context).size.height * .40, child: Material(color: Colors.black54, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: () => setState(() => _storyMuted.value = !_storyMuted.value), child: Padding(padding: const EdgeInsets.all(14), child: Icon(_storyMuted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 28))))) ,
        if (story.overlayEmoji.isNotEmpty) Positioned(top: 28, right: 24, child: Text(story.overlayEmoji, style: const TextStyle(fontSize: 34))),
        if (story.musicTitle.isNotEmpty) Positioned(left: 18, right: 18, bottom: 94, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.music_note, color: Colors.white, size: 18), const SizedBox(width: 7), Expanded(child: Text(story.musicTitle, style: const TextStyle(color: Colors.white, fontSize: 13)))]))),
        Positioned(left: 18, right: 18, top: MediaQuery.of(context).padding.top + 58, child: Text('منشورة منذ ${_ago(story.createdAt)} • تنتهي بعد ${_remaining(story.expiresAt)}${_list.length > 1 ? ' • ${_index + 1}/${_list.length}' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center)),
        if (story.caption.isNotEmpty) Positioned(left: 18, right: 18, bottom: 145, child: Center(child: mentionText(context, story.caption, style: const TextStyle(color: Colors.white, fontSize: 15), maxLines: 4, overflow: TextOverflow.ellipsis))),
        Positioned(left: 10, right: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 10, child: SafeArea(top: false, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (story.replyEnabled) Expanded(child: Container(constraints: const BoxConstraints(minHeight: 50), padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(27), border: Border.all(color: Colors.white38)), child: TextField(controller: _reply, minLines: 1, maxLines: 4, style: const TextStyle(color: Colors.white), textInputAction: TextInputAction.send, onSubmitted: (_) => _replyToStory(), decoration: const InputDecoration(hintText: 'اكتب ردًا على القصة...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none, prefixIcon: Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20))))),
          if (story.replyEnabled) ...[const SizedBox(width: 4), IconButton(onPressed: _sending ? null : _replyToStory, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 29))] else const SizedBox(width: 8),
          InkWell(onTap: _heart, borderRadius: BorderRadius.circular(30), child: Padding(padding: const EdgeInsets.all(6), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? Colors.redAccent : Colors.white, size: 30), Text('$_likes', style: const TextStyle(color: Colors.white, fontSize: 10))]))),
        ]))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Post composer
// ---------------------------------------------------------------------------
Future<void> showReelComposer(BuildContext context, {VoidCallback? onDone}) async {
  final picker = ImagePicker();
  try {
    final f = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (f == null || !context.mounted) return;
    final result = await openPublishEditor(context, mediaPath: f.path, mediaType: 'VIDEO', reel: true);
    if (result != null) onDone?.call();
  } catch (e) {
    if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
  }
}

Future<void> showCreateChooser(BuildContext context, {VoidCallback? onDone}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: SN.bg1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 14),
        const Text('إنشاء جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _CreateChoice(icon: Icons.post_add_rounded, title: 'منشور', subtitle: 'صورة، فيديو أو نص', onTap: () => Navigator.pop(ctx, 'post'))),
          const SizedBox(width: 12),
          Expanded(child: _CreateChoice(icon: Icons.movie_creation_outlined, title: 'Reels', subtitle: 'فيديو عمودي قصير', onTap: () => Navigator.pop(ctx, 'reel'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _CreateChoice(icon: Icons.movie_filter_rounded, title: 'فيلم / مسلسل', subtitle: 'نشر فيلم وحلقات ومواسم', onTap: () => Navigator.pop(ctx, 'tv'))),
          const SizedBox(width: 12),
          Expanded(child: _CreateChoice(icon: Icons.workspace_premium_rounded, title: 'اشتراك', subtitle: 'إعداد باقة المشتركين', onTap: () => Navigator.pop(ctx, 'subscription'))),
        ]),
      ]),
    )),
  );
  if (!context.mounted) return;
  if (choice == 'post') await showComposer(context, onDone: onDone);
  if (choice == 'reel') await showReelComposer(context, onDone: onDone);
  if (choice == 'tv') await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatorContentCenterPage(initialTab: 1)));
  if (choice == 'subscription') await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatorContentCenterPage(initialTab: 2)));
}

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(gradient: SN.grad, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 27)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ]),
    ),
  );
}

Future<void> showComposer(BuildContext context, {VoidCallback? onDone}) async {
  final picker = ImagePicker();
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: SN.bg1,
    builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: EdgeInsets.all(16), child: Text(L10n.t('إنشاء منشور'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
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
    WidgetsBinding.instance.addPostFrameCallback((_) { Api.viewPost(widget.post.id).catchError((_) {}); });
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: active ? (activeColor ?? SN.violet) : SN.textSec),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text('$count', style: TextStyle(fontSize: 14, color: active ? (activeColor ?? SN.violet) : SN.textSec, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      );

  /// Menu shown on posts that are not mine: report / copy link.
  Widget _moreMenu(PostM p) => PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz_rounded, color: SN.textMut),
        color: SN.bg2,
        onSelected: (v) async {
          if (v == 'report') {
            final reason = await _askReportReason();
            if (reason == null || reason.trim().isEmpty) return;
            try {
              await Api.reportPost(p.id, reason.trim());
              if (mounted) toast(context, 'تم إرسال البلاغ، شكرًا لك 🛡️');
            } catch (e) {
              if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
            }
          } else if (v == 'copy') {
            await Clipboard.setData(ClipboardData(text: '${p.mediaUrl.isNotEmpty ? p.mediaUrl : p.id}'));
            if (mounted) toast(context, 'تم نسخ رابط المنشور 🔗');
          } else if (v == 'moddelete') {
            try {
              await Api.adminDeletePost(p.id);
              if (mounted) { toast(context, 'تم حذف المنشور (إشراف) 🛡️'); widget.onChanged?.call(); }
            } catch (e) {
              if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.flag_outlined, color: Colors.redAccent), title: Text('إبلاغ عن المنشور'))),
          const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.link_rounded), title: Text('نسخ رابط المنشور'))),
          if (Api.can('POST_MODERATION'))
            const PopupMenuItem(value: 'moddelete', child: ListTile(leading: Icon(Icons.delete_forever_outlined, color: Colors.redAccent), title: Text('حذف المنشور (إشراف)'))),
        ],
      );

  Future<String?> _askReportReason() async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('سبب الإبلاغ'),
          content: TextField(controller: ctrl, maxLines: 3, autofocus: true, decoration: const InputDecoration(hintText: 'اكتب سبب الإبلاغ…')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dctx, ctrl.text), child: const Text('إرسال البلاغ')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: const BoxDecoration(color: Color(0xFF050A1B), border: Border(bottom: BorderSide(color: SN.strokeSoft))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => openStatusForUser(context, p.author),
                child: StatusAvatar(url: p.author.avatarUrl, name: p.author.displayName, size: 44, status: p.author.statusRings, onSegmentTap: (_) => openStatusForUser(context, p.author)),
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
                        style: TextStyle(color: SN.textMut, fontSize: 11)),
                  ],
                ),
              ),
              if (p.author.isMe)
                OwnerContentMoreButton(type: 'post', id: p.id, initial: p.j, onEdit: () async { final edited = await openPublishEditor(context, mediaPath: p.mediaUrl, mediaType: p.type, initialCaption: p.caption, initialTitle: p.title, initialMusic: p.musicTitle, initialMusicUrl: p.musicUrl, initialOverlayText: p.overlayText, initialOverlayEmoji: p.overlayEmoji, initialOverlayImageUrl: p.overlayImageUrl, initialRotation: p.rotationDegrees, existingId: p.id); if (edited != null) widget.onChanged?.call(); }, onChanged: widget.onChanged)
              else
                _moreMenu(p),
            ],
          ),
          if (p.title.isNotEmpty) ...[const SizedBox(height: 12), Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))],
          if (p.caption.isNotEmpty) ...[const SizedBox(height: 8), Text(p.caption, maxLines: 7, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.6))],
          if (p.type == 'IMAGE' && p.mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: SN.strokeSoft), boxShadow: [BoxShadow(color: SN.cyan.withValues(alpha: .06), blurRadius: 16)]),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1.02,
                child: Transform.rotate(
                  angle: p.rotationDegrees * 3.141592653589793 / 180,
                  child: Image.network(
                    p.mediaUrl, fit: BoxFit.cover, width: double.infinity,
                    loadingBuilder: (c, child, progress) => progress == null ? child : Container(color: SN.bg2, alignment: Alignment.center, child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.2))),
                    errorBuilder: (_, __, ___) => const SizedBox(height: 160, child: EmptyState(text: 'تعذّر تحميل الصورة', icon: Icons.broken_image_outlined)),
                  ),
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
                Icon(Icons.music_note, size: 15, color: SN.cyan),
                const SizedBox(width: 6),
                Text(p.musicTitle, style: TextStyle(color: SN.cyan, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white.withValues(alpha: .06)),
          const SizedBox(height: 4),
          Row(
            children: [
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
              const SizedBox(width: 18),
              _actionButton(
                icon: Icons.mode_comment_outlined,
                count: p.commentCount,
                onTap: () => showComments(context, p, widget.onChanged),
              ),
              const SizedBox(width: 18),
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
              const SizedBox(width: 18),
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
              const Spacer(),
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
                  child: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 26, color: bookmarked ? SN.violet : SN.textSec),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showComments(BuildContext context, PostM post, VoidCallback? onChanged) async {
  final ctrl = TextEditingController();
  var comments = <Map<String, dynamic>>[];
  var suggestions = <dynamic>[];
  var busy = false;
  var loaded = false;
  String mentionQuery = '';
  String? replyToId;
  String replyToName = '';

  Future<void> refreshComments(StateSetter setLocal) async {
    try {
      final rows = await Api.postComments(post.id);
      comments = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      loaded = true;
    } catch (_) {
      comments = List<Map<String, dynamic>>.from(post.comments);
      loaded = true;
    }
    setLocal(() {});
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: SN.bg1,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        if (!loaded && !busy) {
          Future.microtask(() => refreshComments(setLocal));
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .76,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Text(L10n.t('التعليقات'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Divider(color: SN.strokeSoft),
                Expanded(
                  child: comments.isEmpty
                      ? const EmptyState(text: 'لا توجد تعليقات بعد', icon: Icons.mode_comment_outlined)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: comments.length,
                          itemBuilder: (_, i) {
                            final c = comments[i];
                            final a = Map<String, dynamic>.from((c['author'] ?? {}) as Map);
                            final name = '${a['displayName'] ?? ''}'.trim().isEmpty ? '${a['username'] ?? 'مستخدم'}' : '${a['displayName']}';
                            final mine = '${a['id'] ?? ''}' == '${Api.me?['id'] ?? ''}';
                            bool liked = c['likedByMe'] == true;
                            int hearts = (c['likeCount'] as num?)?.toInt() ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                StatusAvatar(url: '${a['avatarUrl'] ?? ''}', name: name, size: 42, status: a['statusRings'] is Map ? Map<String,dynamic>.from(a['statusRings'] as Map) : const <String,dynamic>{}, onSegmentTap: (_) => openUserStatusOrProfile(ctx, UserM(a))),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [Expanded(child: Text(name, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))), if(!mine) TextButton(onPressed:() async { try { final r=await Api.follow('${a['id']??''}'); if(ctx.mounted) toast(ctx,r['following']==true?'تمت المتابعة':(r['requested']==true?'تم إرسال طلب المتابعة':'تم إلغاء المتابعة')); } catch(e) { if(ctx.mounted) toast(ctx,e.toString().replaceFirst('Exception: ','')); } }, style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:6),minimumSize:const Size(0,28),tapTargetSize:MaterialTapTargetSize.shrinkWrap), child:const Text('متابعة +',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)))]),
                                  const SizedBox(height:2), mentionText(ctx, '${c['body'] ?? ''}', style: const TextStyle(fontSize: 14, height: 1.45)),
                                  const SizedBox(height: 4),
                                  Row(children:[Text(timeAgo(c['createdAt']),style:TextStyle(fontSize:10,color:SN.textMut)),const SizedBox(width:12),TextButton.icon(style:TextButton.styleFrom(padding:EdgeInsets.zero,minimumSize:const Size(0,28),tapTargetSize:MaterialTapTargetSize.shrinkWrap),onPressed:(){setLocal(() { replyToId='${c['id']??''}'; replyToName=name; });ctrl.text='@${a['username']??''} ';ctrl.selection=TextSelection.collapsed(offset:ctrl.text.length);},icon:Icon(Icons.reply_rounded,size:15,color:SN.violet),label:Text('رد',style:TextStyle(fontSize:11,color:SN.violet)))])
                                ])),
                                Column(mainAxisSize:MainAxisSize.min,children:[IconButton(visualDensity:VisualDensity.compact,padding:EdgeInsets.zero,onPressed:() async { final old=liked; setLocal(() { liked=!old; hearts += liked?1:-1; }); try { final r=await Api.likeComment('${c['id']??''}'); c['likedByMe']=r['liked']==true; c['likeCount']=r['likeCount']; setLocal((){liked=c['likedByMe']==true;hearts=(c['likeCount'] as num).toInt();}); } catch(_) { setLocal(() { liked=old; hearts += old?1:-1; }); } }, icon:Icon(liked?Icons.favorite_rounded:Icons.favorite_border_rounded,color:liked?Colors.redAccent:SN.textMut,size:20)), Text('$hearts ♥',style:TextStyle(fontSize:10,color:SN.textMut,fontWeight:FontWeight.w700))]),
                                PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      final cid = '${c['id'] ?? ''}';
                                      if (v == 'delete') {
                                        try { await Api.deleteComment(cid); comments.removeWhere((x) => '${x['id'] ?? ''}' == cid); setLocal(() {}); } catch (e) { toast(ctx, e.toString().replaceFirst('Exception: ', '')); }
                                      } else if (v == 'edit' && mine) {
                                        final ec = TextEditingController(text: '${c['body'] ?? ''}');
                                        final ok = await showDialog<bool>(context: ctx, builder: (d) => AlertDialog(title: const Text('تعديل التعليق'), content: TextField(controller: ec, maxLines: 4), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ'))]));
                                        if (ok == true) { try { await Api.editComment(cid, ec.text.trim()); final i2 = comments.indexWhere((x) => '${x['id'] ?? ''}' == cid); if (i2 >= 0) comments[i2] = {...comments[i2], 'body': ec.text.trim()}; setLocal(() {}); } catch (e) { toast(ctx, e.toString().replaceFirst('Exception: ', '')); } }
                                      }
                                    },
                                    itemBuilder: (_) => [if (mine) PopupMenuItem(value: 'edit', child: Text(L10n.t('تعديل'))), if (mine || post.author.id == '${Api.me?['id'] ?? ''}') PopupMenuItem(value: 'delete', child: Text(L10n.t('حذف')))],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (suggestions.isNotEmpty)
                  SizedBox(
                    height: 58,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final u = Map<String, dynamic>.from(suggestions[i] as Map);
                        final un = '${u['username'] ?? ''}';
                        return ActionChip(
                          avatar: SNav(url: '${u['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? un}', size: 28),
                          label: Text('@$un'),
                          onPressed: () {
                            final text = ctrl.text;
                            final m = RegExp(r'@[^\s]*$').firstMatch(text);
                            ctrl.text = m == null ? '$text@$un ' : '${text.substring(0, m.start)}@$un ';
                            ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
                            setLocal(() { suggestions = []; mentionQuery = ''; });
                          },
                        );
                      },
                    ),
                  ),
                Divider(color: SN.strokeSoft),
                if (replyToId != null) Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: Row(children: [
                    Expanded(child: Text('الرد على $replyToName', style: TextStyle(color: SN.violet, fontSize: 12, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => setLocal(() { replyToId = null; replyToName = ''; }), icon: Icon(Icons.close_rounded, size: 18, color: SN.textSec)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'اكتب تعليقًا...  @لذكر شخص'),
                      onChanged: (value) async {
                        final m = RegExp(r'@([^\s@]*)$').firstMatch(value);
                        if (m == null || m.group(1)!.isEmpty) { setLocal(() { suggestions = []; mentionQuery = ''; }); return; }
                        final q = m.group(1)!;
                        if (q == mentionQuery) return;
                        mentionQuery = q;
                        try { final rows = await Api.searchUsers(q); if (mentionQuery == q) setLocal(() => suggestions = rows.take(8).toList()); } catch (_) {}
                      },
                    )),
                    const SizedBox(width: 8),
                    IconButton(onPressed: busy ? null : () async {
                      final t = ctrl.text.trim(); if (t.isEmpty) return;
                      setLocal(() => busy = true);
                      try { final x = await Api.comment(post.id, t, parentId: replyToId); comments = [...comments, x]; ctrl.clear(); suggestions = []; setLocal(() { replyToId = null; replyToName = ''; }); onChanged?.call(); } catch (e) { toast(ctx, e.toString().replaceFirst('Exception: ', '')); }
                      setLocal(() => busy = false);
                    }, icon: Icon(Icons.send_rounded, color: SN.violet)),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key, this.isVisible = true});
  final bool isVisible;
  @override State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  late Future<List<dynamic>> _future;
  bool followingOnly = false;
  int active = 0;
  @override void initState(){super.initState();_future=Api.reels();}
  void _switch(bool v){setState((){followingOnly=v;_future=v?Api.followingReels():Api.reels();});}
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor:Colors.black,body:FutureBuilder<List<dynamic>>(future:_future,builder:(context,snap){
      if(snap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(snap.hasError)return Center(child:Text('${snap.error}',style:const TextStyle(color:Colors.white)));
      final rows=snap.data??const <dynamic>[];
      if(rows.isNotEmpty && widget.isVisible && ReelsPlaybackController.i.state.value == null){ final rr=ReelM(Map<String,dynamic>.from(rows[active] as Map)); ReelsPlaybackController.i.setCurrent(ReelsPlaybackState(videoUrl:rr.videoUrl,musicUrl:rr.musicUrl,title:rr.title.isEmpty?rr.caption:rr.title,author:rr.author.displayName,authorAvatar:rr.author.avatarUrl,index:active)); }
      if(rows.isEmpty)return const Center(child:Text('لا توجد Reels حاليًا',style:TextStyle(color:Colors.white)));
      return Stack(children:[PageView.builder(scrollDirection:Axis.vertical,itemCount:rows.length,onPageChanged:(i){setState(()=>active=i); final rr=ReelM(Map<String,dynamic>.from(rows[i] as Map)); ReelsPlaybackController.i.setCurrent(ReelsPlaybackState(videoUrl:rr.videoUrl,musicUrl:rr.musicUrl,title:rr.title.isEmpty?rr.caption:rr.title,author:rr.author.displayName,authorAvatar:rr.author.avatarUrl,index:i));},itemBuilder:(_,i){final r=ReelM(Map<String,dynamic>.from(rows[i] as Map));return _ReelCard(r:r,active:i==active,isVisible:widget.isVisible,onComments:()=>_comments(r),onChanged:()=>setState((){}));}),Positioned(top:MediaQuery.of(context).padding.top+10,left:12,right:12,child:Row(children:[_tab('لك',!followingOnly,()=>_switch(false)),_tab('أتابعه',followingOnly,()=>_switch(true)),const Spacer(),IconButton(onPressed:()=>Navigator.maybePop(context),icon:const Icon(Icons.close_rounded,color:Colors.white))]))]);
    }));
  }
  Widget _tab(String text,bool selected,VoidCallback onTap)=>TextButton(onPressed:onTap,child:Text(text,style:TextStyle(color:selected?Colors.white:Colors.white54,fontWeight:FontWeight.w900)));
  Future<void> _comments(ReelM r) async {
    final ctrl = TextEditingController();
    var comments = <Map<String, dynamic>>[];
    try {
      comments = (await Api.reelComments(r.id)).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      comments = r.comments;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SN.bg1,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.of(ctx).size.height * .75,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('التعليقات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: comments.length,
                itemBuilder: (_, i) {
                  final c = comments[i];
                  final a = Map<String, dynamic>.from((c['author'] ?? {}) as Map);
                  final name = '${a['displayName'] ?? a['username'] ?? 'مستخدم'}';
                  final liked = c['likedByMe'] == true;
                  final hearts = (c['likeCount'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    leading: SNav(url: '${a['avatarUrl'] ?? ''}', name: name, size: 38),
                    title: GestureDetector(onTap: () => openProfile(ctx, '${a['id'] ?? ''}'), child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    subtitle: Text('${c['body'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                    trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        onPressed: () async {
                          try {
                            final x = await Api.likeReelComment('${c['id'] ?? ''}');
                            c['likedByMe'] = x['liked'] == true;
                            c['likeCount'] = x['likeCount'];
                            setSheet(() {});
                          } catch (_) {}
                        },
                        icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? Colors.redAccent : Colors.white54),
                      ),
                      Text('$hearts ♥', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 10, right: 10, bottom: MediaQuery.of(ctx).viewInsets.bottom + 10, top: 6),
              child: Row(children: [
                Expanded(child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'اكتب تعليقًا...', hintStyle: TextStyle(color: Colors.white54)))),
                IconButton(
                  onPressed: () async {
                    final body = ctrl.text.trim();
                    if (body.isEmpty) return;
                    try {
                      await Api.commentReel(r.id, body);
                      ctrl.clear();
                      comments = (await Api.reelComments(r.id)).map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      setSheet(() {});
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.send_rounded, color: SN.violet),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
  }
}

class _ReelCard extends StatefulWidget {
  const _ReelCard({required this.r, required this.active, required this.isVisible, required this.onComments, required this.onChanged});
  final ReelM r;
  final bool active;
  final bool isVisible;
  final VoidCallback onComments;
  final VoidCallback onChanged;
  @override State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  @override void initState(){super.initState(); if(widget.active && widget.isVisible){ ReelsPlaybackController.i.setCurrent(ReelsPlaybackState(videoUrl:widget.r.videoUrl,musicUrl:widget.r.musicUrl,title:widget.r.title.isEmpty?widget.r.caption:widget.r.title,author:widget.r.author.displayName,authorAvatar:widget.r.author.avatarUrl)); }}
  @override void didUpdateWidget(covariant _ReelCard oldWidget){super.didUpdateWidget(oldWidget); if(widget.active && widget.isVisible && (!oldWidget.active || !oldWidget.isVisible)){ ReelsPlaybackController.i.setCurrent(ReelsPlaybackState(videoUrl:widget.r.videoUrl,musicUrl:widget.r.musicUrl,title:widget.r.title.isEmpty?widget.r.caption:widget.r.title,author:widget.r.author.displayName,authorAvatar:widget.r.author.avatarUrl)); }}
  late bool liked = widget.r.likedByMe;
  late bool saved = widget.r.savedByMe;
  late bool reposted = widget.r.repostedByMe;
  late bool following = widget.r.author.j['following'] == true || widget.r.author.j['followedByMe'] == true;
  late int likes = widget.r.likeCount;
  late int shares = widget.r.shareCount;
  late int reposts = widget.r.repostCount;
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  @override void dispose() { muted.dispose(); super.dispose(); }

  Future<void> _like() async {
    try {
      final x = await Api.likeReel(widget.r.id);
      if (!mounted) return;
      setState(() { liked = x['liked'] == true; likes = (x['likeCount'] as num?)?.toInt() ?? likes; });
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final x = await Api.bookmarkReel(widget.r.id);
      if (!mounted) return;
      setState(() { saved = x['saved'] == true; });
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _share() async {
    try {
      final x = await Api.shareReel(widget.r.id);
      if (!mounted) return;
      setState(() { shares = (x['shareCount'] as num?)?.toInt() ?? (shares + 1); });
      await SharePlus.instance.share(ShareParams(text: '${widget.r.caption.isEmpty ? 'شاهد هذا الريلز على SocialNova' : widget.r.caption}\n${widget.r.videoUrl}'));
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _repost() async {
    try {
      final x = await Api.repostReel(widget.r.id);
      if (!mounted) return;
      setState(() { reposted = x['reposted'] == true; reposts = (x['repostCount'] as num?)?.toInt() ?? reposts; });
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _follow() async {
    final id = widget.r.author.id;
    if (id.isEmpty || widget.r.author.isMe) return;
    try {
      final x = await Api.follow(id);
      if (!mounted) return;
      setState(() { following = x['following'] == true || x['followed'] == true; });
      widget.onChanged();
    } catch (_) {}
  }

  @override Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final author = widget.r.author;
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        onDoubleTap: _like,
        child: VideoBox(url: widget.r.videoUrl, autoPlay: widget.active, playbackActive: widget.active && widget.isVisible, height: h, radius: 0, musicUrl: widget.r.musicUrl, muteNotifier: muted),
      ),
      Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: .72)]))))),
      if (widget.r.overlayText.isNotEmpty) Positioned(left: 20, right: 80, top: h * .22, child: Text(widget.r.overlayText, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900), maxLines: 3, overflow: TextOverflow.ellipsis)),
      if (widget.r.overlayEmoji.isNotEmpty) Positioned(left: 20, top: h * .30, child: Text(widget.r.overlayEmoji, style: const TextStyle(fontSize: 42))),
      Positioned(left: 14, right: 78, bottom: 34, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusAvatar(url: author.avatarUrl, name: author.displayName, size: 44, status: author.statusRings, onSegmentTap: (_) => openUserStatusOrProfile(context, author)),
          const SizedBox(width: 9),
          Expanded(child: GestureDetector(onTap: () => openProfile(context, author.id), child: Text(author.displayName.isEmpty ? '@${author.username}' : author.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis))),
          if (!author.isMe) OutlinedButton(onPressed: _follow, child: Text(following ? 'متابع' : 'متابعة')),
        ]),
        const SizedBox(height: 8),
        if (widget.r.caption.isNotEmpty) Text(widget.r.caption, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
        if (widget.r.musicTitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('♫ ${widget.r.musicTitle}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
        if (widget.r.isEpisodePreview && widget.r.seriesId.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailPage(id: widget.r.seriesId))), icon: const Icon(Icons.video_library_outlined), label: Text(widget.r.totalEpisodes > 0 ? 'شاهد كل الحلقات (${widget.r.totalEpisodes})' : 'شاهد كل الحلقات'))),
      ])),
      Positioned(right: 10, bottom: 26, child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: _like, icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? Colors.redAccent : Colors.white, size: 32)),
        Text('$likes', style: const TextStyle(color: Colors.white, fontSize: 11)),
        IconButton(onPressed: widget.onComments, icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 30)),
        Text('${widget.r.commentCount}', style: const TextStyle(color: Colors.white, fontSize: 11)),
        IconButton(onPressed: _share, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 30)),
        Text('$shares', style: const TextStyle(color: Colors.white, fontSize: 11)),
        IconButton(onPressed: _repost, icon: Icon(Icons.repeat_rounded, color: reposted ? SN.violet : Colors.white, size: 30)),
        Text('$reposts', style: const TextStyle(color: Colors.white, fontSize: 11)),
        IconButton(onPressed: _save, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Colors.white, size: 30)),
        IconButton(onPressed: () => muted.value = !muted.value, icon: ValueListenableBuilder<bool>(valueListenable: muted, builder: (_, m, __) => Icon(m ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 28))),
      ])),
    ]);
  }
}

class ActivityPage extends StatefulWidget { const ActivityPage({super.key}); @override State<ActivityPage> createState()=>_ActivityPageState(); }
class _ActivityPageState extends State<ActivityPage> {
  late Future<Map<String,dynamic>> _future;
  @override void initState(){super.initState();_future=Api.activity();}
  Future<void> _refresh() async { setState(()=>_future=Api.activity()); await _future; }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('نشاطاتي'),actions:[IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh_rounded))]),body:FutureBuilder<Map<String,dynamic>>(future:_future,builder:(c,s){if(s.connectionState==ConnectionState.waiting)return const LoadingBox();if(s.hasError)return EmptyState(text:'${s.error}'.replaceFirst('Exception: ',''));final d=s.data??{};return RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.fromLTRB(14,10,14,30),children:[
    _section('👀','ريلز شاهدتها',((d['views']??[]) as List), (x)=>_openReel(Map<String,dynamic>.from((x['reel']??{}) as Map))),
    _section('💬','تعليقاتي',((d['comments']??[]) as List), (x)=>_openReel(Map<String,dynamic>.from((x['reel']??{}) as Map))),
    _section('💬','تعليقاتي على المنشورات',((d['postComments']??[]) as List), (x)=>_openPost(Map<String,dynamic>.from((x['post']??{}) as Map))),
    _section('📝','منشوراتي',((d['posts']??[]) as List), (x)=>_openPost(Map<String,dynamic>.from(x as Map))),
    _section('❤️','منشورات أعجبتني',((d['likedPosts']??[]) as List), (x)=>_openPost(Map<String,dynamic>.from((x['post']??{}) as Map))),
    _section('🎬','ريلز أعجبتني',((d['likedReels']??[]) as List), (x)=>_openReel(Map<String,dynamic>.from((x['reel']??{}) as Map))),
  ]));}),);
  Widget _section(String e,String t,List items,void Function(dynamic) tap)=>Card(margin:EdgeInsets.only(bottom:12),child:ExpansionTile(leading:Text(e,style:TextStyle(fontSize:24)),title:Text(t,style:TextStyle(fontWeight:FontWeight.w900)),trailing:Text('${items.length}',style:TextStyle(fontWeight:FontWeight.w900)),children:items.isEmpty?[ListTile(title:Text(L10n.t('لا توجد عناصر بعد')))]:items.take(30).map((x){final m=Map<String,dynamic>.from(x as Map);final target=Map<String,dynamic>.from(((m['reel']??m['post'])??{}) as Map);final a=Map<String,dynamic>.from((target['author']??{}) as Map);final title='${target['caption']??target['title']??m['body']??''}';return ListTile(leading:SNav(url:'${a['avatarUrl']??''}',name:'${a['displayName']??a['username']??''}',size:44),title:Text(title.isEmpty?t:title,maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text('@${a['username']??''}'),trailing:Icon(Icons.play_circle_outline_rounded),onTap:()=>tap(x));}).toList()));
  void _openReel(Map<String,dynamic> r){if(r.isEmpty)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>ActivityReelPage(reel:r)));}
  void _openPost(Map<String,dynamic> p){if(p.isEmpty)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>ActivityPostPage(post:p)));}
}
class ActivityReelPage extends StatelessWidget { const ActivityReelPage({super.key,required this.reel}); final Map<String,dynamic> reel; @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text('${reel['author']?['displayName']??reel['author']?['username']??'Reels'}')),body:Center(child:VideoBox(url:'${reel['videoUrl']??''}',autoPlay:true,playbackActive:true,height:MediaQuery.of(context).size.height*.78,radius:0,musicUrl:'${reel['musicUrl']??''}'))); }
class ActivityPostPage extends StatelessWidget { const ActivityPostPage({super.key,required this.post}); final Map<String,dynamic> post; @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('منشور')),body:ListView(padding:const EdgeInsets.all(14),children:[if('${post['title']??''}'.isNotEmpty)Text('${post['title']}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),if('${post['caption']??''}'.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text('${post['caption']}')),if('${post['mediaUrl']??''}'.isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.network('${post['mediaUrl']}',fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(height:180,child:Center(child:Icon(Icons.broken_image_outlined,size:50)))))])); }

// ---------------------------------------------------------------------------
// Search + notifications
// ---------------------------------------------------------------------------
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ctrl = TextEditingController();
  Map<String,dynamic> data = {};
  bool busy = false;
  bool searched = false;
  List<dynamic> suggestions = [];

  @override void initState(){super.initState(); _loadSuggested();}
  @override void dispose(){ctrl.dispose();super.dispose();}

  Future<void> _loadSuggested() async {
    setState(()=>busy=true);
    try{
      final r=await Api.suggestedUsers();
      if(!mounted)return;
      setState(()=>suggestions=r);
    }catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> run(String q) async {
    final text=q.trim();
    if(text.length<2){if(mounted)toast(context,'اكتب حرفين على الأقل للبحث');return;}
    FocusScope.of(context).unfocus();
    setState(()=>busy=true);
    try{
      final r=await Api.globalSearch(text);
      if(!mounted)return;
      setState(() { data=r; searched=true; });
    }catch(e){if(mounted)toast(context,e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Widget _title(String icon,String title,int count)=>Padding(
    padding:const EdgeInsets.fromLTRB(4,16,4,9),
    child:Row(children:[Text(icon,style:const TextStyle(fontSize:18)),const SizedBox(width:8),Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(width:7),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:SN.violet.withValues(alpha: .14),borderRadius:BorderRadius.circular(9)),child:Text('$count',style:TextStyle(color:SN.cyan,fontSize:10,fontWeight:FontWeight.w800))),const Spacer()]),
  );

  Widget _userCard(Map<String,dynamic> u)=>GlassCard(padding:const EdgeInsets.all(11),child:Row(children:[
    GestureDetector(onTap:()=>openProfile(context,'${u['id']}'),child:SNav(url:'${u['avatarUrl']??''}',name:'${u['displayName']??u['username']??''}',size:48,ring:true)),
    const SizedBox(width:11),Expanded(child:InkWell(onTap:()=>openProfile(context,'${u['id']}'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Flexible(child:Text('${u['displayName']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800))),const SizedBox(width:5),VerifiedBadge(tier:'${u['verificationTier']??(u['isVerified']==true?'NORMAL':'NONE')}',size:14)]),Text('@${u['username']??''}',style:TextStyle(color:SN.textMut,fontSize:11)),if('${u['bio']??''}'.isNotEmpty)Text('${u['bio']}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:SN.textSec,fontSize:11))]))),
    IconButton(
      onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatPage(userId:'${u['id']}',name:'${u['displayName']??u['username']}',avatar:'${u['avatarUrl']??''}'))),
      icon:const Icon(Icons.chat_bubble_outline_rounded,size:19),
    ),
  ]));

  Widget _reelCard(Map<String,dynamic> r)=>GlassCard(padding:EdgeInsets.zero,child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ActivityReelPage(reel:r))),child:Row(children:[
    ClipRRect(borderRadius:const BorderRadius.horizontal(left:Radius.circular(20)),child:Container(width:92,height:112,decoration:BoxDecoration(gradient:SN.grad),child:const Center(child:Icon(Icons.play_circle_fill_rounded,color:Colors.white,size:42)))),
    Expanded(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r['title']??r['caption']??'فيديو'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text('@${r['author']?['username']??''}',style:TextStyle(color:SN.textMut,fontSize:11)),const SizedBox(height:5),Text('${r['views']??0} مشاهدة',style:TextStyle(color:SN.cyan,fontSize:11,fontWeight:FontWeight.w700))]))),
    const Padding(padding:EdgeInsets.all(10),child:Icon(Icons.chevron_left_rounded,color:SN.textMut))
  ])));

  Widget _postCard(Map<String,dynamic> p)=>GlassCard(padding:const EdgeInsets.all(12),child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ActivityPostPage(post:p))),child:Row(children:[
    Container(width:62,height:62,decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),color:SN.bg2,image:'${p['mediaUrl']??''}'.isEmpty?null:DecorationImage(image:NetworkImage('${p['mediaUrl']}'),fit:BoxFit.cover)),child:'${p['mediaUrl']??''}'.isEmpty?Icon(p['type']=='VIDEO'?Icons.videocam_rounded:Icons.article_rounded,color:SN.cyan):null),
    const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p['title']??p['caption']??'منشور'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:5),Text('@${p['author']?['username']??''}',style:TextStyle(color:SN.textMut,fontSize:11)),Text(p['type']=='VIDEO'?'فيديو عام':'منشور عام',style:TextStyle(color:SN.textSec,fontSize:10))])),const Icon(Icons.chevron_left_rounded,color:SN.textMut)
  ])));

  Widget _groupCard(Map<String,dynamic> g)=>GlassCard(padding:const EdgeInsets.all(12),child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupChatPage(groupId:'${g['id']}',name:'${g['name']}'))),child:Row(children:[
    Container(width:58,height:58,decoration:BoxDecoration(borderRadius:BorderRadius.circular(17),gradient:SN.grad,image:'${g['avatarUrl']??''}'.isEmpty?null:DecorationImage(image:NetworkImage('${g['avatarUrl']}'),fit:BoxFit.cover)),child:'${g['avatarUrl']??''}'.isEmpty?const Icon(Icons.groups_rounded,color:Colors.white,size:28):null),
    const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${g['name']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),Text('${((g['_count']??{}) as Map)['members']??0} عضو • مجموعة عامة',style:TextStyle(color:SN.textMut,fontSize:11)),if('${g['description']??''}'.isNotEmpty)Text('${g['description']}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:SN.textSec,fontSize:10))])),const Icon(Icons.chevron_left_rounded,color:SN.textMut)
  ])));

  Widget _liveCard(Map<String,dynamic> r)=>GlassCard(padding:const EdgeInsets.all(12),child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LiveRoomPage(title:'${r['title']}',roomName:'${r['roomName']}',hostId:'${r['host']?['id']??''}'))),child:Row(children:[
    Container(width:66,height:66,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:LinearGradient(colors:[SN.red,SN.violet])),child:Center(child:SNav(url:'${r['host']?['avatarUrl']??''}',name:'${r['host']?['displayName']??r['host']?['username']??''}',size:48,ring:true))),
    const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:SN.red,borderRadius:BorderRadius.circular(7)),child:const Text('LIVE',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))),const SizedBox(width:7),Expanded(child:Text('${r['title']??'بث مباشر'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)))]),const SizedBox(height:5),Text('${r['host']?['displayName']??r['host']?['username']??''} • ${r['viewerCount']??0} مشاهد',style:TextStyle(color:SN.textMut,fontSize:11))])),const Icon(Icons.play_arrow_rounded,color:SN.red)
  ])));

  Widget _storyCard(Map<String,dynamic> s)=>GlassCard(
    padding:const EdgeInsets.all(10),
    child:InkWell(
      onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StoryViewer(story:StoryM(s)))),
      child:Row(children:[
        Container(
          width:58,height:78,
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(15),
            gradient:SN.grad,
            image:'${s['mediaUrl']??''}'.isEmpty?null:DecorationImage(image:NetworkImage('${s['mediaUrl']}'),fit:BoxFit.cover),
          ),
          child:'${s['mediaUrl']??''}'.isEmpty?const Icon(Icons.auto_stories_rounded,color:Colors.white):null,
        ),
        const SizedBox(width:11),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${s['caption']??'ستوري'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:5),
          Text('@${s['author']?['username']??''}',style:TextStyle(color:SN.textMut,fontSize:11)),
        ])),
        const Icon(Icons.chevron_left_rounded,color:SN.textMut),
      ]),
    ),
  );

  @override Widget build(BuildContext context){
    final users=List<dynamic>.from(data['users']??[]), reels=List<dynamic>.from(data['reels']??[]), posts=List<dynamic>.from(data['posts']??[]), groups=List<dynamic>.from(data['groups']??[]), lives=List<dynamic>.from(data['live']??[]), stories=List<dynamic>.from(data['stories']??[]);
    final has=users.isNotEmpty||reels.isNotEmpty||posts.isNotEmpty||groups.isNotEmpty||lives.isNotEmpty||stories.isNotEmpty;
    return Scaffold(
      appBar:AppBar(backgroundColor:SN.bg1,title:TextField(controller:ctrl,autofocus:true,onSubmitted:run,decoration:const InputDecoration(hintText:'ابحث عن مستخدمين، فيديوهات، مجموعات، بث مباشر...',border:InputBorder.none,filled:false)),actions:[IconButton(onPressed:()=>run(ctrl.text),icon:const Icon(Icons.search_rounded))]),
      body:busy?const LoadingBox():!searched?ListView(padding:const EdgeInsets.all(12),children:[_title('✨','أشخاص قد تعرفهم',suggestions.length),...suggestions.take(20).map((x)=>_userCard(Map<String,dynamic>.from(x as Map)))]) : !has ? const EmptyState(text:'لا توجد نتائج مطابقة',icon:Icons.search_off_rounded) : ListView(padding:const EdgeInsets.fromLTRB(12,4,12,100),children:[
        if(users.isNotEmpty)...[_title('👤','المستخدمون',users.length),...users.map((x)=>_userCard(Map<String,dynamic>.from(x as Map)))],
        if(reels.isNotEmpty)...[_title('🎬','الفيديوهات و Reels',reels.length),...reels.map((x)=>_reelCard(Map<String,dynamic>.from(x as Map)))],
        if(posts.isNotEmpty)...[_title('📝','المنشورات',posts.length),...posts.map((x)=>_postCard(Map<String,dynamic>.from(x as Map)))],
        if(groups.isNotEmpty)...[_title('👥','المجموعات',groups.length),...groups.map((x)=>_groupCard(Map<String,dynamic>.from(x as Map)))],
        if(lives.isNotEmpty)...[_title('🔴','البث المباشر',lives.length),...lives.map((x)=>_liveCard(Map<String,dynamic>.from(x as Map)))],
        if(stories.isNotEmpty)...[_title('⭕','القصص',stories.length),...stories.map((x)=>_storyCard(Map<String,dynamic>.from(x as Map)))],
      ]),
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
  AppUpdateInfo? _appUpdate;

  @override
  void initState() {
    super.initState();
    _future = Api.notifications();
    Api.readNotifications().catchError((_) => null);
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    final update = await AppUpdateManager.check();
    if (mounted && update != null) setState(() => _appUpdate = update);
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
      appBar: AppBar(backgroundColor: SN.bg1, title: Text('الإشعارات')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
          if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
          final items = snap.data ?? [];
          if (items.isEmpty && _appUpdate == null) return const EmptyState(text: 'لا توجد إشعارات', icon: Icons.notifications_off_outlined);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (_appUpdate != null)
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: InkWell(
                    onTap: () => AppUpdateManager.showUpdateDialog(context, _appUpdate!),
                    child: Row(children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: SN.cyan.withValues(alpha: .18)), child: const Icon(Icons.system_update_alt_rounded, color: SN.cyan, size: 21)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('تحديث جديد لـ SocialNova', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('الإصدار ${_appUpdate!.versionName} متاح الآن — اضغط للتحديث.', style: TextStyle(color: SN.textSec, fontSize: 12)),
                      ])),
                      const Icon(Icons.chevron_left_rounded, color: SN.cyan),
                    ]),
                  ),
                ),
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
                      Text(timeAgo(n['createdAt']), style: TextStyle(color: SN.textMut, fontSize: 11)),
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

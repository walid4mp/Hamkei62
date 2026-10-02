import 'creator_rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api.dart';
import '../core/app_update.dart';
import '../core/creator_levels.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'digital_id.dart';
import '../models/models.dart';
import 'auth.dart';
import 'home.dart';
import 'social.dart';
import 'wallet.dart';
import 'content_studio.dart';
import 'max_privacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization.dart';
import '../core/push_notifications.dart';
import '../core/nova_audio.dart';

class _ProfileOpenEffectDialog extends StatefulWidget {
  const _ProfileOpenEffectDialog({required this.effect, required this.videoUrl, required this.durationMs});
  final String effect;
  final String videoUrl;
  final int durationMs;
  @override
  State<_ProfileOpenEffectDialog> createState() => _ProfileOpenEffectDialogState();
}

class _ProfileOpenEffectDialogState extends State<_ProfileOpenEffectDialog> with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _prepareVideo();
    Future.delayed(Duration(milliseconds: widget.durationMs.clamp(1000, 15000).toInt()), () { if (mounted) Navigator.of(context).pop(); });
  }
  Future<void> _prepareVideo() async {
    if (widget.videoUrl.isEmpty) return;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (mounted) { setState(() => _video = controller); } else { controller.dispose(); }
    } catch (_) {}
  }
  @override
  void dispose() { _video?.dispose(); _pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final video = _video;
    final gradient = switch (widget.effect) {
      'GOLDEN_AURA' => const RadialGradient(colors: [Color(0xFFFFF3A3), Color(0xFFFFB300), Color(0x00000000)]),
      'HEART_BURST' => const RadialGradient(colors: [Color(0xFFFF4D8D), Color(0xFF7C3AED), Color(0x00000000)]),
      'FIRE' => const RadialGradient(colors: [Color(0xFFFFE082), Color(0xFFFF5722), Color(0x00000000)]),
      'GALAXY' => const RadialGradient(colors: [Color(0xFFB388FF), Color(0xFF311B92), Color(0x00000000)]),
      'CROWN' => const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFF9A825), Color(0x00000000)]),
      'DIAMOND' => const RadialGradient(colors: [Color(0xFFB2EBF2), Color(0xFF00838F), Color(0x00000000)]),
      'STARS' => const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFD54F), Color(0x00000000)]),
      'LIGHTNING' => const RadialGradient(colors: [Color(0xFFFFFF8A), Color(0xFF0288D1), Color(0x00000000)]),
      'SAKURA' => const RadialGradient(colors: [Color(0xFFFFE4E9), Color(0xFFEC407A), Color(0x00000000)]),
      _ => const RadialGradient(colors: [Color(0xFF22D3EE), Color(0xFF7C3AED), Color(0x00000000)]),
    };
    return Center(child: Material(color: Colors.transparent, child: Stack(alignment: Alignment.center, children: [
      if (video != null && video.value.isInitialized)
        ClipRRect(borderRadius: BorderRadius.circular(28), child: AspectRatio(aspectRatio: video.value.aspectRatio, child: VideoPlayer(video)))
      else
        AnimatedBuilder(animation: _pulse, builder: (_, __) => Transform.scale(scale: 1 + _pulse.value * .06, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient)))),
      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 72),
      Positioned(top: 18, right: 18, child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30))),
    ])));
  }
}

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

class _ProfileBodyState extends State<_ProfileBody> with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> _posts;
  late Future<List<dynamic>> _reels;
  late Future<List<dynamic>> _repostedReels;
  late Future<List<dynamic>> _savedPosts;
  late Future<List<dynamic>> _likedPosts;
  late Future<List<dynamic>> _likedReels;
  late Future<List<dynamic>> _savedReels;
  late Future<List<dynamic>> _stories;
  int _tab = 0;
  final AudioPlayer _profileAudio = AudioPlayer();
  late final AnimationController _profileBgController;
  String _effectShownForUser = '';
  bool _showingOpenEffect = false;

  @override
  void initState() {
    super.initState();
    _profileBgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _applyProfileSecure(widget.user);
    _posts = Api.userPosts(widget.user.id);
    _reels = Api.userReels(widget.user.id);
    _repostedReels = Api.userRepostedReels(widget.user.id);
    _savedPosts = Api.userSavedPosts(widget.user.id);
    _likedPosts = Api.userLikedPosts(widget.user.id);
    _likedReels = Api.userReelsLiked(widget.user.id);
    _savedReels = Api.userReelsSaved(widget.user.id);
    _stories = Api.userStories(widget.user.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowProfileOpenEffect(widget.user));
  }

  void _applyProfileSecure(UserM u) { const MethodChannel('socialnova/privacy').invokeMethod('setSecure', {'enabled': u.j['preventProfileScreenshots'] == true}).catchError((_){}); }

  @override
  void didUpdateWidget(covariant _ProfileBody old) {
    super.didUpdateWidget(old);
    _applyProfileSecure(widget.user);
    if (old.user.id != widget.user.id) {
      _posts = Api.userPosts(widget.user.id);
      _reels = Api.userReels(widget.user.id);
      _repostedReels = Api.userRepostedReels(widget.user.id);
      _savedPosts = Api.userSavedPosts(widget.user.id);
      _likedPosts = Api.userLikedPosts(widget.user.id);
      _likedReels = Api.userReelsLiked(widget.user.id);
      _savedReels = Api.userReelsSaved(widget.user.id);
      _stories = Api.userStories(widget.user.id);
      _effectShownForUser = '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowProfileOpenEffect(widget.user));
    }
  }

  @override void dispose(){ _profileBgController.dispose(); _profileAudio.dispose(); const MethodChannel('socialnova/privacy').invokeMethod('setSecure', {'enabled': false}).catchError((_){}); super.dispose(); }

  Map<String, dynamic> _profileFeatures(UserM u) {
    final raw = u.j['specialFeatures'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<String> _stringList(dynamic value) => value is List ? value.map((e) => '$e').where((e) => e.isNotEmpty).toList() : <String>[];

  Future<void> _playProfileSong(Map<String, dynamic> f) async {
    final url = '${f['profileSongUrl'] ?? ''}'.trim();
    if (url.isEmpty) return;
    try {
      final uri = Uri.tryParse(url);
      // Spotify/Apple Music/etc. page URLs are not raw audio streams. Open
      // those links in the music app/browser instead of showing a misleading
      // "تعذر تشغيل الأغنية" error. Uploaded MP3/M4A/AAC URLs still play
      // directly inside SocialNova.
      final host = (uri?.host ?? '').toLowerCase();
      if (host.contains('spotify.com') || host.contains('music.apple.com') || host.contains('deezer.com')) {
        if (uri != null) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok && mounted) toast(context, 'تعذر فتح رابط الموسيقى');
        }
        return;
      }
      if (_profileAudio.playing) {
        await _profileAudio.pause();
      } else {
        await _profileAudio.setUrl(url);
        await _profileAudio.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) toast(context, 'الرابط ليس ملفًا صوتيًا مباشرًا. ارفع أغنية من الهاتف.');
    }
  }

  Future<void> _maybeShowProfileOpenEffect(UserM u) async {
    if (_showingOpenEffect || _effectShownForUser == u.id) return;
    final raw = u.j['profileOpenEffect'];
    if (raw is! Map) return;
    final f = Map<String, dynamic>.from(raw);
    if (f['enabled'] != true) return;
    final effect = '${f['effect'] ?? ''}'.trim();
    final videoUrl = '${f['videoUrl'] ?? ''}'.trim();
    if (effect.isEmpty && videoUrl.isEmpty) return;
    _effectShownForUser = u.id;
    _showingOpenEffect = true;
    try {
      await showDialog<void>(context: context, barrierColor: Colors.black.withValues(alpha: .82), barrierDismissible: true, builder: (_) => _ProfileOpenEffectDialog(effect: effect, videoUrl: videoUrl, durationMs: (f['durationMs'] as num?)?.toInt() ?? 4500));
    } finally { _showingOpenEffect = false; }
  }

  Future<void> _openProfileCustomization(UserM u) async {
    final f = _profileFeatures(u);
    var bg = '${f['profileBackground'] ?? 'gradient'}';
    if ('${f['profileBackgroundUrl'] ?? ''}'.trim().isNotEmpty) bg = 'custom';
    var frame = '${f['profileFrame'] ?? 'neon'}';
    if (frame == 'frame_ice') frame = 'ice';
    if (frame == 'frame_neon') frame = 'neon';
    if (frame == 'frame_gold') frame = 'gold';
    if (frame == 'frame_diamond') frame = 'diamond';
    if (frame == 'frame_legend') frame = 'vip';
    var bgUrl = '${f['profileBackgroundUrl'] ?? ''}';
    var songTitle = '${f['profileSongTitle'] ?? ''}';
    var songUrl = '${f['profileSongUrl'] ?? ''}';
    var team = '${f['teamClan'] ?? ''}';
    var showAchievements = f['showAchievements'] != false;
    var showTeam = f['showTeamClan'] != false;
    var pinnedPosts = _stringList(f['pinnedPostIds']).take(3).toList();
    var pinnedReel = '${f['pinnedReelId'] ?? ''}';
    final bgCtrl = TextEditingController(text: bgUrl);
    final titleCtrl = TextEditingController(text: songTitle);
    final songCtrl = TextEditingController(text: songUrl);
    final teamCtrl = TextEditingController(text: team);
    Future<void> pickCustomBackground(StateSetter setSheet) async {
      try {
        final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
        final path = picked?.files.single.path;
        if (path == null || path.isEmpty) return;
        if (mounted) toast(context, 'جاري رفع الخلفية...');
        final uploaded = await Api.uploadMedia(path, kind: 'IMAGE');
        final url = '${uploaded['url'] ?? ''}'.trim();
        if (url.isEmpty) throw Exception('UPLOAD_FAILED');
        setSheet(() { bg = 'custom'; bgCtrl.text = url; });
      } catch (e) {
        if (mounted) toast(context, 'تعذر رفع الخلفية: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
    Future<void> pickProfileSong(StateSetter setSheet) async {
      try {
        final picked = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
        final path = picked?.files.single.path;
        if (path == null || path.isEmpty) return;
        if (mounted) toast(context, 'جاري رفع الأغنية...');
        final uploaded = await Api.uploadMedia(path, kind: 'AUDIO');
        final url = '${uploaded['url'] ?? ''}'.trim();
        if (url.isEmpty) throw Exception('UPLOAD_FAILED');
        final name = picked!.files.single.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        setSheet(() { songCtrl.text = url; if (titleCtrl.text.trim().isEmpty) titleCtrl.text = name; });
      } catch (e) {
        if (mounted) toast(context, 'تعذر رفع الأغنية: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
    try {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context, isScrollControlled: true, backgroundColor: SN.bg1, showDragHandle: true,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.auto_awesome_rounded, color: Colors.amber), const SizedBox(width: 8), const Expanded(child: Text('تخصيص الملف الشخصي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 16),
            Text('الخلفية المتحركة', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final x in const ['gradient', 'aurora', 'stars', 'waves', 'bg_neon', 'bg_gold', 'bg_diamond', 'bg_galaxy', 'custom']) ChoiceChip(label: Text(x == 'gradient' ? 'Neon' : x == 'aurora' ? 'Aurora' : x == 'stars' ? 'Stars' : x == 'waves' ? 'Waves' : x == 'bg_neon' ? 'Neon +' : x == 'bg_gold' ? 'Gold' : x == 'bg_diamond' ? 'Diamond' : x == 'bg_galaxy' ? 'Galaxy' : 'مخصصة'), selected: bg == x, onSelected: (_) => setSheet(() => bg = x))]),
            const SizedBox(height: 10),
            if (bgCtrl.text.trim().isNotEmpty) ...[
              ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(bgCtrl.text.trim(), height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 120, alignment: Alignment.center, color: SN.bg3, child: const Text('تعذر تحميل معاينة الخلفية')))),
              const SizedBox(height: 8),
            ],
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => pickCustomBackground(setSheet), icon: const Icon(Icons.upload_rounded), label: Text(bgCtrl.text.trim().isEmpty ? 'رفع خلفية من الهاتف' : 'استبدال الخلفية من الهاتف'))),
            const SizedBox(height: 6),
            TextField(controller: bgCtrl, onChanged: (_) => setSheet(() {}), decoration: const InputDecoration(labelText: 'رابط خلفية مخصصة (اختياري)', prefixIcon: Icon(Icons.link))),
            const SizedBox(height: 16),
            Text('إطار الملف الشخصي', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final x in const ['neon', 'gold', 'diamond', 'fire', 'vip', 'ice']) ChoiceChip(label: Text(x == 'neon' ? 'Neon' : x == 'gold' ? 'Gold' : x == 'diamond' ? 'Diamond' : x == 'fire' ? 'Fire' : x == 'vip' ? 'VIP' : 'Ice'), selected: frame == x, onSelected: (_) { if (x == 'vip' && u.tier != 'VIP') { toast(context, 'إطار VIP متاح للحسابات VIP فقط'); return; } setSheet(() => frame = x); })]),
            const SizedBox(height: 16),
            Text('أغنية أعلى الملف', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم الأغنية', prefixIcon: Icon(Icons.music_note))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => pickProfileSong(setSheet), icon: const Icon(Icons.audio_file_rounded), label: const Text('رفع أغنية من الهاتف'))),
            const SizedBox(height: 8),
            TextField(controller: songCtrl, onChanged: (_) => setSheet(() {}), decoration: const InputDecoration(labelText: 'رابط الصوت المباشر أو Spotify', prefixIcon: Icon(Icons.link))),
            if (songCtrl.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(songCtrl.text.contains('spotify.com') ? 'سيتم فتح Spotify عند الضغط على التشغيل.' : 'الرابط سيعمل داخل SocialNova إذا كان ملف MP3/M4A/AAC مباشرًا.', style: TextStyle(color: SN.textMut, fontSize: 11))),
            const SizedBox(height: 16),
            Text('تثبيت المحتوى', style: TextStyle(color: SN.textMut, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(future: _posts, builder: (ctx, snap) {
              final rows = snap.data ?? [];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المنشورات المثبتة (حتى 3)', style: TextStyle(fontSize: 12, color: SN.textMut)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final x in rows.take(20)) Builder(builder: (_) { final m = Map<String, dynamic>.from(x as Map); final id = '${m['id'] ?? ''}'; final selected = pinnedPosts.contains(id); return FilterChip(label: Text('${m['caption'] ?? 'منشور'}', maxLines: 1, overflow: TextOverflow.ellipsis), selected: selected, onSelected: (v) { setSheet(() { if (v) { if (pinnedPosts.length < 3) pinnedPosts.add(id); } else { pinnedPosts.remove(id); } }); }); })]),
              ]);
            }),
            const SizedBox(height: 10),
            FutureBuilder<List<dynamic>>(future: _reels, builder: (ctx, snap) {
              final rows = snap.data ?? [];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reel المثبت', style: TextStyle(fontSize: 12, color: SN.textMut)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [for (final x in rows.take(20)) Builder(builder: (_) { final m = Map<String, dynamic>.from(x as Map); final id = '${m['id'] ?? ''}'; return ChoiceChip(label: Text('${m['caption'] ?? 'Reel'}', maxLines: 1, overflow: TextOverflow.ellipsis), selected: pinnedReel == id, onSelected: (v) => setSheet(() => pinnedReel = v ? id : '')); })]),
              ]);
            }),
            const SizedBox(height: 16),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: showAchievements, onChanged: (v) => setSheet(() => showAchievements = v), title: const Text('عرض الإنجازات')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: showTeam, onChanged: (v) => setSheet(() => showTeam = v), title: const Text('عرض Team / Clan')),
            if (showTeam) TextField(controller: teamCtrl, decoration: const InputDecoration(labelText: 'اسم الفريق / الكلان', prefixIcon: Icon(Icons.groups_rounded))),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, {'profileBackground': bgCtrl.text.trim().isNotEmpty ? 'custom' : bg, 'profileBackgroundUrl': bgCtrl.text.trim(), 'profileFrame': frame, 'profileSongTitle': titleCtrl.text.trim(), 'profileSongUrl': songCtrl.text.trim(), 'pinnedPostIds': pinnedPosts, 'pinnedReelId': pinnedReel, 'showAchievements': showAchievements, 'showTeamClan': showTeam, 'teamClan': teamCtrl.text.trim()}), icon: const Icon(Icons.save_rounded), label: const Text('حفظ التخصيص'))),
          ]))));
        }),
      );
      if (result == null) return;
      await Api.updateMe({'specialFeatures': result});
      if (mounted) { toast(context, 'تم حفظ تخصيص الملف'); widget.onRefresh(); }
    } finally { bgCtrl.dispose(); titleCtrl.dispose(); songCtrl.dispose(); teamCtrl.dispose(); }
  }

  Widget _profileExtras(UserM u) {
    final f = _profileFeatures(u);
    final bg = '${f['profileBackground'] ?? ''}';
    final frame = '${f['profileFrame'] ?? ''}';
    final songTitle = '${f['profileSongTitle'] ?? ''}';
    final songUrl = '${f['profileSongUrl'] ?? ''}';
    final pinnedPosts = _stringList(f['pinnedPostIds']);
    final pinnedReel = '${f['pinnedReelId'] ?? ''}';
    final team = '${f['teamClan'] ?? ''}';
    final showAchievements = f['showAchievements'] != false;
    final showTeam = f['showTeamClan'] != false;
    if ([bg, frame, songTitle, pinnedReel, team].every((x) => x.isEmpty) && pinnedPosts.isEmpty && !showAchievements) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (songTitle.isNotEmpty || songUrl.isNotEmpty) Card(color: SN.bg2, child: ListTile(leading: const CircleAvatar(child: Icon(Icons.music_note_rounded)), title: Text(songTitle.isEmpty ? 'أغنية الملف الشخصي' : songTitle, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(songUrl.contains('spotify.com') ? 'Spotify' : 'أغنية الملف الشخصي'), trailing: songUrl.isEmpty ? null : IconButton(onPressed: () => _playProfileSong(f), icon: Icon(_profileAudio.playing ? Icons.pause_circle_filled : Icons.play_circle_fill)))),
      if (showAchievements) const Card(child: ListTile(leading: Icon(Icons.emoji_events_rounded, color: Colors.amber), title: Text('الإنجازات', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('إنجازات صاحب الحساب'))),
      if (showTeam && team.isNotEmpty) Card(color: SN.bg2, child: ListTile(leading: const Icon(Icons.groups_rounded), title: const Text('Team / Clan', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(team))),
      if (pinnedPosts.isNotEmpty || pinnedReel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text('📌 محتوى مثبت', style: const TextStyle(fontWeight: FontWeight.w900))),
      if (pinnedPosts.isNotEmpty) Text('${pinnedPosts.length} منشورات مثبتة', style: TextStyle(color: SN.textMut)),
      if (pinnedReel.isNotEmpty) Text('1 Reel مثبت', style: TextStyle(color: SN.textMut)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _managedProfileCard(UserM u) {
    final raw = u.j['managementPermissions'];
    final perms = raw is List ? raw.map((e) => '$e').toList() : const <String>[];
    final canModerate = Api.can('USER_MODERATION');
    if (perms.isEmpty && !canModerate) return const SizedBox.shrink();
    bool can(String p) => perms.contains('*') || perms.contains(p);
    final isBanned = u.j['isBanned'] == true;
    final isClosed = u.j['isDeactivated'] == true;
    return Card(color: SN.bg2, child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber), const SizedBox(width: 8), const Expanded(child: Text('إدارة الحساب المفوضة', style: TextStyle(fontWeight: FontWeight.w900))), const Icon(Icons.verified_user_rounded, size: 18, color: Colors.green)]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (can('ASSIGNED_PROFILE_VERIFY')) OutlinedButton.icon(onPressed: () async { try { await Api.managedProfileAction(u.id, 'VERIFY', {'value': !u.isVerified, 'tier': 'PRO'}); toast(context, u.isVerified ? 'تم إلغاء التوثيق' : 'تم توثيق الحساب'); widget.onRefresh(); } catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); } }, icon: const Icon(Icons.verified_rounded, size: 17), label: Text(u.isVerified ? 'إلغاء التوثيق' : 'توثيق')),
        if (can('ASSIGNED_PROFILE_FEATURE')) OutlinedButton.icon(onPressed: () async { try { await Api.managedProfileAction(u.id, 'FEATURE', {'value': u.j['featuredAccount'] != true, 'priority': 100}); toast(context, 'تم تحديث التمييز'); widget.onRefresh(); } catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); } }, icon: const Icon(Icons.star_rounded, size: 17), label: const Text('تمييز')),
        if (can('ASSIGNED_PROFILE_BAN')) OutlinedButton.icon(onPressed: () async { try { await Api.managedProfileAction(u.id, 'BAN', {'value': !isBanned}); toast(context, isBanned ? 'تم فك الحظر' : 'تم حظر الحساب'); widget.onRefresh(); } catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); } }, icon: const Icon(Icons.block_rounded, size: 17), label: const Text('حظر')),
        if (can('ASSIGNED_PROFILE_COINS')) OutlinedButton.icon(onPressed: () async { final amount = await _askAmount(); if (amount == null) return; try { await Api.managedProfileAction(u.id, 'COINS', {'coins': amount}); toast(context, 'تم تعديل NovaCoin'); } catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); } }, icon: const Icon(Icons.monetization_on_outlined, size: 17), label: const Text('عملة')),
        if (can('ASSIGNED_PROFILE_EFFECTS')) OutlinedButton.icon(onPressed: () => _editManagedEffect(u), icon: const Icon(Icons.auto_awesome, size: 17), label: const Text('تأثير فتح')),
      ]),
      // Global staff actions, shown once a platform permission is granted.
      if (canModerate) ...[
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.shield_rounded, size: 15, color: SN.cyan), const SizedBox(width: 6), const Text('صلاحيات المنصة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          OutlinedButton.icon(
            onPressed: () async {
              try { await Api.adminUpdateUser(u.id, {'banned': !isBanned}); toast(context, isBanned ? 'تم فك الحظر' : 'تم حظر الحساب'); widget.onRefresh(); }
              catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); }
            },
            icon: Icon(isBanned ? Icons.lock_open_rounded : Icons.block_rounded, size: 17, color: Colors.redAccent),
            label: Text(isBanned ? 'فك الحظر' : 'حظر الحساب'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              try { await Api.adminSetDeactivated(u.id, !isClosed); toast(context, isClosed ? 'تمت إعادة تفعيل الحساب' : 'تم إغلاق الحساب'); widget.onRefresh(); }
              catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); }
            },
            icon: Icon(isClosed ? Icons.person_add_alt_1_rounded : Icons.no_accounts_rounded, size: 17, color: Colors.orangeAccent),
            label: Text(isClosed ? 'إعادة تفعيل الحساب' : 'إغلاق الحساب'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final n = await _askFollowers();
              if (n == null || n == 0) return;
              try { await Api.adminAddFollowers(u.id, n); toast(context, n > 0 ? 'تمت إضافة $n متابع' : 'تم حذف المتابعين'); widget.onRefresh(); }
              catch (e) { toast(context, e.toString().replaceFirst('Exception: ', '')); }
            },
            icon: const Icon(Icons.group_add_rounded, size: 17, color: Colors.greenAccent),
            label: const Text('زيادة متابعين'),
          ),
        ]),
      ],
    ])));
  }

  Future<int?> _askFollowers() async {
    final controller = TextEditingController(text: '1000');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زيادة المتابعين'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العدد (سالب لحذف المتابعين)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())), child: const Text('تطبيق')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<int?> _askAmount() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(title: const Text('NovaCoin'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد العملات (+ أو -)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())), child: const Text('تطبيق'))]));
    controller.dispose();
    return result;
  }

  Future<void> _editManagedEffect(UserM u) async {
    final raw = u.j['profileOpenEffect'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final effectController = TextEditingController(text: '${data['effect'] ?? ''}');
    final urlController = TextEditingController(text: '${data['videoUrl'] ?? ''}');
    bool enabled = data['enabled'] == true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('تأثير فتح الملف'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: effectController.text.isEmpty ? null : effectController.text,
                  items: const ['NONE', 'GOLDEN_AURA', 'NEON_PORTAL', 'HEART_BURST', 'SPARKLES', 'FIRE', 'GALAXY', 'CROWN', 'DIAMOND', 'STARS', 'LIGHTNING', 'SAKURA']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => setDialog(() => effectController.text = v ?? ''),
                  decoration: const InputDecoration(labelText: 'التأثير'),
                ),
                TextField(controller: urlController, decoration: const InputDecoration(labelText: 'فيديو قصير اختياري')),
                SwitchListTile(value: enabled, onChanged: (v) => setDialog(() => enabled = v), title: const Text('تفعيل')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'profileOpenEffect': effectController.text,
                'profileOpenVideoUrl': urlController.text.trim(),
                'profileOpenEnabled': enabled,
                'profileOpenDurationMs': 4500,
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    effectController.dispose();
    urlController.dispose();
    if (result == null) return;
    try {
      await Api.updateAdminProfileEffects(u.id, result);
      toast(context, 'تم حفظ تأثير فتح الملف');
      widget.onRefresh();
    } catch (e) {
      toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
  Future<void> _openStatusSegment(UserM u, String segment) async {
    if (segment == 'NONE') { if (u.avatarUrl.isNotEmpty) _showProfileImage(u.avatarUrl, 'صورة الملف الشخصي'); return; }
    if (segment == 'LIVE') {
      try { final rows = await Api.live(); final live = rows.cast<dynamic>().map((e) => Map<String, dynamic>.from(e as Map)).firstWhere((e) => '${e['host']?['id'] ?? e['hostId'] ?? ''}' == u.id, orElse: () => <String, dynamic>{}); if (live.isNotEmpty && mounted) { Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomPage(title: '${live['title'] ?? u.displayName}', roomName: '${live['roomName'] ?? ''}', roomId: '${live['id'] ?? ''}', hostId: u.id))); return; } } catch (_) {}
    }
    if (segment == 'STORY') { try { final rows = await Api.userStories(u.id); if (rows.isNotEmpty && mounted) { Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewer(story: StoryM(Map<String, dynamic>.from(rows.first as Map))))); return; } } catch (_) {} }
    if (segment == 'REEL') { try { final rows = await Api.userReels(u.id); if (rows.isNotEmpty && mounted) { Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityReelPage(reel: Map<String, dynamic>.from(rows.first as Map)))); return; } } catch (_) {} }
    if (segment == 'POST') { try { final rows = await Api.userPosts(u.id); if (rows.isNotEmpty && mounted) { Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityPostPage(post: Map<String, dynamic>.from(rows.first as Map)))); return; } } catch (_) {} }
    if (mounted && u.avatarUrl.isNotEmpty) _showProfileImage(u.avatarUrl, 'صورة الملف الشخصي');
  }

  Future<void> _openStatusFromAvatar(UserM u) async {
    // An active Story must always win over the profile-image action. This
    // makes the ring behave like Instagram/TikTok: tapping the avatar opens
    // the current Story directly instead of opening the cover/avatar image.
    // Live has absolute priority when both Live and Story are active.
    // A single tap on the profile ring should enter the live room first.
    final segments = List<String>.from(u.statusRings['segments'] ?? const <String>[]);
    if (segments.isEmpty) { if (u.avatarUrl.isNotEmpty) _showProfileImage(u.avatarUrl, 'صورة الملف الشخصي'); return; }
    for (final segment in const ['LIVE', 'STORY', 'POST', 'REEL']) { if (segments.contains(segment)) { await _openStatusSegment(u, segment); return; } }
    if (u.avatarUrl.isNotEmpty) _showProfileImage(u.avatarUrl, 'صورة الملف الشخصي');
  }

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

  Widget _profileBackgroundLayer(UserM u) {
    final f = _profileFeatures(u);
    final kind = '${f['profileBackground'] ?? 'gradient'}';
    final url = '${f['profileBackgroundUrl'] ?? ''}'.trim();

    // Keep custom/profile backgrounds visible while adding a readability veil.
    // This prevents bright blue/purple backgrounds from washing out names,
    // counters, tabs and secondary metadata.
    Widget background;
    if (kind == 'custom' && url.isNotEmpty) {
      background = Opacity(
        opacity: .34,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(gradient: SN.grad)),
        ),
      );
    } else if (kind == 'bg_aurora') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF10245E), const Color(0xFF54206F), SN.bg0])));
    } else if (kind == 'bg_neon') {
      background = Container(decoration: BoxDecoration(gradient: SN.grad));
    } else if (kind == 'bg_gold') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF3B2B08), const Color(0xFF6B4B0A), SN.bg0])));
    } else if (kind == 'bg_diamond') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF17304A), const Color(0xFF4B3A79), SN.bg0])));
    } else if (kind == 'bg_galaxy') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF160D3D), const Color(0xFF35105C), SN.bg0])));
    } else if (kind == 'stars') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF10152F), SN.bg0])));
    } else if (kind == 'aurora') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF0B1637), const Color(0xFF221047), const Color(0xFF071C28), SN.bg0])));
    } else if (kind == 'waves') {
      background = Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF071C42), const Color(0xFF11103C), SN.bg0])));
    } else {
      background = Container(decoration: BoxDecoration(gradient: SN.grad));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        // Contrast overlay: text remains readable on every selectable background.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .30),
                  Colors.black.withValues(alpha: .20),
                  Colors.black.withValues(alpha: .34),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileFrameLayer(UserM u, Widget child) {
    var frame = '${_profileFeatures(u)['profileFrame'] ?? 'neon'}'.toLowerCase();
    if (frame == 'frame_ice') frame = 'ice';
    if (frame == 'frame_neon') frame = 'neon';
    if (frame == 'frame_gold') frame = 'gold';
    if (frame == 'frame_diamond') frame = 'diamond';
    if (frame == 'frame_legend') frame = 'vip';
    final Gradient gradient;
    double width = 3;
    if (frame == 'ice') {
      gradient = const LinearGradient(colors: [Color(0xFFB3E5FC), Color(0xFF4FC3F7), Color(0xFFE1F5FE)]);
    } else if (frame == 'gold') {
      gradient = const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFFFE082)]);
    } else if (frame == 'diamond') {
      gradient = const LinearGradient(colors: [Color(0xFFB3E5FC), Color(0xFF7C4DFF), Color(0xFFE1F5FE)]);
    } else if (frame == 'fire') {
      gradient = const LinearGradient(colors: [Color(0xFFFF3D00), Color(0xFFFFC107), Color(0xFFFF1744)]);
      width = 4;
    } else if (frame == 'vip') {
      gradient = const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB388FF), Color(0xFFFF80AB)]);
      width = 4;
    } else {
      gradient = SN.grad;
    }
    return Container(padding: EdgeInsets.all(width), decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 18)]), child: child);
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _profileBackgroundLayer(u)),
          ListView(
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
                    // Tapping the profile photo opens the highest-priority active status: LIVE first, then STORY/REEL/POST.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openStatusFromAvatar(u),
                      child: _profileFrameLayer(u, StatusAvatar(url: u.avatarUrl, name: u.displayName, size: 96, status: u.statusRings)),
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
                Row(children: [
                  Text('@${u.username}', style: TextStyle(color: SN.textMut, fontSize: 13)),
                  if (!widget.isMe && u.showOnlineStatus) ...[
                    const SizedBox(width: 8),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: u.online ? SN.green : SN.textMut, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(u.online ? 'متصل الآن' : 'كان متصلًا ${timeAgo(u.lastSeen)}', style: TextStyle(color: u.online ? SN.green : SN.textMut, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(width: 8),
                  CreatorLevelBadge(followers: u.followers),
                  const SizedBox(width: 6),
                  const CreatorMilestoneBadge(),
                ]),
                if (u.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(u.bio, style: const TextStyle(height: 1.6, fontSize: 14)),
                ],
                const SizedBox(height: 10),
                _profileMeta(u),
                if (!widget.isMe) _managedProfileCard(u),
                if (widget.isMe) Padding(padding: const EdgeInsets.only(top: 10), child: OutlinedButton.icon(onPressed: () => _openProfileCustomization(u), icon: const Icon(Icons.auto_awesome), label: const Text('تخصيص الملف الشخصي'))),
                _profileExtras(u),
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
                      _tabButton('Reels', 5),
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
        ],
      ),
    );
  }

  Widget _tabButton(String title, int index) => InkWell(
    onTap: () => setState(() => _tab = index),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: _tab == index ? const Color(0xFFB9A7FF) : Colors.white.withValues(alpha: .88), shadows: const [Shadow(color: Colors.black54, blurRadius: 3)])),
    ),
  );

  Widget _tabContent(UserM u) {
    if (_tab == 5) {
      return FutureBuilder<List<dynamic>>(future: _reels, builder: (c,snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingBox();
        if (snap.hasError) return EmptyState(text: '${snap.error}'.replaceFirst('Exception: ', ''));
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyState(text: 'لا توجد Reels منشورة بعد.', icon: Icons.video_collection_outlined);
        return Column(children: [for (final x in rows) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ProfileRepostedReelCard(reel: ReelM(Map<String,dynamic>.from(x as Map)), onChanged: widget.onRefresh)), const SizedBox(height: 40)]);
      });
    }
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

  Widget _profileMeta(UserM u) {
    final chips=<Widget>[];
    if(u.showLocationInProfile && u.location.isNotEmpty) chips.add(_metaChip(Icons.location_on_rounded,u.location));
    if(u.showBirthDateInProfile && u.birthDate.isNotEmpty){ final d=DateTime.tryParse(u.birthDate)?.toLocal(); if(d!=null) chips.add(_metaChip(Icons.cake_rounded,'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}')); }
    if(u.showRelationshipInProfile && u.relationshipType.isNotEmpty) chips.add(_metaChip(Icons.favorite_rounded,_relationshipLabel(u.relationshipType,u.gender)));
    if(u.showGenderInProfile && u.gender.isNotEmpty) chips.add(_metaChip(Icons.person_rounded,u.gender));
    if(chips.isEmpty) return const SizedBox.shrink();
    return Padding(padding:const EdgeInsets.only(bottom:12),child:Wrap(spacing:7,runSpacing:7,children:chips));
  }
  Widget _metaChip(IconData icon,String text)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:SN.bg2,borderRadius:BorderRadius.circular(20),border:Border.all(color:SN.stroke)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:15,color:SN.violet),const SizedBox(width:5),ConstrainedBox(constraints:const BoxConstraints(maxWidth:150),child:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w700,color:Colors.white,shadows:[Shadow(color:Colors.black54,blurRadius:2)])))]));

  String _relationshipLabel(String type, String gender) {
    final female = gender.toLowerCase() == 'female' || gender == 'أنثى' || gender == 'FEMALE';
    final key = switch (type) {
      'SINGLE' => female ? 'عزباء' : 'أعزب',
      'IN_RELATIONSHIP' => female ? 'مرتبطة' : 'مرتبط',
      'ENGAGED' => female ? 'مخطوبة' : 'مخطوب',
      'MARRIED' => female ? 'متزوجة' : 'متزوج',
      'CIVIL_UNION' => 'زواج مدني',
      'DOMESTIC_PARTNERSHIP' => 'شراكة أسرية',
      'OPEN_RELATIONSHIP' => 'في علاقة مفتوحة',
      'COMPLICATED' => 'علاقة معقدة',
      'SEPARATED' => female ? 'منفصلة' : 'منفصل',
      'DIVORCED' => female ? 'مطلقة' : 'مطلق',
      'WIDOWED' => female ? 'أرملة' : 'أرمل',
      _ => 'أعزب',
    };
    return L10n.t(key);
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
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12, shadows: const [Shadow(color: Colors.black54, blurRadius: 2)])),
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
  String relationshipType = 'SINGLE';
  String? relationshipPartnerId;
  String relationshipPartnerName = '';
  DateTime? relationshipSince;
  bool busy = false;
  bool uploading = false;
  bool showBirthDateInProfile = true;
  bool showLocationInProfile = true;
  bool showRelationshipInProfile = true;
  bool showGenderInProfile = false;

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
    relationshipType = u.relationshipType;
    final rel = u.relationship;
    relationshipPartnerId = rel?['partner'] is Map ? '${(rel!['partner'] as Map)['id'] ?? ''}' : null;
    relationshipPartnerName = rel?['partner'] is Map ? '${(rel!['partner'] as Map)['displayName'] ?? ''}' : '';
    relationshipSince = DateTime.tryParse('${rel?['since'] ?? ''}')?.toLocal();
    showBirthDateInProfile = u.showBirthDateInProfile;
    showLocationInProfile = u.showLocationInProfile;
    showRelationshipInProfile = u.showRelationshipInProfile;
    showGenderInProfile = u.showGenderInProfile;
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

  Future<void> _editRelationship() async {
    List<dynamic> followers = [];
    try {
      followers = await Api.followers(widget.user.id);
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    var type = relationshipType;
    String? partnerId = relationshipPartnerId;
    String partnerName = relationshipPartnerName;
    DateTime? since = relationshipSince;
    const types = <String>['SINGLE','IN_RELATIONSHIP','ENGAGED','MARRIED','CIVIL_UNION','DOMESTIC_PARTNERSHIP','OPEN_RELATIONSHIP','COMPLICATED','SEPARATED','DIVORCED','WIDOWED'];
    final result = await showModalBottomSheet<Map<String,dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SN.bg1,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final female = widget.user.gender.toLowerCase() == 'female' || widget.user.gender == 'أنثى' || widget.user.gender == 'FEMALE';
        String label(String t) => switch (t) { 'SINGLE'=>female?'عزباء':'أعزب', 'IN_RELATIONSHIP'=>female?'مرتبطة':'مرتبط', 'ENGAGED'=>female?'مخطوبة':'مخطوب', 'MARRIED'=>female?'متزوجة':'متزوج', 'CIVIL_UNION'=>'زواج مدني', 'DOMESTIC_PARTNERSHIP'=>'شراكة أسرية', 'OPEN_RELATIONSHIP'=>'في علاقة مفتوحة', 'COMPLICATED'=>'علاقة معقدة', 'SEPARATED'=>female?'منفصلة':'منفصل', 'DIVORCED'=>female?'مطلقة':'مطلق', 'WIDOWED'=>female?'أرملة':'أرمل', _=>female?'عزباء':'أعزب' };
        final needsPartner = true; // عرض اختيار الشريك، لكن الحفظ لا يتطلبه
        return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 42,height:42,decoration:BoxDecoration(color:Colors.pink.withValues(alpha:.12),shape:BoxShape.circle),child:const Icon(Icons.favorite_rounded,color:Colors.pinkAccent)),const SizedBox(width:10),Expanded(child:Text(L10n.t('حالة العلاقة'),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)))]),
          const SizedBox(height:16),
          DropdownButtonFormField<String>(value: types.contains(type)?type:'SINGLE', decoration: InputDecoration(labelText:L10n.t('حالة العلاقة'), prefixIcon:const Icon(Icons.favorite_border_rounded)), items:[for(final t in types) DropdownMenuItem(value:t,child:Text(L10n.t(label(t))))], onChanged:(v){if(v!=null)setSheet((){type=v;if({'SINGLE','DIVORCED','WIDOWED'}.contains(v)){partnerId=null;partnerName='';}});}),
          if(needsPartner) ...[
            const SizedBox(height:12),
            Text(L10n.t('اختر شريكًا (اختياري)'),style:TextStyle(color:SN.textMut,fontSize:12)),
            const SizedBox(height:6),
            Container(
              decoration: BoxDecoration(color: SN.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: SN.stroke)),
              constraints: const BoxConstraints(maxHeight: 250),
              child: followers.isEmpty
                  ? Padding(padding: const EdgeInsets.all(18), child: Text('لا يوجد متابعون متاحون للاختيار'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: followers.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: SN.stroke),
                      itemBuilder: (_, i) {
                        final u = Map<String, dynamic>.from(followers[i] as Map);
                        final selected = '${u['id']}' == partnerId;
                        return ListTile(
                          leading: SNav(url: '${u['avatarUrl'] ?? ''}', name: '${u['displayName'] ?? ''}', size: 42),
                          title: Text('${u['displayName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('@${u['username'] ?? ''}', style: TextStyle(color: SN.textMut, fontSize: 11)),
                          trailing: selected ? const Icon(Icons.check_circle_rounded, color: Colors.pinkAccent) : null,
                          onTap: () {
                            setSheet(() {
                              partnerId = '${u['id']}';
                              partnerName = '${u['displayName'] ?? ''}';
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
          const SizedBox(height:12),
          InkWell(borderRadius:BorderRadius.circular(16),onTap:() async {final now=DateTime.now();final picked=await showDatePicker(context:ctx,initialDate:since??now,firstDate:DateTime(1950),lastDate:now,helpText:L10n.t('منذ متى؟'),cancelText:L10n.t('إلغاء'),confirmText:L10n.t('تأكيد'));if(picked!=null)setSheet((){since=picked;});},child:InputDecorator(decoration:InputDecoration(labelText:L10n.t('منذ متى؟'),prefixIcon:const Icon(Icons.event_outlined)),child:Text(since==null?'${DateTime.now().day.toString().padLeft(2,'0')}/${DateTime.now().month.toString().padLeft(2,'0')}/${DateTime.now().year}':'${since!.day.toString().padLeft(2,'0')}/${since!.month.toString().padLeft(2,'0')}/${since!.year}'))),
          const SizedBox(height:16),
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>Navigator.pop(ctx,{'type':type,'partnerId':partnerId,'since':since}),icon:const Icon(Icons.check_rounded),label:Text(L10n.t('حفظ')))),
          const SizedBox(height:8),
          if(relationshipType!='SINGLE') SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>Navigator.pop(ctx,{'end':true}),icon:const Icon(Icons.link_off_rounded),label:Text(L10n.t('إنهاء العلاقة')))),
        ]))));
      }),
    );
    if (result == null) return;
    try {
      if (result['end'] == true) {
        await Api.endRelationship();
        if (mounted) { setState(() { relationshipType='SINGLE'; relationshipPartnerId=null; relationshipPartnerName=''; relationshipSince=null; }); toast(context,'تم إنهاء العلاقة'); }
        return;
      }
      final pickedType='${result['type']}';
      final pickedSince=result['since'] as DateTime?;
      if (result['partnerId'] == null || '${result['partnerId']}'.isEmpty) {
        await Api.setRelationshipStatus(pickedType, since: pickedSince);
        if (!mounted) return;
        setState(() { relationshipType=pickedType; relationshipPartnerId=null; relationshipPartnerName=''; relationshipSince=pickedSince; });
        toast(context,'تم تحديث الحالة ✓');
        return;
      }
      final created = await Api.createRelationship(pickedType, '${result['partnerId'] ?? ''}', since: pickedSince);
      if (!mounted) return;
      setState(() { relationshipType='${created['type'] ?? pickedType}'; relationshipPartnerId='${(created['partner'] as Map?)?['id'] ?? result['partnerId'] ?? ''}'; relationshipPartnerName='${(created['partner'] as Map?)?['displayName'] ?? partnerName}'; relationshipSince=DateTime.tryParse('${created['since'] ?? pickedSince ?? ''}')?.toLocal(); });
      toast(context,'تم إرسال طلب العلاقة ❤️');
    } catch (e) { if (mounted) toast(context,e.toString().replaceFirst('Exception: ','')); }
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
      await Api.updateSettings({'showBirthDateInProfile':showBirthDateInProfile,'showLocationInProfile':showLocationInProfile,'showRelationshipInProfile':showRelationshipInProfile,'showGenderInProfile':showGenderInProfile});
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
        actions: [IconButton(tooltip: 'مكافآت المبدع', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorRewardsPage(userId: widget.user.id, displayName: widget.user.displayName))), icon: const Icon(Icons.emoji_events_rounded, color: SN.gold)),IconButton(tooltip: 'بطاقة الهوية الرقمية', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DigitalIdPage())), icon: const Icon(Icons.badge_rounded, color: SN.cyan)),TextButton(onPressed: busy ? null : _save, child: const Text('حفظ'))],
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
          const SizedBox(height: 8),
          Text('خصوصية معلومات الملف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SN.textPri)),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: showLocationInProfile, onChanged: (v)=>setState(()=>showLocationInProfile=v), title: const Text('إظهار الولاية / الموقع')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: showBirthDateInProfile, onChanged: (v)=>setState(()=>showBirthDateInProfile=v), title: const Text('إظهار تاريخ الميلاد')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: showRelationshipInProfile, onChanged: (v)=>setState(()=>showRelationshipInProfile=v), title: const Text('إظهار العلاقة')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: showGenderInProfile, onChanged: (v)=>setState(()=>showGenderInProfile=v), title: const Text('إظهار الجنس')),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20), const SizedBox(width: 8), Expanded(child: Text(L10n.t('حالة العلاقة'), style: const TextStyle(fontWeight: FontWeight.w800))), TextButton(onPressed: busy ? null : _editRelationship, child: Text(L10n.t('تعديل')))]),
              const SizedBox(height: 4),
              Text(L10n.t(relationshipType == 'SINGLE' ? 'أعزب' : relationshipType == 'ENGAGED' ? 'مخطوب' : relationshipType == 'MARRIED' ? 'متزوج' : relationshipType == 'IN_RELATIONSHIP' ? 'مرتبط' : relationshipType == 'DIVORCED' ? 'مطلق' : relationshipType == 'WIDOWED' ? 'أرمل' : relationshipType == 'CIVIL_UNION' ? 'زواج مدني' : relationshipType == 'DOMESTIC_PARTNERSHIP' ? 'شراكة أسرية' : relationshipType == 'OPEN_RELATIONSHIP' ? 'في علاقة مفتوحة' : relationshipType == 'COMPLICATED' ? 'علاقة معقدة' : 'منفصل'), style: TextStyle(color: SN.textSec, fontSize: 13)),
              if (relationshipPartnerName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${L10n.t('مرتبط بـ')} $relationshipPartnerName', style: const TextStyle(fontWeight: FontWeight.w700))),
              if (relationshipSince != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('${L10n.t('منذ')}: ${relationshipSince!.day.toString().padLeft(2,'0')}/${relationshipSince!.month.toString().padLeft(2,'0')}/${relationshipSince!.year}', style: TextStyle(color: SN.textMut, fontSize: 11.5))),
            ]),
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
  bool messageSoundEnabled = true;
  String callRingtone = 'call_ring';
  String messageSound = 'message';

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
        messageSoundEnabled = me['pushNotifications'] != false;
        loaded = true;
      });
      callRingtone = await getCallRingtone();
      messageSound = await getNotificationSound();
      if (mounted) setState(() {});
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

  String _callRingtoneLabel(String key) => switch (key) {
    'call_classic' => 'كلاسيكية', 'call_soft' => 'ناعمة', 'call_digital' => 'رقمية', _ => 'الرنين العادي',
  };
  String _messageSoundLabel(String key) => switch (key) {
    'soft' => 'هادئ', 'digital' => 'رقمي', 'silent' => 'بدون صوت', _ => 'الصوت العادي',
  };
  Future<void> _chooseCallRingtone() async {
    final options = const ['call_ring','call_classic','call_soft','call_digital'];
    final selected = await showModalBottomSheet<String>(context: context, backgroundColor: SN.bg1, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerRight, child: Text('اختر نغمة الاتصال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))), for(final key in options) ListTile(leading: Icon(key==callRingtone?Icons.radio_button_checked:Icons.radio_button_off,color:key==callRingtone?SN.cyan:SN.textMut),title:Text(_callRingtoneLabel(key)),onTap:()=>Navigator.pop(ctx,key)), const SizedBox(height:8)])));
    if(selected==null)return; setState(()=>callRingtone=selected); await setCallRingtone(selected); await NovaAudio.i.playCallRing(key:selected); await Future<void>.delayed(const Duration(milliseconds:1200)); await NovaAudio.i.stopCallRing();
  }
  Future<void> _chooseMessageSound() async {
    final options = const ['message','soft','digital','silent'];
    final selected = await showModalBottomSheet<String>(context: context, backgroundColor: SN.bg1, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerRight, child: Text('اختر صوت الرسائل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))), for(final key in options) ListTile(leading: Icon(key==messageSound?Icons.radio_button_checked:Icons.radio_button_off,color:key==messageSound?SN.cyan:SN.textMut),title:Text(_messageSoundLabel(key)),onTap:()=>Navigator.pop(ctx,key)), const SizedBox(height:8)])));
    if(selected==null)return; setState(()=>messageSound=selected); await setNotificationSound(selected);
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
                _switch(
                  'إشعارات الرسائل',
                  'تظهر عند وصول رسالة جديدة سواء كان التطبيق مفتوحًا أو مغلقًا.',
                  messageSoundEnabled,
                  (v) async {
                    setState(() => messageSoundEnabled = v);
                    await _save({'pushNotifications': v});
                    final p = await SharedPreferences.getInstance();
                    await p.setBool('sn_${Api.me?['id'] ?? 'guest'}_message_notifications', v);
                  },
                ),
                GlassCard(child: ListTile(leading: const Icon(Icons.call_rounded, color: SN.green), title: const Text('نغمة الاتصال', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(_callRingtoneLabel(callRingtone)), trailing: const Icon(Icons.chevron_left), onTap: _chooseCallRingtone)),
                GlassCard(child: ListTile(leading: const Icon(Icons.notifications_active_rounded, color: SN.cyan), title: const Text('صوت إشعار الرسائل', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(_messageSoundLabel(messageSound)), trailing: const Icon(Icons.chevron_left), onTap: _chooseMessageSound)),
                _section('تحديث التطبيق'),
                GlassCard(
                  child: ListTile(
                    leading: const Icon(Icons.system_update_alt_rounded, color: SN.cyan),
                    title: const Text('تحديث التطبيق', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('التحقق من أحدث إصدار وتنزيله وتثبيته فوق النسخة الحالية'),
                    trailing: const Icon(Icons.download_rounded),
                    onTap: () async {
                      final update = await AppUpdateManager.check();
                      if (!mounted) return;
                      if (update == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أنت تستخدم أحدث إصدار متاح حاليًا.')),
                        );
                        return;
                      }
                      await AppUpdateManager.showUpdateDialog(context, update);
                    },
                  ),
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
                  leading: Icon(Icons.devices_other_rounded, color: Colors.orangeAccent),
                  title: const Text('تسجيل الخروج من كل الأجهزة'),
                  subtitle: Text('ينهي كل الجلسات المفتوحة على هذا الحساب', style: TextStyle(color: SN.textMut, fontSize: 12)),
                  onTap: () async {
                    try {
                      await Api.logoutAllDevices();
                    } catch (_) {}
                    await Api.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                      (_) => false,
                    );
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
                Center(
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) => Text(
                      'SocialNova v${snap.data?.version ?? '4.0.0'} • A WHX Labs Product',
                      style: const TextStyle(color: SN.textMut, fontSize: 11),
                    ),
                  ),
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

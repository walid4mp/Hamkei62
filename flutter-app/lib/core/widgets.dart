import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

import 'theme.dart';

/// Reusable vertical/horizontal video player with tap-to-play and a spinner.
class VideoBox extends StatefulWidget {
  const VideoBox({
    super.key,
    required this.url,
    this.autoPlay = false,
    this.loop = true,
    this.radius = 18,
    this.height,
    this.musicUrl = '',
    this.musicVolume = 1.0,
    this.playbackActive = true,
    this.muteNotifier,
    this.onTap,
  });

  final String url;
  final bool autoPlay;
  final bool loop;
  final double radius;
  final double? height;
  final String musicUrl;
  final double musicVolume;
  final bool playbackActive;
  final ValueNotifier<bool>? muteNotifier;
  final VoidCallback? onTap;

  @override
  State<VideoBox> createState() => _VideoBoxState();
}

class _VideoBoxState extends State<VideoBox> {
  VideoPlayerController? _c;
  AudioPlayer? _music;
  bool _ready = false;
  bool _musicReady = false;
  bool _failed = false;
  String _errorText = 'تعذّر تشغيل الفيديو';
  VoidCallback? _videoListener;
  VoidCallback? _muteListener;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.url.trim().isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    VideoPlayerController? c;
    AudioPlayer? music;
    try {
      final uri = Uri.parse(widget.url.trim());
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw Exception('BAD_VIDEO_URL');
      }

      c = VideoPlayerController.networkUrl(uri);
      await c.initialize();
      await c.setLooping(widget.loop);
      await c.setVolume(widget.muteNotifier?.value == true ? 0.0 : 1.0); // video's original audio

      final musicUrl = widget.musicUrl.trim();
      if (musicUrl.isNotEmpty) {
        final mUri = Uri.tryParse(musicUrl);
        if (mUri != null && (mUri.scheme == 'http' || mUri.scheme == 'https')) {
          music = AudioPlayer();
          await music.setVolume(widget.musicVolume.clamp(0.0, 1.0).toDouble());
          await music.setUrl(musicUrl);
          await music.setLoopMode(LoopMode.one);
          _musicReady = true;
        }
      }

      if (!mounted) {
        await c.dispose();
        await music?.dispose();
        return;
      }

      _c = c;
      _music = music;
      _videoListener = _syncMediaState;
      c.addListener(_videoListener!);
      if (widget.muteNotifier != null) { _muteListener = () { _applyMute(); }; widget.muteNotifier!.addListener(_muteListener!); }
      setState(() => _ready = true);

      if (widget.autoPlay && widget.playbackActive) { await _playTogether(); }
    } catch (e) {
      await c?.dispose();
      await music?.dispose();
      if (mounted) {
        setState(() {
          _failed = true;
          _errorText = 'تعذّر تشغيل الفيديو أو الصوت';
        });
      }
    }
  }

  void _applyMute() { final c=_c; if(c==null||!c.value.isInitialized)return; c.setVolume(widget.muteNotifier?.value==true?0.0:1.0); }

  @override
  void didUpdateWidget(covariant VideoBox oldWidget) { super.didUpdateWidget(oldWidget); if(oldWidget.playbackActive!=widget.playbackActive && _ready){ if(widget.playbackActive){ _playTogether(); } else { _pauseTogether(); } } if(oldWidget.muteNotifier!=widget.muteNotifier){ if(oldWidget.muteNotifier!=null && _muteListener!=null) oldWidget.muteNotifier!.removeListener(_muteListener!); if(widget.muteNotifier!=null){ _muteListener=(){_applyMute();}; widget.muteNotifier!.addListener(_muteListener!); } _applyMute(); } }

  Future<void> _playTogether() async {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.play();
      if (_musicReady && _music != null && !_music!.playing) {
        await _music!.play();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _pauseTogether() async {
    try {
      await _c?.pause();
      if (_musicReady) await _music?.pause();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _syncMediaState() {
    final c = _c;
    final m = _music;
    if (c == null || m == null || !_musicReady) return;
    final value = c.value;
    if (!value.isInitialized) return;

    // Keep the music aligned with the video whenever the video loops.
    if (widget.loop && value.position >= value.duration - const Duration(milliseconds: 180)) {
      if (m.position > const Duration(milliseconds: 300)) {
        m.seek(Duration.zero);
      }
      if (value.isPlaying && !m.playing) {
        m.play();
      }
    }

    // The video's play/pause state is the master state for the music.
    if (value.isPlaying && !m.playing) {
      m.play();
    } else if (!value.isPlaying && m.playing) {
      m.pause();
    }
  }

  Future<void> _retry() async {
    await _disposePlayers();
    if (!mounted) return;
    setState(() {
      _failed = false;
      _ready = false;
      _musicReady = false;
    });
    await _init();
  }

  Future<void> _disposePlayers() async {
    final c = _c;
    final m = _music;
    if (c != null && _videoListener != null) c.removeListener(_videoListener!);
    if (widget.muteNotifier != null && _muteListener != null) widget.muteNotifier!.removeListener(_muteListener!);
    _c = null;
    _music = null;
    _videoListener = null;
    await c?.dispose();
    await m?.dispose();
  }

  @override
  void dispose() {
    final c = _c;
    final m = _music;
    if (c != null && _videoListener != null) c.removeListener(_videoListener!);
    if (widget.muteNotifier != null && _muteListener != null) widget.muteNotifier!.removeListener(_muteListener!);
    c?.dispose();
    m?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    if (_failed) {
      return Container(
        height: widget.height ?? 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: SN.bg3, borderRadius: radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, color: SN.textMut),
            const SizedBox(height: 8),
            Text(_errorText, style: const TextStyle(color: SN.textSec, fontSize: 12)),
            const SizedBox(height: 6),
            TextButton(onPressed: _retry, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (!_ready || _c == null) {
      return Container(
        height: widget.height ?? 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: SN.bg3, borderRadius: radius),
        child: const CircularProgressIndicator(strokeWidth: 2, color: SN.violet),
      );
    }

    final ratio = _c!.value.aspectRatio == 0 ? 16 / 9 : _c!.value.aspectRatio;
    return ClipRRect(
      borderRadius: radius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (_c!.value.isPlaying) {
            await _pauseTogether();
          } else {
            await _playTogether();
          }
          widget.onTap?.call();
        },
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_c!),
              if (!_c!.value.isPlaying)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: .45),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.icon = Icons.inbox_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 54, color: SN.textMut),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: SN.textSec)),
            ],
          ),
        ),
      );
}

class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2, color: SN.violet),
        ),
      );
}

/// Standard page header with a leading title and optional trailing actions.
class SNHeader extends StatelessWidget {
  const SNHeader({super.key, required this.title, this.trailing = const []});

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: SN.bg1,
          border: Border(bottom: BorderSide(color: SN.strokeSoft)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SN.grad),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 9),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3)),
            const Spacer(),
            ...trailing,
          ],
        ),
      );
}

/// Small interaction feedback used by primary navigation/actions.
void snClick() {
  HapticFeedback.selectionClick();
  SystemSound.play(SystemSoundType.click);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Row(children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const Spacer(),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ]),
  );
}

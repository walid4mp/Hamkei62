import 'package:flutter/foundation.dart';

/// Lightweight in-app Reels handoff state.
///
/// Reels stays mounted in the MainShell's IndexedStack, but when the user
/// navigates away we show a compact player over the destination page instead
/// of destroying the current reel. The full-screen Reels page resumes when
/// the user taps the mini-player.
class ReelsPlaybackState {
  const ReelsPlaybackState({
    required this.videoUrl,
    this.musicUrl = '',
    this.title = 'Reels',
    this.author = '',
    this.authorAvatar = '',
    this.index = 0,
  });

  final String videoUrl;
  final String musicUrl;
  final String title;
  final String author;
  final String authorAvatar;
  final int index;
}

class ReelsPlaybackController {
  ReelsPlaybackController._();
  static final ReelsPlaybackController i = ReelsPlaybackController._();

  final ValueNotifier<ReelsPlaybackState?> state = ValueNotifier<ReelsPlaybackState?>(null);

  void setCurrent(ReelsPlaybackState value) => state.value = value;
  void clear() => state.value = null;
  void dispose() => state.dispose();
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'theme.dart';

/// One Messenger chat-head for the whole inbox (not one circle per person).
/// The selected state is persisted so it can be restored the next time
/// SocialNova starts. The native OS bubble/notification still depends on the
/// Android notification system when the process has been fully terminated.
class ChatBubbleManager {
  ChatBubbleManager._();
  static final ChatBubbleManager i = ChatBubbleManager._();

  OverlayState? _overlay;
  OverlayEntry? _entry;
  VoidCallback? _onOpen;
  bool _requested = false;

  void setDefaultOpen(VoidCallback callback) => _onOpen = callback;

  void attach(OverlayState overlay) {
    _overlay = overlay;
    if (_requested && _entry == null) _insert();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('sn_messenger_bubble') == true) {
      _requested = true;
      if (_overlay != null && _entry == null) _insert();
    }
  }

  Future<void> showMessenger({VoidCallback? onOpen}) async {
    _requested = true;
    _onOpen = onOpen ?? _onOpen;
    final p = await SharedPreferences.getInstance();
    await p.setBool('sn_messenger_bubble', true);
    if (_overlay != null && _entry == null) _insert();
  }

  Future<void> hideMessenger() async {
    _requested = false;
    _entry?.remove();
    _entry = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool('sn_messenger_bubble', false);
  }

  void _insert() {
    final overlay = _overlay;
    if (overlay == null || _entry != null) return;
    _entry = OverlayEntry(
      builder: (_) => _MessengerBubble(onOpen: () {
        _entry?.remove();
        _entry = null;
        _onOpen?.call();
      }, onClose: hideMessenger),
    );
    overlay.insert(_entry!);
  }

  void hide(String _) => hideMessenger();
  void hideAll() => hideMessenger();
}

class _MessengerBubble extends StatefulWidget {
  const _MessengerBubble({required this.onOpen, required this.onClose});
  final VoidCallback onOpen;
  final VoidCallback onClose;
  @override
  State<_MessengerBubble> createState() => _MessengerBubbleState();
}

class _MessengerBubbleState extends State<_MessengerBubble> {
  Offset position = const Offset(12, 180);
  List<dynamic> convos = const [];
  bool dragging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Api.conversations();
      if (mounted) setState(() => convos = rows);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final x = position.dx.clamp(8.0, size.width - 68.0);
    final y = position.dy.clamp(70.0, size.height - 100.0);
    final preview = convos.take(3).map((e) => Map<String,dynamic>.from(e as Map)).toList();
    final unread = convos.fold<int>(0, (n,e) => n + (int.tryParse('${(e as Map)['unreadCount'] ?? 0}') ?? 0));
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanStart: (_) => setState(() => dragging = true),
        onPanUpdate: (d) => setState(() => position += d.delta),
        onPanEnd: (_) => setState(() => dragging = false),
        onTap: widget.onOpen,
        onLongPress: widget.onClose,
        child: AnimatedScale(
          scale: dragging ? 1.08 : 1,
          duration: const Duration(milliseconds: 120),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SN.grad,
                  border: Border.all(color: SN.bg1, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .30), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: preview.isEmpty
                    ? const Icon(Icons.forum_rounded, color: Colors.white, size: 29)
                    : Stack(children: [
                        for (var i=0; i<preview.length; i++) Positioned(
                          left: 9.0 + i*14,
                          top: 16.0 - (i==1?5:0),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: SN.bg1,
                            child: CircleAvatar(radius: 12, backgroundImage: '${preview[i]['avatarUrl'] ?? ''}'.isNotEmpty ? NetworkImage('${preview[i]['avatarUrl']}') : null, child: '${preview[i]['avatarUrl'] ?? ''}'.isEmpty ? Text('${preview[i]['displayName'] ?? preview[i]['username'] ?? '?'}'.characters.first) : null),
                          ),
                        ),
                      ]),
              ),
              if (unread > 0) Positioned(
                right: -2,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: SN.red, borderRadius: BorderRadius.circular(12), border: Border.all(color: SN.bg1, width: 2)),
                  child: Text(unread > 99 ? '99+' : '$unread', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

/// Messenger-style floating chat heads shown while the app is open.
class ChatBubbleManager {
  ChatBubbleManager._();
  static final ChatBubbleManager i = ChatBubbleManager._();

  OverlayState? _overlay;
  final Map<String, OverlayEntry> _entries = {};
  final Map<String, _BubbleData> _data = {};

  void attach(OverlayState overlay) => _overlay = overlay;

  void show({required String userId, required String name, String avatar = '', VoidCallback? onOpen}) {
    if (userId.isEmpty || userId == '${Api.me?['id']}') return;
    _data[userId] = _BubbleData(userId: userId, name: name, avatar: avatar);
    if (_entries.containsKey(userId)) return;
    final entry = OverlayEntry(builder: (_) => _ChatBubble(data: _data[userId]!, onClose: () => hide(userId), onOpen: onOpen));
    _entries[userId] = entry;
    _overlay?.insert(entry);
  }

  void hide(String userId) {
    _entries.remove(userId)?.remove();
    _data.remove(userId);
  }

  void hideAll() {
    for (final e in _entries.values) e.remove();
    _entries.clear();
    _data.clear();
  }
}

class _BubbleData {
  const _BubbleData({required this.userId, required this.name, required this.avatar});
  final String userId;
  final String name;
  final String avatar;
}

class _ChatBubble extends StatefulWidget {
  const _ChatBubble({required this.data, required this.onClose, this.onOpen});
  final _BubbleData data;
  final VoidCallback onClose;
  final VoidCallback? onOpen;
  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  Offset position = const Offset(12, 180);
  bool dragging = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final x = position.dx.clamp(8.0, size.width - 68.0);
    final y = position.dy.clamp(70.0, size.height - 100.0);
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanStart: (_) => setState(() => dragging = true),
        onPanUpdate: (d) => setState(() => position += d.delta),
        onPanEnd: (_) => setState(() => dragging = false),
        onTap: () {
          ChatBubbleManager.i.hide(widget.data.userId);
          widget.onOpen?.call();
        },
        onLongPress: widget.onClose,
        child: AnimatedScale(
          scale: dragging ? 1.08 : 1,
          duration: const Duration(milliseconds: 120),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SN.bg1, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: ClipOval(
                  child: widget.data.avatar.isNotEmpty
                      ? Image.network(widget.data.avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                      : _fallback(),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: SN.cyan, border: Border.all(color: SN.bg1, width: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(color: SN.bg2, alignment: Alignment.center, child: Text(widget.data.name.isEmpty ? '?' : widget.data.name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)));
}

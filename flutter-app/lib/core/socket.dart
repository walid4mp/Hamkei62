import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api.dart';

/// Thin, defensive wrapper around the backend Socket.IO namespace.
/// Every call is safe to make even when the socket is offline.
class SocketService {
  SocketService._();
  static final SocketService i = SocketService._();

  IO.Socket? _s;
  bool get connected => _s?.connected == true;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _liveChat = StreamController<Map<String, dynamic>>.broadcast();
  final _liveUsers = StreamController<Map<String, dynamic>>.broadcast();
  final _liveGifts = StreamController<Map<String, dynamic>>.broadcast();
  final _liveTaps = StreamController<Map<String, dynamic>>.broadcast();
  final _liveComments = StreamController<Map<String, dynamic>>.broadcast();
  final _liveCommentPins = StreamController<Map<String, dynamic>>.broadcast();
  final _liveCommentDeletes = StreamController<Map<String, dynamic>>.broadcast();
  final _liveModerators = StreamController<Map<String, dynamic>>.broadcast();
  final _liveMuted = StreamController<Map<String, dynamic>>.broadcast();
  final _liveRemoved = StreamController<Map<String, dynamic>>.broadcast();
  final _liveMutedNotice = StreamController<Map<String, dynamic>>.broadcast();
  final _callInvites = StreamController<Map<String, dynamic>>.broadcast();
  final _callAccepted = StreamController<Map<String, dynamic>>.broadcast();
  final _callRejected = StreamController<Map<String, dynamic>>.broadcast();
  final _callReels = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDelivered = StreamController<Map<String, dynamic>>.broadcast();
  final _messageRead = StreamController<Map<String, dynamic>>.broadcast();
  final _messageRequestAccepted = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callInvites => _callInvites.stream;
  Stream<Map<String, dynamic>> get callAccepted => _callAccepted.stream;
  Stream<Map<String, dynamic>> get callRejected => _callRejected.stream;
  Stream<Map<String, dynamic>> get callReels => _callReels.stream;
  Stream<Map<String, dynamic>> get messageDelivered => _messageDelivered.stream;
  Stream<Map<String, dynamic>> get messageRead => _messageRead.stream;
  Stream<Map<String, dynamic>> get messageRequestAccepted => _messageRequestAccepted.stream;

  /// Peer typing presence: `{from, typing}` relayed by the server.
  Stream<Map<String, dynamic>> get typing => _typing.stream;

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get liveChat => _liveChat.stream;
  Stream<Map<String, dynamic>> get liveUsers => _liveUsers.stream;
  Stream<Map<String, dynamic>> get liveGifts => _liveGifts.stream;
  Stream<Map<String, dynamic>> get liveTaps => _liveTaps.stream;
  Stream<Map<String, dynamic>> get liveComments => _liveComments.stream;
  Stream<Map<String, dynamic>> get liveCommentPins => _liveCommentPins.stream;
  Stream<Map<String, dynamic>> get liveCommentDeletes => _liveCommentDeletes.stream;
  Stream<Map<String, dynamic>> get liveModerators => _liveModerators.stream;
  Stream<Map<String, dynamic>> get liveMuted => _liveMuted.stream;
  Stream<Map<String, dynamic>> get liveRemoved => _liveRemoved.stream;
  Stream<Map<String, dynamic>> get liveMutedNotice => _liveMutedNotice.stream;

  void connect() {
    if (Api.token == null) return;
    if (_s != null && _s!.connected) return;
    _s?.dispose();
    try {
      final s = IO.io(
        Api.socketUrl,
        IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
      );
      s.onConnect((_) {
        s.emit('auth', {'token': Api.token});
      });
      s.on('message', (d) {
        if (d is Map) _messages.add(Map<String, dynamic>.from(d));
      });
      s.on('message:delivered', (d) { if (d is Map) _messageDelivered.add(Map<String, dynamic>.from(d)); });
      s.on('message:read', (d) { if (d is Map) _messageRead.add(Map<String, dynamic>.from(d)); });
      s.on('message:request:accepted', (d) { if (d is Map) _messageRequestAccepted.add(Map<String, dynamic>.from(d)); });
      s.on('typing', (d) { if (d is Map) _typing.add(Map<String, dynamic>.from(d)); });
      s.on('live:chat', (d) { if (d is Map) _liveChat.add(Map<String, dynamic>.from(d)); });
      s.on('live:comment', (d) { if (d is Map) _liveComments.add(Map<String, dynamic>.from(d)); });
      s.on('live:comment:pin', (d) { if (d is Map) _liveCommentPins.add(Map<String, dynamic>.from(d)); });
      s.on('live:comment:delete', (d) { if (d is Map) _liveCommentDeletes.add(Map<String, dynamic>.from(d)); });
      s.on('live:moderator', (d) { if (d is Map) _liveModerators.add(Map<String, dynamic>.from(d)); });
      s.on('live:muted', (d) { if (d is Map) _liveMuted.add(Map<String, dynamic>.from(d)); });
      s.on('live:removed', (d) { if (d is Map) _liveRemoved.add(Map<String, dynamic>.from(d)); });
      s.on('live:muted-notice', (d) { if (d is Map) _liveMutedNotice.add(Map<String, dynamic>.from(d)); });
      s.on('live:user-joined', (d) {
        if (d is Map) _liveUsers.add(Map<String, dynamic>.from(d));
      });
      s.on('call:invite', (d) { if (d is Map) _callInvites.add(Map<String, dynamic>.from(d)); });
      s.on('call:accept', (d) { if (d is Map) _callAccepted.add(Map<String, dynamic>.from(d)); });
      s.on('call:reject', (d) { if (d is Map) _callRejected.add(Map<String, dynamic>.from(d)); });
      s.on('call:reel', (d) { if (d is Map) _callReels.add(Map<String, dynamic>.from(d)); });
      s.on('live:gift', (d) {
        if (d is Map) _liveGifts.add(Map<String, dynamic>.from(d));
      });
      s.on('live:tap', (d) {
        if (d is Map) _liveTaps.add(Map<String, dynamic>.from(d));
      });
      s.onConnectError((_) {});
      s.onError((_) {});
      s.connect();
      _s = s;
    } catch (_) {
      // Socket.IO is an enhancement; the REST fallback still works.
    }
  }


  void sendCallInvite({required String to, required String roomName, required bool video, required String name, required String avatar}) { _s?.emit('call:invite', {'to':to,'roomName':roomName,'video':video,'name':name,'avatar':avatar}); }
  void sendCallAccept(String to, String roomName) { _s?.emit('call:accept', {'to':to,'roomName':roomName}); }
  void sendCallReject(String to) { _s?.emit('call:reject', {'to':to}); }
  void sendCallReel({required String to, required String url, String title = ''}) { _s?.emit('call:reel', {'to': to, 'url': url, 'title': title}); }

  void sendMessage(String to, String body, {String effect = ''}) {
    _s?.emit('message', {'to': to, 'body': body, if (effect.isNotEmpty) 'effect': effect});
  }

  /// Typing presence is best-effort: it is emitted only while the socket is
  /// connected and it always expires on the receiver side.
  void sendTyping({required String to, bool typing = true}) {
    _s?.emit('typing', {'to': to, 'typing': typing});
  }

  void joinLive(String room) {
    _s?.emit('live:join', {'room': room});
  }

  void leaveLive(String room) {
    _s?.emit('live:leave', {'room': room});
  }

  void sendLiveChat(String room, String body, {String replyToId = ''}) {
    _s?.emit('live:chat', {'room': room, 'body': body, if (replyToId.isNotEmpty) 'replyToId': replyToId});
  }
  void pinLiveComment(String room, String commentId) { _s?.emit('live:comment:pin', {'room': room, 'commentId': commentId}); }
  void deleteLiveComment(String room, String commentId) { _s?.emit('live:comment:delete', {'room': room, 'commentId': commentId}); }
  void muteLiveUser(String room, String userId, {bool value = true, String reason = ''}) { _s?.emit('live:mute', {'room': room, 'userId': userId, 'value': value, 'reason': reason}); }
  void removeLiveUser(String room, String userId) { _s?.emit('live:remove', {'room': room, 'userId': userId}); }

  void sendLiveTap(String room) {
    _s?.emit('live:tap', {'room': room});
  }

  void dispose() {
    _s?.dispose();
    _s = null;
  }
}

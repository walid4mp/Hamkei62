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
  final _callInvites = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDelivered = StreamController<Map<String, dynamic>>.broadcast();
  final _messageRead = StreamController<Map<String, dynamic>>.broadcast();
  final _messageRequestAccepted = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callInvites => _callInvites.stream;
  Stream<Map<String, dynamic>> get messageDelivered => _messageDelivered.stream;
  Stream<Map<String, dynamic>> get messageRead => _messageRead.stream;
  Stream<Map<String, dynamic>> get messageRequestAccepted => _messageRequestAccepted.stream;

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get liveChat => _liveChat.stream;
  Stream<Map<String, dynamic>> get liveUsers => _liveUsers.stream;
  Stream<Map<String, dynamic>> get liveGifts => _liveGifts.stream;

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
      s.on('live:chat', (d) {
        if (d is Map) _liveChat.add(Map<String, dynamic>.from(d));
      });
      s.on('live:user-joined', (d) {
        if (d is Map) _liveUsers.add(Map<String, dynamic>.from(d));
      });
      s.on('call:invite', (d) { if (d is Map) _callInvites.add(Map<String, dynamic>.from(d)); });
      s.on('live:gift', (d) {
        if (d is Map) _liveGifts.add(Map<String, dynamic>.from(d));
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

  void sendMessage(String to, String body) {
    _s?.emit('message', {'to': to, 'body': body});
  }

  void joinLive(String room) {
    _s?.emit('live:join', {'room': room});
  }

  void leaveLive(String room) {
    _s?.emit('live:leave', {'room': room});
  }

  void sendLiveChat(String room, String body) {
    _s?.emit('live:chat', {'room': room, 'body': body});
  }

  void dispose() {
    _s?.dispose();
    _s = null;
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'socket.dart';

bool _firebaseReady = false;
final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
StreamSubscription? _messageSub;
StreamSubscription? _callSub;
StreamSubscription? _callKitSub;
Future<void> Function(Map<String, dynamic> data)? onSystemCallAccepted;
Future<void> Function()? onAppUpdateNotificationTap;
Timer? _unreadTimer;
String _activeChatUserId = '';
String _currentUserId = '';

final ValueNotifier<int> unreadMessagesNotifier = ValueNotifier<int>(0);

String _uuid() {
  final r = Random();
  String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${['8','9','a','b'][r.nextInt(4)]}${h(3)}-${h(12)}';
}

String _accountKey(String suffix) => 'sn_${_currentUserId.isEmpty ? 'guest' : _currentUserId}_$suffix';

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

Future<String> getCallRingtone() async {
  final p = await _prefs();
  return p.getString(_accountKey('call_ringtone')) ?? 'call_ring';
}

Future<String> getNotificationSound() async {
  final p = await _prefs();
  return p.getString(_accountKey('message_sound')) ?? 'message';
}

Future<void> setCallRingtone(String key) async {
  final p = await _prefs();
  await p.setString(_accountKey('call_ringtone'), key);
  await _createNotificationChannels();
}

Future<void> setNotificationSound(String key) async {
  final p = await _prefs();
  await p.setString(_accountKey('message_sound'), key);
  await _createNotificationChannels();
}

Future<void> setActiveChat(String? userId) async {
  _activeChatUserId = (userId ?? '').trim();
}

Future<bool> _mutedSender(String senderId) async {
  final p = await _prefs();
  return p.getStringList(_accountKey('muted_senders'))?.contains(senderId) ?? false;
}

Future<bool> isSenderMuted(String senderId) => _mutedSender(senderId);

Future<void> setSenderMuted(String senderId, bool muted) => _setMutedSender(senderId, muted);

Future<void> _setMutedSender(String senderId, bool muted) async {
  final p = await _prefs();
  final key = _accountKey('muted_senders');
  final list = List<String>.from(p.getStringList(key) ?? const []);
  if (muted) {
    if (!list.contains(senderId)) list.add(senderId);
  } else {
    list.remove(senderId);
  }
  await p.setStringList(key, list);
}

AndroidNotificationChannel _messageChannel(String key) {
  final sound = switch (key) {
    'soft' => 'socialnova_message_soft',
    'digital' => 'socialnova_message_digital',
    _ => 'socialnova_message',
  };
  return AndroidNotificationChannel(
    'socialnova_messages_$key',
    key == 'silent' ? 'رسائل بدون صوت' : 'رسائل SocialNova',
    description: 'إشعارات الرسائل الجديدة في SocialNova',
    importance: Importance.high,
    playSound: key != 'silent',
    sound: key == 'silent' ? null : RawResourceAndroidNotificationSound(sound),
  );
}

Future<void> _createNotificationChannels() async {
  final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  for (final key in const ['message', 'soft', 'digital', 'silent']) {
    await android.createNotificationChannel(_messageChannel(key));
  }
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      'socialnova_updates',
      'تحديثات SocialNova',
      description: 'إشعارات توفر إصدارات جديدة من SocialNova',
      importance: Importance.high,
      playSound: true,
    ),
  );
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      'socialnova_calls',
      'مكالمات SocialNova',
      description: 'تنبيهات المكالمات الواردة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('socialnova_call'),
    ),
  );
}

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await _local.initialize(
    settings,
    onDidReceiveNotificationResponse: _onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  await _createNotificationChannels();
  await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}

Map<String, dynamic> _payloadMap(String? payload) {
  if (payload == null || payload.isEmpty) return <String, dynamic>{};
  try {
    final x = jsonDecode(payload);
    return x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

Future<void> _handleNotificationAction(NotificationResponse response) async {
  final data = _payloadMap(response.payload);
  if (data['type'] == 'app_update') {
    await onAppUpdateNotificationTap?.call();
    return;
  }
  final senderId = '${data['fromId'] ?? ''}';
  final messageId = '${data['messageId'] ?? ''}';
  final action = response.actionId;
  if (action == 'mute' && senderId.isNotEmpty) {
    await _setMutedSender(senderId, true);
    return;
  }
  if (action == 'like' && messageId.isNotEmpty) {
    await Api.init();
    if (Api.token != null) { try { await Api.reactToMessage(messageId, '❤️'); } catch (_) {} }
    return;
  }
  if (action == 'reply' && senderId.isNotEmpty) {
    final text = (response.input ?? '').trim();
    if (text.isEmpty) return;
    await Api.init();
    if (Api.token != null) { try { await Api.sendMessage(senderId, text); } catch (_) {} }
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  try {
    await _handleNotificationAction(response);
  } catch (_) {}
}

void _onNotificationResponse(NotificationResponse response) {
  unawaited(_handleNotificationAction(response));
}

Future<void> showAppUpdatePushNotification(Map<String, dynamic> data) async {
  try {
    final code = int.tryParse('${data['versionCode'] ?? ''}') ?? 0;
    if (code <= 0) return;
    final version = '${data['versionName'] ?? 'تحديث جديد'}';
    final p = await _prefs();
    final key = _accountKey('last_update_notification_code');
    final already = p.getInt(key) ?? 0;
    if (already >= code) return;
    await _local.show(
      8800,
      'تحديث جديد لـ SocialNova',
      'الإصدار $version متاح الآن — اضغط لعرض التحديث.',
      const NotificationDetails(
        android: AndroidNotificationDetails('socialnova_updates', 'تحديثات SocialNova', channelDescription: 'إشعارات توفر إصدارات جديدة من SocialNova', importance: Importance.high, priority: Priority.high, icon: '@mipmap/ic_launcher', playSound: true),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'app_update', 'versionCode': code}),
    );
    await p.setInt(key, code);
  } catch (_) {}
}

Future<void> showAppUpdateNotification(dynamic update) async {
  try {
    final p = await _prefs();
    final key = _accountKey('last_update_notification_code');
    final already = p.getInt(key) ?? 0;
    if (already >= update.versionCode) return;
    await _local.show(
      8800,
      'تحديث جديد لـ SocialNova',
      'الإصدار ${update.versionName} متاح الآن — اضغط لعرض التحديث.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'socialnova_updates',
          'تحديثات SocialNova',
          channelDescription: 'إشعارات توفر إصدارات جديدة من SocialNova',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'app_update', 'versionCode': update.versionCode}),
    );
    await p.setInt(key, update.versionCode);
  } catch (_) {}
}

Future<void> showMessageNotification(Map<String, dynamic> data) async {
  final senderId = '${data['fromId'] ?? ''}';
  if (senderId.isEmpty || senderId == '${Api.me?['id'] ?? ''}') return;
  if (_activeChatUserId == senderId) return;
  if (await _mutedSender(senderId)) return;
  final p = await _prefs();
  if (p.getBool(_accountKey('message_notifications')) == false) return;
  final sound = await getNotificationSound();
  final channelKey = sound == 'silent' ? 'silent' : sound;
  final name = '${data['name'] ?? data['displayName'] ?? 'SocialNova'}';
  final body = '${data['body'] ?? 'لديك رسالة جديدة'}';
  final payload = jsonEncode(data);
  final details = AndroidNotificationDetails(
    'socialnova_messages_$channelKey',
    'رسائل SocialNova',
    channelDescription: 'إشعارات الرسائل الجديدة',
    importance: Importance.high,
    priority: Priority.high,
    playSound: channelKey != 'silent',
    sound: channelKey == 'silent' ? null : RawResourceAndroidNotificationSound(channelKey == 'soft' ? 'socialnova_message_soft' : channelKey == 'digital' ? 'socialnova_message_digital' : 'socialnova_message'),
    category: AndroidNotificationCategory.message,
    actions: const [
      AndroidNotificationAction('reply', 'رد', inputs: [AndroidNotificationActionInput(label: 'اكتب ردك')], showsUserInterface: true, cancelNotification: true),
      AndroidNotificationAction('like', 'إعجاب', cancelNotification: false),
      AndroidNotificationAction('mute', 'كتم', cancelNotification: true),
    ],
  );
  await _local.show(
    senderId.hashCode & 0x7fffffff,
    name,
    body,
    NotificationDetails(android: details),
    payload: payload,
  );
}

Future<void> refreshUnreadCount() async {
  try {
    final rows = await Api.conversations();
    var total = 0;
    for (final row in rows) {
      if (row is Map) total += int.tryParse('${row['unreadCount'] ?? 0}') ?? 0;
    }
    unreadMessagesNotifier.value = total;
  } catch (_) {}
}

Future<void> showIncomingCallFromData(Map<String, dynamic> data) async {
  final id = _uuid();
  final callId = '${data['callId'] ?? ''}';
  final name = '${data['name'] ?? data['fromName'] ?? 'SocialNova'}';
  final video = '${data['video']}' == 'true' || data['video'] == true;
  final room = '${data['roomName'] ?? ''}';
  final fromId = '${data['fromId'] ?? data['from'] ?? ''}';
  final params = CallKitParams(
    id: id,
    nameCaller: name,
    appName: 'SocialNova',
    avatar: '${data['avatar'] ?? ''}',
    handle: fromId,
    type: video ? 1 : 0,
    duration: 60000,
    extra: <String, dynamic>{'callId': callId, 'roomName': room, 'fromId': fromId, 'video': video, 'name': name, 'avatar': '${data['avatar'] ?? ''}'},
    missedCallNotification: const NotificationParams(showNotification: true, isShowCallback: true, subtitle: 'مكالمة فائتة', callbackText: 'اتصال'),
    callingNotification: const NotificationParams(showNotification: true, isShowCallback: true, subtitle: 'مكالمة واردة…', callbackText: 'إنهاء'),
    android: const AndroidParams(
      isCustomNotification: true,
      ringtonePath: 'system_ringtone_default',
      incomingCallNotificationChannelName: 'مكالمات SocialNova',
      missedCallNotificationChannelName: 'مكالمات فائتة',
      isShowCallID: false,
    ),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

Future<void> _bindCallKitEvents() async {
  await _callKitSub?.cancel();
  _callKitSub = FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;
    try {
      final dynamic params = (event as dynamic).callKitParams;
      final extra = params?.extra is Map ? Map<String, dynamic>.from(params.extra as Map) : <String, dynamic>{};
      final callId = '${extra['callId'] ?? ''}';
      if (callId.isEmpty) return;
      final name = '${extra['name'] ?? params?.nameCaller ?? 'SocialNova'}';
      final roomName = '${extra['roomName'] ?? ''}';
      final fromId = '${extra['fromId'] ?? params?.handle ?? ''}';
      final video = extra['video'] == true || '${extra['video']}' == 'true';
      final eventName = '${(event as dynamic).eventName}';
      if (eventName.contains('accept')) {
        await Api.init();
        await Api.acceptCall(callId);
        await FlutterCallkitIncoming.setCallConnected(params?.id ?? '');
        final cb = onSystemCallAccepted;
        if (cb != null) await cb({'callId':callId,'roomName':roomName,'fromId':fromId,'name':name,'video':video});
      } else if (eventName.contains('decline')) {
        await Api.init();
        try { await Api.rejectCall(callId); } catch (_) {}
      } else if (eventName.contains('timeout')) {
        await Api.init();
        try { await Api.endCall(callId, reason:'RING_TIMEOUT'); } catch (_) {}
      }
    } catch (_) {}
  });
}

Future<void> _bindRealtime() async {
  SocketService.i.connect();
  await _messageSub?.cancel();
  await _callSub?.cancel();
  _messageSub = SocketService.i.messages.listen((m) {
    final mine = '${m['senderId']}' == '${Api.me?['id'] ?? ''}';
    if (!mine && '${m['receiverId']}' == '${Api.me?['id'] ?? ''}') {
      unawaited(showMessageNotification({
        'type': 'message',
        'messageId': '${m['id'] ?? ''}',
        'fromId': '${m['senderId'] ?? ''}',
        'name': '${m['senderName'] ?? m['sender']?['displayName'] ?? 'SocialNova'}',
        'avatar': '${m['senderAvatar'] ?? ''}',
        'body': '${m['body'] ?? 'لديك رسالة جديدة'}',
      }));
      unawaited(refreshUnreadCount());
    }
  });
  _callSub = SocketService.i.callInvites.listen((m) {
    unawaited(showIncomingCallFromData(m));
  });
  _unreadTimer?.cancel();
  _unreadTimer = Timer.periodic(const Duration(seconds: 25), (_) => refreshUnreadCount());
  await refreshUnreadCount();
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _initLocalNotifications();
    final data = Map<String, dynamic>.from(message.data);
    _currentUserId = '${data['toId'] ?? ''}';
    if (data['type'] == 'call') {
      await showIncomingCallFromData(data);
    } else if (data['type'] == 'message' || data['type'] == 'call_message') {
      await showMessageNotification(data);
    }
  } catch (_) {}
}

Future<void> initPushNotifications() async {
  if (Api.token == null) return;
  _currentUserId = '${Api.me?['id'] ?? ''}';
  await _initLocalNotifications();
  try {
    await FlutterCallkitIncoming.requestNotificationPermission({
      'title': 'إشعارات المكالمات',
      'rationaleMessagePermission': 'نحتاج الإذن لإظهار المكالمات الواردة حتى عندما يكون التطبيق مغلقًا.',
      'postNotificationMessageRequired': 'فعّل إشعارات المكالمات من إعدادات الهاتف.',
    });
    final canFull = await FlutterCallkitIncoming.canUseFullScreenIntent();
    if (!canFull) await FlutterCallkitIncoming.requestFullIntentPermission();
  } catch (_) {}
  await _bindCallKitEvents();
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (_) {
    // Firebase is optional until android/google-services.json is supplied.
    await _bindRealtime();
    return;
  }

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) { try { await Api.savePushToken(token); } catch (_) {} }
  messaging.onTokenRefresh.listen((t) async { try { await Api.savePushToken(t); } catch (_) {} });
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((message) async {
    final data = Map<String, dynamic>.from(message.data);
    _currentUserId = '${data['toId'] ?? ''}';
    if (data['type'] == 'call') {
      await showIncomingCallFromData(data);
    } else if (data['type'] == 'message' || data['type'] == 'call_message') {
      await showMessageNotification(data);
      await refreshUnreadCount();
    }
  });
  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    final data = Map<String, dynamic>.from(message.data);
    if (data['type'] == 'app_update') await onAppUpdateNotificationTap?.call();
  });
  final initial = await messaging.getInitialMessage();
  if (initial != null) {
    final data = Map<String, dynamic>.from(initial.data);
    if (data['type'] == 'app_update') unawaited(onAppUpdateNotificationTap?.call());
  }
  await _bindRealtime();
}

bool get firebaseReady => _firebaseReady;

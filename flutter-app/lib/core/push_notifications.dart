import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

import 'api.dart';

bool _firebaseReady = false;

String _uuid() {
  final r = Random();
  String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${['8','9','a','b'][r.nextInt(4)]}${h(3)}-${h(12)}';
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    if (message.data['type'] == 'call') {
      await showIncomingCallFromData(message.data);
    }
  } catch (_) {}
}

Future<void> showIncomingCallFromData(Map<String, dynamic> data) async {
  final id = '${data['callId'] ?? _uuid()}';
  final name = '${data['name'] ?? 'SocialNova'}';
  final video = '${data['video']}' == 'true';
  final room = '${data['roomName'] ?? ''}';
  final fromId = '${data['fromId'] ?? ''}';
  final params = CallKitParams(
    id: id,
    nameCaller: name,
    appName: 'SocialNova',
    avatar: '${data['avatar'] ?? ''}',
    handle: fromId,
    type: video ? 1 : 0,
    duration: 30000,
    extra: <String, dynamic>{'roomName': room, 'fromId': fromId, 'video': video},
    missedCallNotification: const NotificationParams(showNotification: true, isShowCallback: true, subtitle: 'مكالمة فائتة', callbackText: 'اتصال'),
    callingNotification: const NotificationParams(showNotification: true, isShowCallback: true, subtitle: 'مكالمة واردة…', callbackText: 'إنهاء'),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

Future<void> initPushNotifications() async {
  if (Api.token == null) return;
  try {
    await Firebase.initializeApp();
    _firebaseReady = true;
  } catch (_) {
    // Firebase is optional until google-services.json is added.
    return;
  }

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) {
    await Api.savePushToken(token).catchError((_) {});
  }
  messaging.onTokenRefresh.listen((t) => Api.savePushToken(t).catchError((_) {}));
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((message) async {
    if (message.data['type'] == 'call') {
      await showIncomingCallFromData(message.data);
    }
  });

}

bool get firebaseReady => _firebaseReady;

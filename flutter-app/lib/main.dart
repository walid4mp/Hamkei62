import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/theme.dart';
import 'core/localization.dart';
import 'core/chat_bubbles.dart';
import 'core/push_notifications.dart';
import 'core/app_update.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/social.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  // A 401 anywhere means the session is gone: clear state and return to login.
  Api.onUnauthorized = () async {
    final nav = socialNovaNavigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  };
  onAppUpdateNotificationTap = () async {
    final nav = socialNovaNavigatorKey.currentState;
    final context = nav?.overlay?.context;
    if (context != null) await AppUpdateManager.checkAndShow(context, force: true);
  };
  onSystemCallAccepted = (data) async {
    final nav = socialNovaNavigatorKey.currentState;
    if (nav == null) return;
    final peer = '${data['fromId'] ?? ''}';
    final title = '${data['name'] ?? 'مكالمة'}';
    final room = '${data['roomName'] ?? ''}';
    final callId = '${data['callId'] ?? ''}';
    if (room.isEmpty || callId.isEmpty) return;
    nav.push(MaterialPageRoute(builder: (_) => CallRoomPage(title:title, roomName:room, videoCall:data['video']==true, peerUserId:peer, isCaller:false, callId:callId)));
  };
  if (Api.token != null) { await initPushNotifications(); }
  ChatBubbleManager.i.setDefaultOpen(() {
    final nav = socialNovaNavigatorKey.currentState;
    if (nav != null) nav.push(MaterialPageRoute(builder: (_) => const MessengerPage()));
  });
  final prefs = await SharedPreferences.getInstance();
  AppAppearance.mode.value = prefs.getString('app_appearance') ?? 'neon';
  await AppLocale.load();
  runApp(const SocialNovaApp());
}

final GlobalKey<NavigatorState> socialNovaNavigatorKey = GlobalKey<NavigatorState>();

class SocialNovaApp extends StatelessWidget {
  const SocialNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppAppearance.mode,
      builder: (context, mode, _) => ValueListenableBuilder<Locale>(
        valueListenable: AppLocale.locale,
        builder: (context, locale, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SocialNova',
          navigatorKey: socialNovaNavigatorKey,
          theme: SN.theme(night: mode == 'night'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final overlay = socialNovaNavigatorKey.currentState?.overlay;
              if (overlay != null) ChatBubbleManager.i.attach(overlay);
              if (Api.token != null) { AppUpdateManager.checkAndShow(context); }
            });
            return Directionality(
              textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Api.token == null ? const AuthScreen() : const MainShell(),
        ),
      ),
    );
    
  }
}

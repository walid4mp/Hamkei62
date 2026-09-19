import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/theme.dart';
import 'core/chat_bubbles.dart';
import 'screens/auth.dart';
import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const SocialNovaApp());
}

final GlobalKey<NavigatorState> socialNovaNavigatorKey = GlobalKey<NavigatorState>();

class SocialNovaApp extends StatelessWidget {
  const SocialNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SocialNova',
      navigatorKey: socialNovaNavigatorKey,
      theme: SN.theme(),
      // Arabic date pickers / dialogs need the global delegates, otherwise
      // showDatePicker(locale: Locale('ar')) throws at runtime.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: const Locale('ar'),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final overlay = socialNovaNavigatorKey.currentState?.overlay;
          if (overlay != null) ChatBubbleManager.i.attach(overlay);
        });
        return Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink());
      },
      home: Api.token == null ? const AuthScreen() : const MainShell(),
    );
  }
}

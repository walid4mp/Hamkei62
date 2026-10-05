import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/toast/app_toast.dart';
import '../../../core/config/app_identity.dart';

class SupportActions {
  const SupportActions._();

  static Future<void> sendFeedback(BuildContext context) async {
    if (AppIdentity.supportEmail.isEmpty) {
      AppToast.info('Support email is not configured yet.');
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: AppIdentity.supportEmail,
      queryParameters: {
        'subject': '${AppIdentity.appName} Feedback',
        'body': 'Hello ${AppIdentity.ownerName},\n\n',
      },
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.error('Could not open your email app.');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error('Could not open your email app.');
      }
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'push_notifications.dart';

class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String title;
  final String notes;
  final bool mandatory;
  const AppUpdateInfo({required this.versionCode, required this.versionName, required this.apkUrl, required this.title, required this.notes, required this.mandatory});
}

class AppUpdateManager {
  static const _releaseApi = 'https://api.github.com/repos/walid4mp/Hamkei62/releases/latest';
  static const _channel = MethodChannel('socialnova/updater');
  static bool _dialogShown = false;
  static bool _checking = false;

  static Future<AppUpdateInfo?> check({bool notify = true}) async {
    if (_checking) return null;
    _checking = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;
      final response = await http.get(Uri.parse(_releaseApi), headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final tag = '${data['tag_name'] ?? ''}'.replaceFirst(RegExp(r'^v'), '').trim();
      final releaseName = '${data['name'] ?? ''}'.trim();
      final body = '${data['body'] ?? ''}'.trim();
      final assets = (data['assets'] as List?) ?? const [];
      Map<String, dynamic>? apk;
      for (final raw in assets) {
        if (raw is Map) {
          final name = '${raw['name'] ?? ''}'.toLowerCase();
          if (name.endsWith('.apk') && (name.contains('socialnova') || name == 'app-release.apk')) {
            apk = Map<String, dynamic>.from(raw);
            break;
          }
        }
      }
      final match = RegExp(r'\+(\d+)$').firstMatch(tag);
      final code = int.tryParse(match?.group(1) ?? '') ?? 0;
      final apkUrl = '${apk?['browser_download_url'] ?? ''}'.trim();
      if (code <= currentCode || apkUrl.isEmpty) return null;
      final update = AppUpdateInfo(
        versionCode: code,
        versionName: tag.isEmpty ? releaseName : tag,
        apkUrl: apkUrl,
        title: releaseName.isEmpty ? 'تحديث جديد لـ SocialNova' : releaseName,
        notes: body.isEmpty ? 'تحسينات وإصلاحات جديدة.' : body,
        mandatory: data['prerelease'] == false && data['draft'] == false && releaseName.contains('[إجباري]'),
      );
      if (notify) await showAppUpdateNotification(update);
      return update;
    } catch (_) {
      return null;
    } finally {
      _checking = false;
    }
  }

  static Future<void> checkAndShow(BuildContext context, {bool force = false}) async {
    if (_dialogShown && !force) return;
    final update = await check();
    if (update == null || !context.mounted) return;
    _dialogShown = true;
    await showUpdateDialog(context, update);
  }

  static Future<void> showUpdateDialog(BuildContext context, AppUpdateInfo update) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: const [Icon(Icons.system_update_alt), SizedBox(width: 10), Expanded(child: Text('تحديث جديد'))]),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الإصدار ${update.versionName}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(update.notes, maxLines: 10, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          const Text('سيتم تثبيت التحديث فوق النسخة الحالية بدون حذف بيانات حسابك.', style: TextStyle(fontSize: 13)),
        ])),
        actions: [
          if (!update.mandatory) TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لاحقًا')),
          FilledButton.icon(onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              await _channel.invokeMethod('downloadAndInstall', {'url': update.apkUrl, 'fileName': 'SocialNova-${update.versionName}.apk'});
            } on PlatformException catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر بدء التحديث: ${e.message ?? e.code}')));
            }
          }, icon: const Icon(Icons.download), label: const Text('قم بتحديث التطبيق')),
        ],
      ),
    );
  }
}

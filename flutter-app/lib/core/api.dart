import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'device_identity.dart';

const Map<String, String> apiMessages = {
  'EMAIL_OR_USERNAME_EXISTS': 'البريد الإلكتروني أو اسم المستخدم مستخدم بالفعل.',
  'INVALID_CREDENTIALS': 'بيانات الدخول غير صحيحة.',
  'DEVICE_BANNED': 'تم حظر هذا الهاتف من SocialNova. إذا كنت تعتقد أن الحظر بالخطأ، تواصل مع الإدارة.',
  'UNAUTHORIZED': 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.',
  'NOT_FOUND': 'العنصر المطلوب غير موجود.',
  'FORBIDDEN': 'لا تملك صلاحية تنفيذ هذا الإجراء.',
  'VALIDATION_ERROR': 'البيانات المُدخلة غير صالحة.',
  'SERVER_ERROR': 'حدث خطأ في الخادم.',
  'ADMIN_ONLY': 'هذه الصفحة متاحة للمشرفين فقط.',
  'USER_NOT_FOUND': 'المستخدم غير موجود.',
  'SELF': 'لا يمكنك متابعة نفسك.',
  'OWNER': 'لا يمكن لمالك المجموعة مغادرتها.',
  'EMPTY_COMMENT': 'لا يمكن إرسال محتوى فارغ.',
  'COMMENTS_DISABLED': 'التعليقات متوقفة لهذا المحتوى.',
  'REPOST_DISABLED': 'إعادة النشر متوقفة لهذا المحتوى.',
  'REPLIES_DISABLED': 'الردود على هذه الستوري متوقفة.',
  'NO_FILE': 'لم يتم اختيار ملف.',
  'UPLOAD_FAILED': 'فشل رفع الملف.',
  'STORAGE_NOT_CONFIGURED': 'تخزين الوسائط غير مُعد على الخادم. يجب إعداد Cloudinary في Render.',
  'MEDIA_NORMALIZATION_FAILED': 'تعذر تجهيز الفيديو أو الصوت للتشغيل.',
  'MEDIA_MIX_FAILED': 'تعذر دمج صوت الفيديو مع الموسيقى. حاول مرة أخرى.',
  'UNSUPPORTED_MEDIA': 'نوع الملف غير مدعوم.',
  'LIVEKIT_NOT_CONFIGURED': 'البث المباشر غير مُعد بعد على الخادم.',
  'PACKAGE_NOT_FOUND': 'باقة العملات غير موجودة.',
  'PURCHASE_NOT_FOUND': 'عملية الشراء غير موجودة.',
  'PRODUCT_MISMATCH': 'المنتج لا يطابق عملية الشراء.',
  'IAP_VERIFICATION_NOT_CONFIGURED': 'نظام التحقق من شراء العملات لم يُفعّل على الخادم بعد.',
  'INSUFFICIENT_COINS': 'رصيد NovaCoins غير كافٍ.',
  'INSUFFICIENT_WITHDRAWABLE': 'الرصيد القابل للسحب غير كافٍ.',
  'WITHDRAW_TOO_SMALL': 'مبلغ السحب صغير جدًا.',
  'GIFT_NOT_FOUND': 'الهدية غير موجودة.',
  'SELF_GIFT': 'لا يمكنك إرسال هدية إلى نفسك.',
  'AGE_VERIFICATION_REQUIRED': 'يجب إكمال التحقق من العمر قبل طلب السحب.',
  'WITHDRAWAL_18_PLUS': 'السحب النقدي متاح فقط لمن بلغ السن القانوني (18+).',
  'TRY_AGAIN': 'تعذر تنفيذ العملية الآن، حاول مرة أخرى.',
  'CALL_ALREADY_ACTIVE': 'هناك مكالمة نشطة بالفعل مع هذا المستخدم.',
  'CALL_NOT_FOUND': 'المكالمة غير موجودة أو انتهت.',
  'CALL_ENDED': 'انتهت المكالمة.',
  'MESSAGE_SEND_FAILED': 'تعذر إرسال الرسالة. تحقق من الاتصال بالخادم وحاول مرة أخرى.',
};

class Api {
  /// The ONLY API host the app may talk to. It is fixed at build time via
  /// `--dart-define=API_URL=...`; there is intentionally **no** runtime host
  /// switching and no fallback list, so credentials can never be sent to an
  /// arbitrary or unowned host.
  // Production is deliberately allow-listed. A stale/misconfigured CI
  // variable must never make a release APK point at localhost, a tunnel, or
  // an old staging host. The workflow also injects these exact values.
  static const _productionApiUrl = 'https://hamkei62.onrender.com';
  static const _configuredApiUrl = String.fromEnvironment('API_URL', defaultValue: '');
  static const _configuredSocketUrl = String.fromEnvironment('SOCKET_URL', defaultValue: '');

  static String _safeProductionUrl(String configured) {
    final candidate = configured.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(candidate);
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'hamkei62.onrender.com') {
      return candidate;
    }
    return _productionApiUrl;
  }

  static final String baseUrl = _safeProductionUrl(_configuredApiUrl);
  static final String socketUrl = _safeProductionUrl(_configuredSocketUrl);

  static String? token;
  static Map<String, dynamic>? me;

  /// Secure, encrypted storage for the session token (never SharedPreferences).
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'sn_session_token';

  /// Set by main.dart: called after a 401 so the app can drop to the login
  /// screen instead of leaving the user on a broken authenticated screen.
  static Future<void> Function()? onUnauthorized;

  /// Health probe for hosted deployments. Render's free instance may sleep,
  /// so a single 5-second probe incorrectly showed "تعذر الوصول إلى الخادم"
  /// while the service was simply waking up. Probe with bounded retries and
  /// treat only a confirmed 5xx/unreachable service as unavailable.
  static Future<bool> ping(String root, {Duration timeout = const Duration(seconds: 18)}) async {
    final r = root.trim().replaceAll(RegExp(r'/+$'), '');
    if (r.isEmpty) return false;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$r/api/health'), headers: const {'Accept': 'application/json'})
            .timeout(timeout);
        if (res.statusCode >= 200 && res.statusCode < 500 && res.body.contains('"ok"')) {
          return true;
        }
        if (res.statusCode >= 500 && attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        return false;
      } on TimeoutException {
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      } on SocketException {
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      } on http.ClientException {
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }
    return false;
  }

  static Future<bool> checkServer() =>
      ping(baseUrl, timeout: const Duration(seconds: 18));

  static Future<Map<String, dynamic>> adminConversation(String userId, String peerId, {int limit = 200}) async =>
      Map<String, dynamic>.from(await req('GET', '/api/admin/conversations/$userId/$peerId?limit=$limit'));

  static Future<List<dynamic>> adminAuditLogs({int limit = 50}) async =>
      List<dynamic>.from(await req('GET', '/api/admin/audit-logs?limit=$limit'));

  static Future<void> init() async {
    // One-time migration from the old SharedPreferences token, then delete it.
    try {
      token = await _secure.read(key: _tokenKey);
    } catch (_) {
      token = null;
    }
    if (token == null || token!.isEmpty) {
      try {
        final legacy = await SharedPreferences.getInstance();
        final old = legacy.getString('token');
        if (old != null && old.isNotEmpty) {
          token = old;
          await _secure.write(key: _tokenKey, value: old);
        }
        await legacy.remove('token');
        await legacy.remove('api_url');
      } catch (_) {}
    }
  }

  static Future<void> saveToken(String value) async {
    token = value;
    try {
      await _secure.write(key: _tokenKey, value: value);
    } catch (_) {}
  }

  static Future<void> logout() async {
    token = null;
    me = null;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('token');
    } catch (_) {}
  }

  /// Multipart upload with the same wake-up/retry protection as JSON requests.
  /// This prevents the "ClientConnection closed while receiving data" error
  /// when a hosted backend is waking up or a mobile network briefly changes.
  static Future<Map<String, dynamic>> uploadMedia(String path, {String field = 'file', String? kind}) async {
    if (token == null) throw Exception('UNAUTHORIZED');
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final uri = Uri.parse('$baseUrl/api/upload');
        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token';
        if (kind != null) request.fields['mediaKind'] = kind;
        request.files.add(await http.MultipartFile.fromPath(field, path));
        final streamed = await request.send().timeout(const Duration(seconds: 300));
        final text = await streamed.stream.bytesToString();
        if (streamed.statusCode == 502 || streamed.statusCode == 503 || streamed.statusCode == 504) {
          if (attempt < maxAttempts) {
            await Future<void>.delayed(Duration(seconds: attempt * 2));
            continue;
          }
        }
        if (streamed.statusCode >= 400) {
          dynamic decoded;
          try { decoded = jsonDecode(text); } catch (_) {}
          final code = decoded is Map && decoded['error'] != null
              ? decoded['error'].toString()
              : 'UPLOAD_FAILED';
          throw Exception(apiMessages[code] ?? code);
        }
        return Map<String, dynamic>.from(jsonDecode(text) as Map);
      } on TimeoutException {
      } on SocketException {
      } on http.ClientException {
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 3));
      }
    }
    throw Exception('تعذّر رفع الملف. تحقق من الخادم والاتصال ثم حاول مرة أخرى.');
  }

  /// Retries automatically: Render's free tier answers 502/503/504 for a few
  /// seconds while the container wakes up from sleep, which used to surface as
  /// the "فشل الطلب (HTTP 502)" screen the user saw.
  static final math.Random _rand = math.Random.secure();
  static String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<dynamic> req(String method, String path, {Map<String, dynamic>? body}) async {
    const maxAttempts = 3;
    // One key per logical call: retries reuse it, so a wake-up retry can never
    // execute the same mutation twice on the server.
    final idemKey = _newIdempotencyKey();
    final isMutation = method.toUpperCase() != 'GET';
    for (var attempt = 1; ; attempt++) {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Device-ID': await DeviceIdentity.get(),
        if (isMutation) 'Idempotency-Key': idemKey,
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse('$baseUrl$path');
      const timeout = Duration(seconds: 12);
      late http.Response response;
      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: headers).timeout(timeout);
          case 'PATCH':
            response = await http
                .patch(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
                .timeout(timeout);
          case 'PUT':
            response = await http
                .put(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
                .timeout(timeout);
          case 'DELETE':
            response = await http.delete(uri, headers: headers).timeout(timeout);
          default:
            response = await http
                .post(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{}))
                .timeout(timeout);
        }
      } on TimeoutException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        throw Exception('انتهت مهلة الاتصال بالخادم. تحقق من الشبكة.');
      } on SocketException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        throw Exception('تعذّر الوصول إلى الخدمة. تحقق من الاتصال ثم حاول مرة أخرى.');
      } on http.ClientException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        throw Exception('فشل الاتصال بالخدمة. تحقق من الاتصال ثم حاول مرة أخرى.');
      }

      // Gateway hiccup while the service wakes up -> wait and try again.
      if ((response.statusCode == 502 ||
              response.statusCode == 503 ||
              response.statusCode == 504) &&
          attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 4));
        continue;
      }

      // Expired/invalid session: clear the token and let the app return to
      // login instead of leaving the user on authenticated screens with a token
      // the server no longer accepts.
      if (response.statusCode == 401) {
        await logout();
        final cb = onUnauthorized;
        if (cb != null) {
          try { await cb(); } catch (_) {}
        }
      }

      if (response.statusCode >= 400) {
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}
        var code =
            decoded is Map && decoded['error'] != null ? decoded['error'].toString() : '';
        if (code.isEmpty) {
          switch (response.statusCode) {
            case 502:
            case 503:
            case 504:
              code = 'الخادم يستيقظ حاليًا. اضغط إعادة المحاولة بعد لحظات ⏳';
              break;
            case 404:
              code = 'الخادم غير متاح على هذا المسار (404).';
              break;
            case 401:
              code = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.';
              break;
            default:
              code = 'تعذّر الاتصال بالخادم (HTTP ${response.statusCode}). اضغط إعادة المحاولة.';
          }
        }
        throw Exception(apiMessages[code] ?? code);
      }
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body);
    }
  }

  static Future<dynamic> request(String method, String path, {Map<String, dynamic>? body}) =>
      req(method, path, body: body);

  // ---------------- auth ----------------
  static Future<Map<String, dynamic>> login(String login, String password) async {
    final x = await req('POST', '/api/auth/login', body: {'login': login, 'password': password, 'deviceId': await DeviceIdentity.get()});
    await saveToken(x['token'].toString());
    me = Map<String, dynamic>.from(x['user'] as Map);
    return me!;
  }

  static Future<Map<String, dynamic>> register(
      String username, String email, String password, String displayName) async {
    final x = await req('POST', '/api/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
      'displayName': displayName,
      'deviceId': await DeviceIdentity.get(),
    });
    await saveToken(x['token'].toString());
    me = Map<String, dynamic>.from(x['user'] as Map);
    return me!;
  }

  static Future<Map<String, dynamic>> me$() async {
    final r = await req('GET', '/api/me');
    final u = r is Map && r['user'] is Map ? r['user'] : r;
    me = Map<String, dynamic>.from(u as Map);
    return me!;
  }

  // ---------------- content ----------------
  static Future<List<dynamic>> feed() async => List<dynamic>.from(await req('GET', '/api/feed'));
  static Future<List<dynamic>> reels() async => List<dynamic>.from(await req('GET', '/api/reels'));
  static Future<List<dynamic>> repostedReels() async => List<dynamic>.from(await req('GET', '/api/reels/reposted'));
  static Future<List<dynamic>> followingReels() async => List<dynamic>.from(await req('GET', '/api/reels/following'));
  static Future<List<dynamic>> stories() async => List<dynamic>.from(await req('GET', '/api/stories'));
  static Future<List<dynamic>> music({String search = '', String category = ''}) async {
    final q = <String>[];
    if (search.trim().isNotEmpty) q.add('search=${Uri.encodeQueryComponent(search.trim())}');
    if (category.trim().isNotEmpty) q.add('category=${Uri.encodeQueryComponent(category.trim())}');
    return List<dynamic>.from(await req('GET', '/api/music${q.isEmpty ? '' : '?${q.join('&')}'}'));
  }
  static Future<List<dynamic>> live() async => List<dynamic>.from(await req('GET', '/api/live'));
  static Future<Map<String,dynamic>> adminStartLive(String title) async => Map<String,dynamic>.from(await req('POST','/api/live',body:{'title':title}));
  static Future<List<dynamic>> creatorLevels() async => List<dynamic>.from(await req('GET', '/api/creator/levels'));
  static Future<Map<String, dynamic>> creatorMilestones() async => Map<String, dynamic>.from(await req('GET', '/api/creator/milestones/me'));
  static Future<List<dynamic>> continueWatching() async => List<dynamic>.from(await req('GET', '/api/continue-watching'));
  static Future<void> saveProgress({required String kind, required String contentId, String episodeId = '', required int positionSec, int durationSec = 0, bool completed = false}) async =>
      req('PUT', '/api/continue-watching', body: {'kind': kind, 'contentId': contentId, 'episodeId': episodeId, 'positionSec': positionSec, 'durationSec': durationSec, 'completed': completed});
  static Future<List<dynamic>> adminUsers({String q = ''}) async => List<dynamic>.from(await req('GET', '/api/admin/users${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}'));
  static Future<List<dynamic>> assets({String type = ''}) async => List<dynamic>.from(await req('GET', '/api/assets${type.isEmpty ? '' : '?type=$type'}'));
  static Future<Map<String,dynamic>> adminAddFollowers(String userId, int delta) async => Map<String,dynamic>.from(await req('POST', '/api/admin/users/$userId/followers', body: {'delta': delta}));
  static Future<Map<String,dynamic>> adminBoostContent(String kind, String id, {int viewers = 0, int likes = 0, int taps = 0}) async => Map<String,dynamic>.from(await req('POST', '/api/admin/content/$kind/$id/boost', body: {'viewers': viewers, 'likes': likes, 'taps': taps}));
  static Future<Map<String,dynamic>> achievements() async => Map<String,dynamic>.from(await req('GET','/api/achievements'));
  static Future<List<dynamic>> adminComments({String kind='ALL'}) async => List<dynamic>.from(await req('GET','/api/admin/comments?kind=${Uri.encodeQueryComponent(kind)}'));
  static Future<Map<String,dynamic>> adminBoostCommentHearts(String kind, String id, int hearts) async => Map<String,dynamic>.from(await req('POST','/api/admin/comments/$kind/$id/boost',body:{'hearts':hearts}));
  static Future<Map<String,dynamic>> adminPublishMedia(String kind, String url, {String mediaType = 'VIDEO', String caption = '', String title = '', int durationHours = 24}) async => Map<String,dynamic>.from(await req('POST', '/api/admin/publish-media', body: {'kind': kind, 'url': url, 'mediaType': mediaType, 'caption': caption, 'title': title, 'durationHours': durationHours}));
  static Future<List<dynamic>> groups() async => List<dynamic>.from(await req('GET', '/api/groups'));
  static Future<List<dynamic>> myGroups() async => List<dynamic>.from(await req('GET', '/api/me/groups'));
  static Future<List<dynamic>> notifications() async =>
      List<dynamic>.from(await req('GET', '/api/notifications'));
  static Future<void> readNotifications() async => req('POST', '/api/notifications/read');
  static Future<List<dynamic>> searchUsers(String q) async =>
      List<dynamic>.from(await req('GET', '/api/users/search?q=${Uri.encodeQueryComponent(q)}'));
  static Future<List<dynamic>> suggestedUsers() async =>
      List<dynamic>.from(await req('GET', '/api/users/suggested'));
  static Future<Map<String, dynamic>> globalSearch(String q) async =>
      Map<String, dynamic>.from(await req('GET', '/api/search?q=${Uri.encodeQueryComponent(q.trim())}'));

  static Future<Map<String, dynamic>> like(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/like'));
  static Future<Map<String, dynamic>> bookmark(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/bookmark'));
  static Future<Map<String, dynamic>> repost(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/repost'));
  static Future<Map<String, dynamic>> sharePost(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/share'));
  static Future<void> viewPost(String id) async => req('POST', '/api/posts/$id/view');
  static Future<Map<String,dynamic>> comment(String id, String body, {String? parentId}) async => Map<String,dynamic>.from(await req('POST', '/api/posts/$id/comments', body: {'body': body, if (parentId != null) 'parentId': parentId}));
  static Future<List<dynamic>> postComments(String id) async => List<dynamic>.from(await req('GET','/api/posts/$id/comments'));
  static Future<Map<String,dynamic>> likeComment(String id) async => Map<String,dynamic>.from(await req('POST','/api/posts/comments/$id/like'));
  static Future<void> deletePost(String id) async => req('DELETE', '/api/posts/$id');
  static Future<void> editComment(String id, String body) async => req('PATCH','/api/posts/comments/$id',body:{'body':body});
  static Future<void> deleteComment(String id) async => req('DELETE','/api/posts/comments/$id');
  static Future<void> editReelComment(String id, String body) async => req('PATCH','/api/reels/comments/$id',body:{'body':body});
  static Future<void> deleteReelComment(String id) async => req('DELETE','/api/reels/comments/$id');
  static Future<List<dynamic>> userSavedPosts(String id) async => List<dynamic>.from(await req('GET','/api/users/$id/saved'));
  static Future<List<dynamic>> userLikedPosts(String id) async => List<dynamic>.from(await req('GET','/api/users/$id/liked'));
  static Future<void> deleteMessage(String id,{bool forEveryone=false}) async => req('PATCH','/api/messages/$id/delete',body:{'forEveryone':forEveryone});

  static Future<void> post(String caption,
      {String media = '', String type = 'TEXT', String music = '', String visibility = 'PUBLIC', String title = '', int rotationDegrees = 0, String overlayText = '', String overlayEmoji = '', String overlayImageUrl = '', bool commentsEnabled = true, bool repostEnabled = true, bool pinned = false, bool archived = false, String? scheduledAt}) async {
    await req('POST', '/api/posts', body: {
      'caption': caption, 'mediaUrl': media, 'type': type, 'musicTitle': music,
      'visibility': visibility, 'title': title, 'rotationDegrees': rotationDegrees, 'commentsEnabled': commentsEnabled, 'repostEnabled': repostEnabled, 'pinned': pinned, 'archived': archived, 'scheduledAt': scheduledAt,
      'overlayText': overlayText, 'overlayEmoji': overlayEmoji, 'overlayImageUrl': overlayImageUrl,
    });
  }

  static Future<void> updatePost(String id, Map<String, dynamic> data) async =>
      req('PATCH', '/api/posts/$id', body: data);

  static Future<void> createReel(String videoUrl, String caption, String music, {String musicUrl = '', String title = '', int rotationDegrees = 0, String overlayText = '', String overlayEmoji = '', String overlayImageUrl = '', bool commentsEnabled = true, bool repostEnabled = true, bool archived = false, String? scheduledAt}) async =>
      req('POST', '/api/reels', body: {
        'videoUrl': videoUrl, 'caption': caption, 'musicUrl': musicUrl, 'musicTitle': music, 'title': title,
        'rotationDegrees': rotationDegrees, 'overlayText': overlayText, 'overlayEmoji': overlayEmoji, 'overlayImageUrl': overlayImageUrl, 'commentsEnabled': commentsEnabled, 'repostEnabled': repostEnabled, 'archived': archived, 'scheduledAt': scheduledAt,
      });

  static Future<void> updateReel(String id, Map<String, dynamic> data) async =>
      req('PATCH', '/api/reels/$id', body: data);
  static Future<void> deleteReel(String id) async => req('DELETE', '/api/reels/$id');
  static Future<Map<String,dynamic>> contentAnalytics(String type, String id) async =>
      Map<String,dynamic>.from(await req('GET', '/api/content/$type/$id/analytics'));
  static Future<List<dynamic>> archivedContent(String type) async =>
      List<dynamic>.from(await req('GET', '/api/content/$type/archived'));

  static Future<Map<String,dynamic>> likeReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/like'));
  static Future<List<dynamic>> reelComments(String id) async => List<dynamic>.from(await req('GET','/api/reels/$id/comments'));
  static Future<Map<String,dynamic>> commentReel(String id,String body,{String? parentId}) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/comments',body:{'body':body, if(parentId!=null)'parentId':parentId}));
  static Future<Map<String,dynamic>> likeReelComment(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/comments/$id/like'));
  static Future<Map<String,dynamic>> shareReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/share'));
  static Future<Map<String,dynamic>> repostReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/repost'));
  static Future<Map<String,dynamic>> bookmarkReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/bookmark'));
  static Future<Map<String,dynamic>> reelFeedback(String id,String kind,{String reason=''}) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/feedback',body:{'kind':kind,'reason':reason}));
  static Future<void> reportReel(String id,String reason) async => req('POST','/api/reels/$id/report',body:{'reason':reason});
  static Future<void> reportPost(String id,String reason) async => req('POST','/api/posts/$id/report',body:{'reason':reason});
  static Future<void> reportLiveComment(String id,String reason) async => req('POST','/api/live/comments/$id/report',body:{'reason':reason});
  static Future<Map<String,dynamic>> addReelToStory(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/add-to-story'));
  static Future<void> viewReel(String id) async => req('POST', '/api/reels/$id/view');
  static Future<void> createStory(String mediaUrl, String type, String caption, {int rotationDegrees = 0, String overlayText = '', String overlayEmoji = '', String overlayImageUrl = '', String musicUrl = '', String musicTitle = '', int durationHours = 24, String audienceMode = 'EVERYONE', List<String> hiddenUserIds = const [], bool replyEnabled = true, bool archived = false, String? scheduledAt, int autoHideViews = 0, bool autoHideAfterInteraction = false}) async =>
      req('POST', '/api/stories', body: {'mediaUrl': mediaUrl, 'type': type, 'caption': caption, 'durationHours': durationHours, 'audienceMode': audienceMode, 'hiddenUserIds': hiddenUserIds, 'rotationDegrees': rotationDegrees, 'overlayText': overlayText, 'overlayEmoji': overlayEmoji, 'overlayImageUrl': overlayImageUrl, 'musicUrl': musicUrl, 'musicTitle': musicTitle, 'replyEnabled': replyEnabled, 'archived': archived, 'scheduledAt': scheduledAt, 'autoHideViews': autoHideViews, 'autoHideAfterInteraction': autoHideAfterInteraction});
  static Future<Map<String, dynamic>> mixMedia(String videoUrl, String musicUrl) async => Map<String, dynamic>.from(await req('POST', '/api/media/mix', body: {'videoUrl': videoUrl, 'musicUrl': musicUrl}));
  static Future<void> updateStory(String id, Map<String, dynamic> data) async => req('PATCH', '/api/stories/$id', body: data);
  static Future<void> deleteStory(String id) async => req('DELETE', '/api/stories/$id');
  static Future<void> viewStory(String id) async => req('POST', '/api/stories/$id/view');
  static Future<Map<String, dynamic>> reactStory(String id) async => Map<String, dynamic>.from(await req('POST', '/api/stories/$id/react'));
  static Future<Map<String, dynamic>> replyToStory(String id, String body) async => Map<String, dynamic>.from(await req('POST', '/api/stories/$id/replies', body: {'body': body}));
  static Future<List<dynamic>> storyReplies(String id) async => List<dynamic>.from(await req('GET', '/api/stories/$id/replies'));

  // ---------------- social graph ----------------
  static Future<Map<String, dynamic>> profile(String id) async =>
      Map<String, dynamic>.from(await req('GET', '/api/users/$id/profile'));
  static Future<Map<String,dynamic>> managedProfileAction(String id, String action, Map<String,dynamic> body) async => Map<String,dynamic>.from(await req('POST','/api/admin/managed-users/$id/action',body:{'action':action,...body}));

  // ---- In-app moderation (works once a staff permission is granted) ----
  /// Effective permissions as resolved by the server (role defaults + grants),
  /// exposed on /api/me. Falls back to the raw grants for older servers.
  static List<String> get permissions {
    final effective = me?['permissions'];
    if (effective is List && effective.isNotEmpty) return effective.map((e) => '$e').toList();
    final raw = me?['adminPermissions'];
    if (raw is List) return raw.map((e) => '$e').toList();
    if (raw is String && raw.isNotEmpty) return raw.split(',');
    return const <String>[];
  }
  static bool get isDeveloper => '${me?['role'] ?? ''}' == 'DEVELOPER';
  static bool get isSuperAdmin => '${me?['role'] ?? ''}' == 'SUPER_ADMIN';
  static bool can(String permission) => isSuperAdmin || permissions.contains('*') || permissions.contains(permission);

  static Future<void> logoutAllDevices() async => req('POST', '/api/auth/logout-all');

  static Future<void> adminDeletePost(String id) async => req('DELETE', '/api/admin/posts/$id');
  static Future<void> adminDeleteComment(String id) async => req('DELETE', '/api/admin/comments/$id');
  static Future<void> adminStopLive(String id) async => req('PATCH', '/api/admin/live/$id/stop');
  static Future<Map<String, dynamic>> adminUpdateUser(String id, Map<String, dynamic> body) async => Map<String, dynamic>.from(await req('PATCH', '/api/admin/users/$id', body: body));
  static Future<Map<String, dynamic>> adminSetDeactivated(String id, bool deactivated) async => Map<String, dynamic>.from(await req('PATCH', '/api/admin/users/$id/deactivate', body: {'deactivated': deactivated}));
  static Future<Map<String, dynamic>> closeMyAccount() async => Map<String, dynamic>.from(await req('POST', '/api/account/close', body: const {}));
  static Future<Map<String, dynamic>> reactivateMyAccount() async => Map<String, dynamic>.from(await req('POST', '/api/account/reactivate', body: const {}));
  static Future<Map<String,dynamic>> adminProfileEffects(String id) async => Map<String,dynamic>.from(await req('GET','/api/admin/users/$id/profile-effects'));
  static Future<Map<String,dynamic>> updateAdminProfileEffects(String id, Map<String,dynamic> body) async => Map<String,dynamic>.from(await req('PATCH','/api/admin/users/$id/profile-effects',body:body));
  static Future<Map<String,dynamic>> relationshipCurrent() async => Map<String,dynamic>.from(await req('GET','/api/relationships/current'));
  static Future<List<dynamic>> relationshipRequests() async => List<dynamic>.from(await req('GET','/api/relationships/requests'));
  static Future<Map<String,dynamic>> createRelationship(String type, String partnerId, {DateTime? since}) async => Map<String,dynamic>.from(await req('POST','/api/relationships',body:{'type':type,'partnerId':partnerId,'since':since?.toUtc().toIso8601String()}));
  static Future<void> acceptRelationship(String id) async => req('POST','/api/relationships/$id/accept');
  static Future<void> rejectRelationship(String id) async => req('POST','/api/relationships/$id/reject');
  static Future<void> endRelationship() async => req('DELETE','/api/relationships/current');
  static Future<Map<String,dynamic>> setRelationshipStatus(String type, {DateTime? since}) async => Map<String,dynamic>.from(await req('PATCH','/api/relationships/status',body:{'type':type,'since':since?.toUtc().toIso8601String()}));
  static Future<List<dynamic>> userPosts(String id) async =>
      List<dynamic>.from(await req('GET', '/api/users/$id/posts'));
  static Future<List<dynamic>> userRepostedReels(String id) async =>
      List<dynamic>.from(await req('GET', '/api/users/$id/reposted-reels'));
  static Future<List<dynamic>> followers(String id) async =>
      List<dynamic>.from(await req('GET', '/api/users/$id/followers'));
  static Future<List<dynamic>> following(String id) async =>
      List<dynamic>.from(await req('GET', '/api/users/$id/following'));
  static Future<Map<String,dynamic>> follow(String id) async => Map<String,dynamic>.from(await req('POST', '/api/users/$id/follow'));
  static Future<List<dynamic>> followRequests() async => List<dynamic>.from(await req('GET','/api/follow-requests'));
  static Future<void> acceptFollowRequest(String id) async => req('POST','/api/follow-requests/$id/accept');
  static Future<void> rejectFollowRequest(String id) async => req('POST','/api/follow-requests/$id/reject');
  static Future<List<dynamic>> messageRequests() async => List<dynamic>.from(await req('GET','/api/message-requests'));
  static Future<void> acceptMessageRequest(String id) async => req('POST','/api/message-requests/$id/accept');
  static Future<void> rejectMessageRequest(String id) async => req('POST','/api/message-requests/$id/reject');
  static Future<List<dynamic>> userReelsLiked(String id) async => List<dynamic>.from(await req('GET','/api/users/$id/reels-liked'));
  static Future<List<dynamic>> userReelsSaved(String id) async => List<dynamic>.from(await req('GET','/api/users/$id/reels-saved'));
  static Future<List<dynamic>> userReels(String id) async => List<dynamic>.from(await req('GET','/api/users/$id/reels'));
  static Future<List<dynamic>> userStories(String id) async => List<dynamic>.from(await req('GET','/api/users/$id/stories'));
  static Future<Map<String,dynamic>> activity() async => Map<String,dynamic>.from(await req('GET','/api/activity'));

  static Future<Map<String, dynamic>> digitalCard() async => Map<String, dynamic>.from(await req('GET', '/api/me/digital-card'));
  static Future<void> updateMe(Map<String, dynamic> data) async {
    final r = await req('PATCH', '/api/me', body: data);
    if (r is Map && r['user'] is Map) me = Map<String, dynamic>.from(r['user'] as Map);
  }

  static Future<void> updateSettings(Map<String, dynamic> data) async {
    final r = await req('PATCH', '/api/settings', body: data);
    if (r is Map && r['user'] is Map) me = Map<String, dynamic>.from(r['user'] as Map);
  }

  // ---------------- verification ----------------
  static Future<Map<String, dynamic>> verificationMe() async =>
      Map<String, dynamic>.from(await req('GET', '/api/verification/me'));
  static Future<Map<String, dynamic>> requestVerification(String tier) async =>
      Map<String, dynamic>.from(await req('POST', '/api/verification/request', body: {'tier': tier}));
  static Future<Map<String, dynamic>> confirmVerification(String id) async =>
      Map<String, dynamic>.from(await req('POST', '/api/verification/$id/confirm'));
  static Future<List<dynamic>> verificationRequests() async =>
      List<dynamic>.from(await req('GET', '/api/verification/requests'));

  // ---------------- messaging ----------------
  static Future<List<dynamic>> conversations() async =>
      List<dynamic>.from(await req('GET', '/api/conversations'));
  static Future<List<dynamic>> messages(String userId) async =>
      List<dynamic>.from(await req('GET', '/api/messages/$userId'));
  static Future<Map<String, dynamic>> sendMessage(String userId, String body, {bool secret = false, bool selfDestruct = false, int ttlMinutes = 60, int viewLimit = 0, String effect = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/messages/$userId', body: {'body': body, 'secret': secret, 'selfDestruct': selfDestruct, 'ttlMinutes': ttlMinutes, 'viewLimit': viewLimit, if (effect.isNotEmpty) 'effect': effect}));
  static Future<void> viewMessage(String id) async => req('POST','/api/messages/$id/view');
  static Future<Map<String,dynamic>> chatTheme(String userId) async => Map<String,dynamic>.from(await req('GET','/api/chat/$userId/theme'));
  static Future<void> savePushToken(String token) async => req('POST','/api/push/token',body:{'token':token});
  static Future<void> markMessageDelivered(String id) async => req('POST','/api/messages/$id/delivered');
  static Future<void> markMessageRead(String id) async => req('POST','/api/messages/$id/read');
  static Future<Map<String, dynamic>> reactToMessage(String messageId, String emoji) async =>
      Map<String, dynamic>.from(await req('POST', '/api/messages/$messageId/reaction', body: {'emoji': emoji}));
  static Future<List<dynamic>> messageReactions(String messageId) async =>
      List<dynamic>.from(await req('GET', '/api/messages/$messageId/reactions'));
  static Future<Map<String,dynamic>> saveChatTheme(String userId, {required String background, String bubbleStyle='glass', String accent='violet'}) async => Map<String,dynamic>.from(await req('PUT','/api/chat/$userId/theme', body:{'background':background,'bubbleStyle':bubbleStyle,'accent':accent}));
  static Future<Map<String,dynamic>> socialHub() async => Map<String,dynamic>.from(await req('GET','/api/hub'));
  static Future<List<dynamic>> movies({String q=''}) async => List<dynamic>.from(await req('GET','/api/movies${q.isEmpty?'':'?q=${Uri.encodeQueryComponent(q)}'}'));
  static Future<List<dynamic>> series({String q=''}) async => List<dynamic>.from(await req('GET','/api/series${q.isEmpty?'':'?q=${Uri.encodeQueryComponent(q)}'}'));
  static Future<Map<String,dynamic>> movie(String id) async => Map<String,dynamic>.from(await req('GET','/api/movies/$id'));
  static Future<Map<String,dynamic>> seriesOne(String id) async => Map<String,dynamic>.from(await req('GET','/api/series/$id'));
  static Future<Map<String,dynamic>> episode(String id) async => Map<String,dynamic>.from(await req('GET','/api/episodes/$id'));
  static Future<Map<String,dynamic>> contentAccess(String kind,String id) async => Map<String,dynamic>.from(await req('GET','/api/content/${kind.toUpperCase()}/$id/access'));
  static Future<Map<String,dynamic>> contentView(String kind,String id) async => Map<String,dynamic>.from(await req('POST','/api/content/${kind.toUpperCase()}/$id/view'));
  static Future<List<dynamic>> audioRooms() async => List<dynamic>.from(await req('GET','/api/audio-rooms'));
  static Future<List<dynamic>> creatorTeams() async => List<dynamic>.from(await req('GET','/api/creator/teams'));
  static Future<Map<String,dynamic>> creatorStudio() async => Map<String,dynamic>.from(await req('GET','/api/creator/studio'));
  static Future<List<dynamic>> battles() async => List<dynamic>.from(await req('GET','/api/battles'));
  static Future<List<dynamic>> academy() async => List<dynamic>.from(await req('GET','/api/academy'));
  static Future<List<dynamic>> hallOfFame() async => List<dynamic>.from(await req('GET','/api/hall-of-fame'));
  static Future<Map<String,dynamic>> creatorCoach(String goal,{String prompt=''}) async => Map<String,dynamic>.from(await req('POST','/api/ai/creator-coach',body:{'goal':goal,'prompt':prompt}));

  // ---------------- groups ----------------
  static Future<void> createGroup(String name, String desc, {String avatarUrl = '', String coverUrl = '', String privacy = 'PUBLIC', String rules = '', String joinMode = 'DIRECT', String messageMode = 'MEMBERS', String addMemberMode = 'ADMINS'}) async =>
      req('POST', '/api/groups', body: {'name': name, 'description': desc, 'avatarUrl': avatarUrl, 'coverUrl': coverUrl, 'privacy': privacy, 'rules': rules, 'joinMode': joinMode, 'messageMode': messageMode, 'addMemberMode': addMemberMode});
  static Future<void> updateGroup(String id, String name, String desc, {String? privacy, String? rules, String? joinMode, String? messageMode, String? addMemberMode}) async =>
      req('PATCH', '/api/groups/$id', body: {'name': name, 'description': desc, if (privacy != null) 'privacy': privacy, if (rules != null) 'rules': rules, if (joinMode != null) 'joinMode': joinMode, if (messageMode != null) 'messageMode': messageMode, if (addMemberMode != null) 'addMemberMode': addMemberMode});
  static Future<Map<String,dynamic>> joinGroup(String id) async => Map<String,dynamic>.from(await req('POST', '/api/groups/$id/join'));
  static Future<Map<String, dynamic>> group(String id) async => Map<String, dynamic>.from(await req('GET', '/api/groups/$id'));
  static Future<List<dynamic>> groupMembers(String id) async => List<dynamic>.from(await req('GET', '/api/groups/$id/members'));
  static Future<List<dynamic>> groupJoinRequests(String id) async => List<dynamic>.from(await req('GET', '/api/groups/$id/join-requests'));
  static Future<void> decideGroupJoinRequest(String id,String requestId,String status) async => req('PATCH','/api/groups/$id/join-requests/$requestId',body:{'status':status});
  static Future<void> setGroupMemberRole(String id,String userId,String role) async => req('PATCH','/api/groups/$id/members/$userId',body:{'role':role});
  static Future<void> removeGroupMember(String id,String userId) async => req('DELETE','/api/groups/$id/members/$userId');
  static Future<List<dynamic>> groupMessages(String id) async => List<dynamic>.from(await req('GET', '/api/groups/$id/messages'));
  static Future<void> sendGroupMessage(String id, String body) async =>
      req('POST', '/api/groups/$id/messages', body: {'body': body});
  static Future<void> sendGroupMediaMessage(String id, String mediaUrl, String kind) async =>
      req('POST', '/api/groups/$id/messages', body: {'body': '[${kind}]$mediaUrl'});

  // ---------------- live ----------------
  static Future<Map<String, dynamic>> createLive(String title) async =>
      Map<String, dynamic>.from(await req('POST', '/api/live', body: {'title': title}));
  static Future<Map<String, dynamic>> liveToken(String roomName) async =>
      Map<String, dynamic>.from(await req('POST', '/api/live/token', body: {'roomName': roomName}));
  static Future<Map<String, dynamic>> callToken(String roomName) async =>
      Map<String, dynamic>.from(await req('POST', '/api/calls/token', body: {'roomName': roomName}));
  static Future<void> pauseLive(String id) async => req('POST', '/api/live/$id/pause');
  static Future<void> resumeLive(String id) async => req('POST', '/api/live/$id/resume');
  static Future<void> endLive(String id) async => req('POST', '/api/live/$id/end');
  static Future<Map<String, dynamic>> liveStats(String roomName) async =>
      Map<String, dynamic>.from(await req('GET', '/api/live/stats/$roomName'));
  static Future<Map<String, dynamic>> liveTop(String roomName) async =>
      Map<String, dynamic>.from(await req('GET', '/api/live/top/$roomName'));
  static Future<Map<String,dynamic>> createLiveChallenge(String roomName,String opponentId,{String title='جولة تحدي'}) async => Map<String,dynamic>.from(await req('POST','/api/live/challenges',body:{'roomName':roomName,'opponentId':opponentId,'title':title}));
  static Future<Map<String,dynamic>> updateLiveChallenge(String id,{required int scoreA,required int scoreB}) async => Map<String,dynamic>.from(await req('PATCH','/api/live/challenges/$id',body:{'scoreA':scoreA,'scoreB':scoreB}));
  static Future<Map<String,dynamic>> finishLiveChallenge(String id,String winnerId) async => Map<String,dynamic>.from(await req('POST','/api/live/challenges/$id/finish',body:{'winnerId':winnerId}));

  // ---------------- V93 live join requests ----------------
  static Future<Map<String, dynamic>> liveJoinRequests(String roomId) async =>
      Map<String, dynamic>.from(await req('GET', '/api/live/$roomId/join-requests'));
  static Future<Map<String, dynamic>> requestJoinLive(String roomId, {String message = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/live/$roomId/join-requests', body: {'message': message}));
  static Future<Map<String, dynamic>> decideJoinRequest(String roomId, String requestId, String status) async =>
      Map<String, dynamic>.from(await req('PATCH', '/api/live/$roomId/join-requests/$requestId', body: {'status': status}));

  // ---------------- V93 admin console ----------------
  static Future<Map<String, dynamic>> adminGifts({String q = ''}) async =>
      Map<String, dynamic>.from(await req('GET', '/api/admin/gifts${q.isEmpty ? '' : '?q=$q'}'));
  static Future<Map<String, dynamic>> createGift(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/admin/gifts', body: body));
  static Future<Map<String, dynamic>> updateGift(String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('PATCH', '/api/admin/gifts/$id', body: body));
  static Future<void> disableGift(String id) async => req('DELETE', '/api/admin/gifts/$id');

  static Future<List<dynamic>> adminAssets({String type = ''}) async =>
      List<dynamic>.from(await req('GET', '/api/admin/assets${type.isEmpty ? '' : '?type=$type'}'));
  static Future<Map<String, dynamic>> createAsset(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/admin/assets', body: body));
  static Future<Map<String, dynamic>> updateAsset(String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('PATCH', '/api/admin/assets/$id', body: body));
  static Future<void> deleteAsset(String id) async => req('DELETE', '/api/admin/assets/$id');

  static Future<List<dynamic>> adminMilestones() async =>
      List<dynamic>.from(await req('GET', '/api/creator/milestones'));
  static Future<Map<String, dynamic>> saveMilestones(List<Map<String, dynamic>> milestones) async =>
      Map<String, dynamic>.from(await req('PUT', '/api/admin/creator-milestones', body: {'milestones': milestones}));
  static Future<List<dynamic>> adminCreatorLevels() async =>
      List<dynamic>.from(await req('GET', '/api/creator/levels'));
  static Future<Map<String, dynamic>> saveCreatorLevels(List<Map<String, dynamic>> levels) async =>
      Map<String, dynamic>.from(await req('PUT', '/api/admin/creator-levels', body: {'levels': levels}));

  static Future<Map<String, dynamic>> adminContentTree() async =>
      Map<String, dynamic>.from(await req('GET', '/api/admin/content-tree'));
  static Future<Map<String, dynamic>> saveMovie(Map<String, dynamic> body, {String id = ''}) async =>
      id.isEmpty
          ? Map<String, dynamic>.from(await req('POST', '/api/admin/movies', body: body))
          : Map<String, dynamic>.from(await req('PATCH', '/api/admin/movies/$id', body: body));
  static Future<void> archiveMovie(String id) async => req('DELETE', '/api/admin/movies/$id');
  static Future<Map<String, dynamic>> saveSeries(Map<String, dynamic> body, {String id = ''}) async =>
      id.isEmpty
          ? Map<String, dynamic>.from(await req('POST', '/api/admin/series', body: body))
          : Map<String, dynamic>.from(await req('PATCH', '/api/admin/series/$id', body: body));
  static Future<void> archiveSeries(String id) async => req('DELETE', '/api/admin/series/$id');
  static Future<Map<String, dynamic>> saveSeason(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/admin/seasons', body: body));
  static Future<void> deleteSeason(String id) async => req('DELETE', '/api/admin/seasons/$id');
  static Future<Map<String, dynamic>> saveEpisode(Map<String, dynamic> body, {String id = ''}) async =>
      id.isEmpty
          ? Map<String, dynamic>.from(await req('POST', '/api/admin/episodes', body: body))
          : Map<String, dynamic>.from(await req('PATCH', '/api/admin/episodes/$id', body: body));
  static Future<void> archiveEpisode(String id) async => req('DELETE', '/api/admin/episodes/$id');
  static Future<Map<String, dynamic>> creatorContent() async =>
      Map<String, dynamic>.from(await req('GET', '/api/creator/content'));
  static Future<Map<String, dynamic>> creatorSubscriptionPlan({String creatorId = ''}) async =>
      Map<String, dynamic>.from(await req('GET', creatorId.isEmpty ? '/api/creator/subscription-plan' : '/api/creator/subscription-plan/$creatorId'));
  static Future<Map<String, dynamic>?> saveCreatorSubscriptionPlan(Map<String, dynamic> body) async {
    final r = await req('PUT', '/api/creator/subscription-plan', body: body);
    if (r == null) return null;
    return Map<String, dynamic>.from(r as Map);
  }
  static Future<Map<String, dynamic>> createCreatorMovie(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/creator/movies', body: body));
  static Future<Map<String, dynamic>> createCreatorSeries(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/creator/series', body: body));
  static Future<Map<String, dynamic>> createCreatorSeason(String seriesId, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/creator/series/$seriesId/seasons', body: body));
  static Future<Map<String, dynamic>> createCreatorEpisode(String seasonId, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/creator/seasons/$seasonId/episodes', body: body));
  static Future<Map<String, dynamic>> buyCreatorSubscription({required String creatorId, required String productId, required String purchaseToken, String expiresAt = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/content/subscription', body: {
        'creatorId': creatorId, 'productId': productId, 'purchaseToken': purchaseToken,
        if (expiresAt.isNotEmpty) 'expiresAt': expiresAt,
      }));

  /// Uploads a file (poster, backdrop, trailer, video, gift art) and returns
  /// the stored URL. Thin wrapper over the existing uploader.
  static Future<String> uploadAndGetUrl(String filePath, {String kind = 'IMAGE'}) async {
    final res = await uploadMedia(filePath, kind: kind);
    return '${res['url'] ?? ''}';
  }

  // ---------------- V93 calls ----------------
  static Future<Map<String, dynamic>> startCall({required String receiverId, String kind = 'AUDIO'}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/calls/start', body: {'receiverId': receiverId, 'kind': kind}));
  static Future<Map<String, dynamic>> acceptCall(String callId) async =>
      Map<String, dynamic>.from(await req('POST', '/api/calls/$callId/accept'));
  static Future<Map<String, dynamic>> rejectCall(String callId) async =>
      Map<String, dynamic>.from(await req('POST', '/api/calls/$callId/reject'));
  static Future<Map<String, dynamic>> endCall(String callId, {String reason = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/calls/$callId/end', body: {'reason': reason}));
  static Future<List<dynamic>> callHistory({int limit = 50}) async =>
      List<dynamic>.from(await req('GET', '/api/calls/history?limit=$limit'));
  static Future<Map<String, dynamic>> callDetail(String callId) async =>
      Map<String, dynamic>.from(await req('GET', '/api/calls/$callId'));

  // ---------------- V93 gift library / XP ----------------
  static Future<Map<String, dynamic>> giftXp() async =>
      Map<String, dynamic>.from(await req('GET', '/api/gifts/xp'));
  static Future<Map<String, dynamic>> giftCatalog() async =>
      Map<String, dynamic>.from(await req('GET', '/api/gifts/catalog'));
  /// V105: authoritative Unity/GLB gift manifest.
  static Future<Map<String, dynamic>> unityGiftManifest() async =>
      Map<String, dynamic>.from(await req('GET', '/api/gifts/unity-manifest'));

  // ---------------- V93 story views ----------------
  // NOTE: the plain view ping already exists higher up as `viewStory(id)`;
  // it used to call a route that did not exist on the server. V93 adds that
  // route, so the call is now real instead of a silent 404.
  static Future<Map<String, dynamic>> storyViewers(String storyId) async =>
      Map<String, dynamic>.from(await req('GET', '/api/stories/$storyId/viewers'));
  static Future<List<dynamic>> storiesSeen(List<String> ids) async =>
      List<dynamic>.from(await req('GET', '/api/stories/seen?ids=${ids.join(',')}'));

  // ---------------- V93 creator rewards ----------------
  static Future<Map<String, dynamic>> myMilestones() async =>
      Map<String, dynamic>.from(await req('GET', '/api/creator/milestones/me'));
  static Future<List<dynamic>> myMilestoneRewards() async =>
      List<dynamic>.from(await req('GET', '/api/creator/milestones/rewards'));

  // ---------------- NovaCoins wallet ----------------
  static Future<Map<String, dynamic>> wallet() async =>
      Map<String, dynamic>.from(await req('GET', '/api/wallet'));
  static Future<List<dynamic>> gifts() async =>
      List<dynamic>.from(await req('GET', '/api/wallet/gifts'));
  static Future<List<dynamic>> liveComments(String roomId) async => List<dynamic>.from(await req('GET', '/api/live/$roomId/comments'));
  static Future<Map<String,dynamic>> createLiveComment(String roomId, String body, {String replyToId = ''}) async => Map<String,dynamic>.from(await req('POST','/api/live/$roomId/comments',body:{'body':body,'replyToId':replyToId}));
  static Future<List<dynamic>> liveModerators(String roomId) async => List<dynamic>.from(await req('GET','/api/live/$roomId/moderators'));
  static Future<List<dynamic>> liveFollowersForModeration(String roomId) async => List<dynamic>.from(await req('GET','/api/live/$roomId/followers'));
  static Future<Map<String,dynamic>> addLiveModerator(String roomId, String userId, {String role='MODERATOR'}) async => Map<String,dynamic>.from(await req('POST','/api/live/$roomId/moderators',body:{'userId':userId,'role':role}));
  static Future<void> removeLiveModerator(String roomId, String userId) async => req('DELETE','/api/live/$roomId/moderators/$userId');
  static Future<void> pinLiveComment(String roomId, String commentId) async => req('POST','/api/live/$roomId/comments/$commentId/pin');
  static Future<void> deleteLiveComment(String roomId, String commentId) async => req('DELETE','/api/live/$roomId/comments/$commentId');
  static Future<Map<String, dynamic>> purchaseIntent(String productId, String platform, String transactionId) async =>
      Map<String, dynamic>.from(await req('POST', '/api/wallet/purchase/intent', body: {
        'productId': productId,
        'platform': platform,
        'transactionId': transactionId,
      }));
  static Future<Map<String, dynamic>> verifyPurchase({required String transactionId, required String productId, required String platform, String purchaseToken = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/wallet/purchase/verify', body: {
        'transactionId': transactionId,
        'productId': productId,
        'platform': platform,
        'purchaseToken': purchaseToken,
      }));
  static Future<Map<String, dynamic>> sendGift({
    required String receiverId,
    required String giftId,
    required String context,
    String contextId = '',
    String message = '',
    int quantity = 1,
    String idempotencyKey = '',
  }) async =>
      Map<String, dynamic>.from(await req('POST', '/api/wallet/gifts/send', body: {
        'receiverId': receiverId,
        'giftId': giftId,
        'context': context,
        'contextId': contextId,
        'message': message,
        'quantity': quantity,
        if (idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
      }));
  static Future<Map<String, dynamic>> withdraw({required int coins, required String method, required String destination}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/wallet/withdraw', body: {
        'coins': coins,
        'method': method,
        'destination': destination,
      }));
  static Future<List<dynamic>> receivedGifts() async =>
      List<dynamic>.from(await req('GET', '/api/wallet/received-gifts'));
  static Future<List<dynamic>> sentGifts() async =>
      List<dynamic>.from(await req('GET', '/api/wallet/sent-gifts'));
  // ---------------- Marketplace / Store ----------------
  static Future<List<dynamic>> storeListings({String category = '', String q = '', String location = '', String minPrice = '', String maxPrice = '', String sort = 'latest'}) async {
    final params = <String, String>{};
    if (category.isNotEmpty && category != 'الكل') params['category'] = category;
    if (q.isNotEmpty) params['q'] = q;
    if (location.isNotEmpty) params['location'] = location;
    if (minPrice.isNotEmpty) params['minPrice'] = minPrice;
    if (maxPrice.isNotEmpty) params['maxPrice'] = maxPrice;
    if (sort.isNotEmpty) params['sort'] = sort;
    final uri = Uri.parse('$baseUrl/api/store/listings').replace(queryParameters: params);
    final r = await req('GET', uri.path + (uri.hasQuery ? '?${uri.query}' : ''));
    return List<dynamic>.from(r);
  }
  static Future<Map<String, dynamic>> createStoreListing(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await req('POST', '/api/store/listings', body: body));
  static Future<Map<String, dynamic>> storeView(String id) async =>
      Map<String, dynamic>.from(await req('POST', '/api/store/listings/$id/view'));
  static Future<Map<String, dynamic>> storeOrder(String id, {int quantity = 1}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/store/listings/$id/order', body: {'quantity': quantity}));
  static Future<Map<String, dynamic>> storeReview(String id, {required int rating, String comment = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/store/listings/$id/reviews', body: {'rating': rating, 'comment': comment}));
  static Future<Map<String, dynamic>> storeCommissionSettings() async =>
      Map<String, dynamic>.from(await req('GET', '/api/store/commission/settings'));
  static Future<Map<String, dynamic>> storeCommissionDashboard() async =>
      Map<String, dynamic>.from(await req('GET', '/api/store/commission/dashboard'));
  static Future<Map<String, dynamic>> storeAffiliate(String listingId) async =>
      Map<String, dynamic>.from(await req('GET', '/api/store/affiliate/$listingId'));
  static Future<Map<String, dynamic>> storeAffiliateClick({required String listingId, required String referrerId}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/store/affiliate/click', body: {'listingId': listingId, 'referrerId': referrerId}));
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> apiMessages = {
  'EMAIL_OR_USERNAME_EXISTS': 'البريد الإلكتروني أو اسم المستخدم مستخدم بالفعل.',
  'INVALID_CREDENTIALS': 'بيانات الدخول غير صحيحة.',
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
};

class Api {
  static const base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://hamkei62.onrender.com',
  );
  static String baseUrl = base;
  static String socketUrl = const String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://hamkei62.onrender.com',
  );

  static String? token;
  static Map<String, dynamic>? me;

  /// Real, distinct fallback endpoints. We deliberately avoid duplicating the
  /// primary URL — Render's free plan returns 502 while waking up; the API now
  /// probes each candidate with a *short* timeout and switches baseUrl to the
  /// first one that responds.
  static const List<String> fallbackBases = <String>[
    'https://hamkei62.onrender.com',
    'https://hamkei62-api.onrender.com',
    'https://socialnova-api.onrender.com',
    'https://hamkei62.up.railway.app',
    'https://hamkei62.fly.dev',
  ];

  static Future<bool> ping(String root) async {
    final r = root.trim().replaceAll(RegExp(r'/+$'), '');
    if (r.isEmpty) return false;
    try {
      final res = await http
          .get(Uri.parse('$r/api/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode < 500 && res.body.contains('"ok"');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> checkServer() => ping(baseUrl);

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    final saved = p.getString('api_url');
    final preferred = (saved != null && saved.trim().isNotEmpty) ? saved.trim() : base;
    baseUrl = preferred;
    unawaited(_resolveReachable(preferred));
  }

  static Future<void> _resolveReachable(String preferred) async {
    if (await ping(preferred)) return;
    for (final candidate in <String>[base, ...fallbackBases]) {
      final c = candidate.trim().replaceAll(RegExp(r'/+$'), '');
      if (c == preferred) continue;
      if (await ping(c)) {
        baseUrl = c;
        return;
      }
    }
  }

  static Future<void> setBaseUrl(String value) async {
    final v = value.trim().replaceAll(RegExp(r'/+$'), '');
    baseUrl = v.isEmpty ? base : v;
    final p = await SharedPreferences.getInstance();
    if (v.isEmpty) {
      await p.remove('api_url');
    } else {
      await p.setString('api_url', baseUrl);
    }
  }

  static Future<void> saveToken(String value) async {
    token = value;
    final p = await SharedPreferences.getInstance();
    await p.setString('token', value);
  }

  static Future<void> logout() async {
    token = null;
    me = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
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
      } on TimeoutException catch (e) {
      } on SocketException catch (e) {
      } on http.ClientException catch (e) {
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
  static Future<dynamic> req(String method, String path, {Map<String, dynamic>? body}) async {
    const maxAttempts = 3;
    for (var attempt = 1; ; attempt++) {
      final headers = <String, String>{
        'Content-Type': 'application/json',
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
        throw Exception('تعذّر الوصول إلى الخادم ($baseUrl).');
      } on http.ClientException {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 3));
          continue;
        }
        throw Exception('فشل الاتصال بالخادم ($baseUrl).');
      }

      // Gateway hiccup while the service wakes up -> wait and try again.
      if ((response.statusCode == 502 ||
              response.statusCode == 503 ||
              response.statusCode == 504) &&
          attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 4));
        continue;
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
    final x = await req('POST', '/api/auth/login', body: {'login': login, 'password': password});
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
  static Future<List<dynamic>> groups() async => List<dynamic>.from(await req('GET', '/api/groups'));
  static Future<List<dynamic>> myGroups() async => List<dynamic>.from(await req('GET', '/api/me/groups'));
  static Future<List<dynamic>> notifications() async =>
      List<dynamic>.from(await req('GET', '/api/notifications'));
  static Future<void> readNotifications() async => req('POST', '/api/notifications/read');
  static Future<List<dynamic>> searchUsers(String q) async =>
      List<dynamic>.from(await req('GET', '/api/users/search?q=${Uri.encodeQueryComponent(q)}'));
  static Future<List<dynamic>> suggestedUsers() async =>
      List<dynamic>.from(await req('GET', '/api/users/suggested'));

  static Future<Map<String, dynamic>> like(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/like'));
  static Future<Map<String, dynamic>> bookmark(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/bookmark'));
  static Future<Map<String, dynamic>> repost(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/repost'));
  static Future<Map<String, dynamic>> sharePost(String id) async => Map<String, dynamic>.from(await req('POST', '/api/posts/$id/share'));
  static Future<void> viewPost(String id) async => req('POST', '/api/posts/$id/view');
  static Future<Map<String,dynamic>> comment(String id, String body, {String? parentId}) async => Map<String,dynamic>.from(await req('POST', '/api/posts/$id/comments', body: {'body': body, if (parentId != null) 'parentId': parentId}));
  static Future<List<dynamic>> postComments(String id) async => List<dynamic>.from(await req('GET','/api/posts/$id/comments'));
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
  static Future<Map<String,dynamic>> shareReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/share'));
  static Future<Map<String,dynamic>> repostReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/repost'));
  static Future<Map<String,dynamic>> bookmarkReel(String id) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/bookmark'));
  static Future<Map<String,dynamic>> reelFeedback(String id,String kind,{String reason=''}) async => Map<String,dynamic>.from(await req('POST','/api/reels/$id/feedback',body:{'kind':kind,'reason':reason}));
  static Future<void> reportReel(String id,String reason) async => req('POST','/api/reels/$id/report',body:{'reason':reason});
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
  static Future<Map<String, dynamic>> sendMessage(String userId, String body, {bool secret = false, bool selfDestruct = false, int ttlMinutes = 60, int viewLimit = 0}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/messages/$userId', body: {'body': body, 'secret': secret, 'selfDestruct': selfDestruct, 'ttlMinutes': ttlMinutes, 'viewLimit': viewLimit}));
  static Future<void> viewMessage(String id) async => req('POST','/api/messages/$id/view');
  static Future<Map<String,dynamic>> chatTheme(String userId) async => Map<String,dynamic>.from(await req('GET','/api/chats/$userId/theme'));
  static Future<void> savePushToken(String token) async => req('POST','/api/push/token',body:{'token':token});
  static Future<void> markMessageDelivered(String id) async => req('POST','/api/messages/$id/delivered');
  static Future<void> markMessageRead(String id) async => req('POST','/api/messages/$id/read');
  static Future<Map<String,dynamic>> saveChatTheme(String userId, {required String background, String bubbleStyle='glass', String accent='violet'}) async => Map<String,dynamic>.from(await req('PUT','/api/chats/$userId/theme', body:{'background':background,'bubbleStyle':bubbleStyle,'accent':accent}));

  // ---------------- groups ----------------
  static Future<void> createGroup(String name, String desc, {String avatarUrl = '', String coverUrl = '', String privacy = 'PUBLIC', String rules = ''}) async =>
      req('POST', '/api/groups', body: {'name': name, 'description': desc, 'avatarUrl': avatarUrl, 'coverUrl': coverUrl, 'privacy': privacy, 'rules': rules});
  static Future<void> updateGroup(String id, String name, String desc, {String? privacy, String? rules}) async =>
      req('PATCH', '/api/groups/$id', body: {'name': name, 'description': desc, if (privacy != null) 'privacy': privacy, if (rules != null) 'rules': rules});
  static Future<void> joinGroup(String id) async => req('POST', '/api/groups/$id/join');
  static Future<Map<String, dynamic>> group(String id) async =>
      Map<String, dynamic>.from(await req('GET', '/api/groups/$id'));
  static Future<List<dynamic>> groupMessages(String id) async =>
      List<dynamic>.from(await req('GET', '/api/groups/$id/messages'));
  static Future<void> sendGroupMessage(String id, String body) async =>
      req('POST', '/api/groups/$id/messages', body: {'body': body});

  // ---------------- live ----------------
  static Future<Map<String, dynamic>> createLive(String title) async =>
      Map<String, dynamic>.from(await req('POST', '/api/live', body: {'title': title}));
  static Future<Map<String, dynamic>> liveToken(String roomName) async =>
      Map<String, dynamic>.from(await req('POST', '/api/live/token', body: {'roomName': roomName}));
  static Future<void> endLive(String id) async => req('POST', '/api/live/$id/end');
  static Future<Map<String,dynamic>> createLiveChallenge(String roomName,String opponentId,{String title='جولة تحدي'}) async => Map<String,dynamic>.from(await req('POST','/api/live/challenges',body:{'roomName':roomName,'opponentId':opponentId,'title':title}));
  static Future<Map<String,dynamic>> updateLiveChallenge(String id,{required int scoreA,required int scoreB}) async => Map<String,dynamic>.from(await req('PATCH','/api/live/challenges/$id',body:{'scoreA':scoreA,'scoreB':scoreB}));
  static Future<Map<String,dynamic>> finishLiveChallenge(String id,String winnerId) async => Map<String,dynamic>.from(await req('POST','/api/live/challenges/$id/finish',body:{'winnerId':winnerId}));

  // ---------------- NovaCoins wallet ----------------
  static Future<Map<String, dynamic>> wallet() async =>
      Map<String, dynamic>.from(await req('GET', '/api/wallet'));
  static Future<List<dynamic>> gifts() async =>
      List<dynamic>.from(await req('GET', '/api/wallet/gifts'));
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
  static Future<Map<String, dynamic>> sendGift({required String receiverId, required String giftId, required String context, String contextId = '', String message = ''}) async =>
      Map<String, dynamic>.from(await req('POST', '/api/wallet/gifts/send', body: {
        'receiverId': receiverId,
        'giftId': giftId,
        'context': context,
        'contextId': contextId,
        'message': message,
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

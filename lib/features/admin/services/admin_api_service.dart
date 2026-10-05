import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialnova/core/secrets/app_secrets.dart';

class AdminSession {
  final String token;
  final Map<String, dynamic> user;
  final bool isAdmin;
  const AdminSession({required this.token, required this.user, required this.isAdmin});
}

class AdminApiService {
  AdminApiService._();
  static final AdminApiService instance = AdminApiService._();

  static const _tokenKey = 'socialnova_admin_token';
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppSecrets.effectiveApiUrl.replaceFirst(RegExp(r'/$'), ''),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  String? _token;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<AdminSession> login(String login, String password) async {
    final response = await _dio.post('/api/auth/login', data: {'login': login.trim(), 'password': password});
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['isAdmin'] != true && data['user']?['role'] != 'DEVELOPER') {
      throw Exception('هذا الحساب لا يملك صلاحيات الإدارة.');
    }
    _token = data['token'] as String?;
    if (_token == null || _token!.isEmpty) throw Exception('لم يتم استلام جلسة الإدارة.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    return AdminSession(token: _token!, user: Map<String, dynamic>.from(data['user'] as Map), isAdmin: true);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> status() async {
    final data = await _get('/api/admin/status');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _get(path, query: query);

  Future<dynamic> patch(String path, {Object? data}) => _request('PATCH', path, data: data);
  Future<dynamic> post(String path, {Object? data}) => _request('POST', path, data: data);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get(path, queryParameters: query, options: _options());
      return r.data;
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  Future<dynamic> _request(String method, String path, {Object? data}) async {
    try {
      final r = await _dio.request(path, data: data, options: _options(method: method));
      return r.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
      }
      throw Exception(_message(e));
    }
  }

  Options _options({String? method}) => Options(
        method: method,
        headers: _token == null ? null : {'Authorization': 'Bearer $_token'},
      );

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (e.type == DioExceptionType.connectionError) return 'تعذر الاتصال بخادم الإدارة.';
    return e.message ?? 'حدث خطأ غير متوقع.';
  }
}

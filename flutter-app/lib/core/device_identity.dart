import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  static const _channel = MethodChannel('socialnova/device');
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;
    try {
      final native = await _channel.invokeMethod<String>('deviceId');
      if (native != null && native.trim().isNotEmpty) {
        _cached = native.trim();
        return _cached!;
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('socialnova_device_id');
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = '${DateTime.now().microsecondsSinceEpoch}-${List<int>.generate(16, (_) => r.nextInt(256)).map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';
      await prefs.setString('socialnova_device_id', id);
    }
    _cached = id;
    return id;
  }
}

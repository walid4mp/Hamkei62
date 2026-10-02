import 'dart:convert';
import 'package:flutter/services.dart';

/// Flutter-side contract for the Unity 3D gift runtime.
///
/// The Android Unity Library owns the actual 3D scene. Flutter remains the
/// source of truth for auth, wallet, LiveKit and gift purchase/send APIs.
class UnityGiftBridge {
  UnityGiftBridge._();
  static const MethodChannel _channel = MethodChannel('socialnova/unity_gifts');

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> show() async {
    await _channel.invokeMethod<void>('show');
  }

  static Future<void> hide() async {
    await _channel.invokeMethod<void>('hide');
  }

  static Future<void> play({
    required String giftId,
    required String senderName,
    int quantity = 1,
  }) async {
    final payload = jsonEncode({
      'giftId': giftId,
      'senderName': senderName,
      'quantity': quantity.clamp(1, 99),
    });
    await _channel.invokeMethod<void>('playGift', {'json': payload});
  }
}

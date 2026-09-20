import 'dart:async';

import 'package:flutter/services.dart';

class CallMediaEngine {
  CallMediaEngine() {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  static const _channel = MethodChannel('mdless/calls');
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  List<String> protocolVersions = const [];
  int minLayer = 65;
  int maxLayer = 92;
  bool isAvailable = false;
  String? error;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> initialize() async {
    try {
      final value = await _channel.invokeMethod<Map<Object?, Object?>>('getProtocol');
      final protocol = value == null ? const <Object?, Object?>{} : Map<Object?, Object?>.from(value);
      protocolVersions = (protocol['libraryVersions'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false);
      minLayer = (protocol['minLayer'] as num?)?.toInt() ?? 65;
      maxLayer = (protocol['maxLayer'] as num?)?.toInt() ?? 92;
      isAvailable = protocolVersions.isNotEmpty;
      error = isAvailable ? null : 'The native Telegram call engine reported no supported protocol versions.';
    } on MissingPluginException {
      isAvailable = false;
      error = 'The Android Telegram call engine is not present in this build.';
    } catch (exception) {
      isAvailable = false;
      error = exception.toString();
    }
  }

  Future<void> prepare({
    required int callId,
    required int userId,
    required bool isOutgoing,
    required String encryptionKey,
    required List<Map<String, dynamic>> servers,
    required Map<String, dynamic> protocol,
    required bool allowP2p,
    required String customParameters,
  }) async {
    await _channel.invokeMethod<void>('prepare', {
      'callId': callId,
      'userId': userId,
      'isOutgoing': isOutgoing,
      'encryptionKey': encryptionKey,
      'servers': servers,
      'protocol': protocol,
      'allowP2p': allowP2p,
      'customParameters': customParameters,
    });
  }

  Future<void> sendSignalingData({required int userId, required String data}) async {
    await _channel.invokeMethod<void>('sendSignalingData', {'userId': userId, 'data': data});
  }

  Future<void> setMuted({required int userId, required bool muted}) async {
    await _channel.invokeMethod<void>('mute', {'userId': userId, 'muted': muted});
  }

  Future<void> stop({required int userId}) async {
    await _channel.invokeMethod<void>('stop', {'userId': userId});
  }

  Future<void> _handleNativeEvent(MethodCall call) async {
    final raw = call.arguments;
    if (raw is Map) {
      _events.add({
        '@type': call.method,
        ...Map<String, dynamic>.from(raw),
      });
    }
  }

  Future<void> dispose() async {
    await _events.close();
  }
}

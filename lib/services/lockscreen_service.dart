import 'package:flutter/services.dart';

class LockscreenService {
  static final LockscreenService instance = LockscreenService._internal();
  LockscreenService._internal();

  static const _channel = MethodChannel('com.staticradio.app/lockscreen');

  VoidCallback? onPrevChannelReceived;
  VoidCallback? onNextChannelReceived;
  VoidCallback? onTalkToggleReceived;

  void init({
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onTalk,
  }) {
    onPrevChannelReceived = onPrev;
    onNextChannelReceived = onNext;
    onTalkToggleReceived = onTalk;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPrevChannel':
          onPrevChannelReceived?.call();
          break;
        case 'onNextChannel':
          onNextChannelReceived?.call();
          break;
        case 'onTalkToggle':
          onTalkToggleReceived?.call();
          break;
      }
    });
  }

  Future<void> start({
    required String ticker,
    required String frequency,
    bool isTransmitting = false,
    bool isBusy = false,
  }) async {
    try {
      await _channel.invokeMethod('startLockscreenService', {
        'ticker': ticker,
        'frequency': frequency,
        'isTransmitting': isTransmitting,
        'isBusy': isBusy,
      });
    } catch (_) {}
  }

  Future<void> update({
    required String ticker,
    required String frequency,
    bool isTransmitting = false,
    bool isBusy = false,
  }) async {
    try {
      await _channel.invokeMethod('updateLockscreenState', {
        'ticker': ticker,
        'frequency': frequency,
        'isTransmitting': isTransmitting,
        'isBusy': isBusy,
      });
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopLockscreenService');
    } catch (_) {}
  }
}

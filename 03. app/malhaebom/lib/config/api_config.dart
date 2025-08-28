import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // 1순위: --dart-define=API_BASE=...
  static const String _defined = String.fromEnvironment(
    'API_BASE',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defined.isNotEmpty) return _defined;

    if (kIsWeb) return 'http://localhost:4000';

    if (Platform.isAndroid) return 'http://10.0.2.2:4000'; // 안드로이드 에뮬레이터
    if (Platform.isIOS) return 'http://localhost:4000'; // iOS 시뮬레이터

    // 실기기 기본값(같은 와이파이에서 PC IP로 바꾸세요)
    return 'http://192.168.0.23:4000';
  }
}

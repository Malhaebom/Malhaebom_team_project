import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 인터뷰 진행 캐시(로컬 저장)
class InterviewSession {
  static const _kKeyPrefix = 'interview_progress_';

  static String _keyOf(int total) => '$_kKeyPrefix$total';

  /// 진행 배열 로드 (길이: total)
  static Future<List<bool>> getProgress(int total) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOf(total));
    if (raw == null) return List<bool>.filled(total, false);
    try {
      final List<dynamic> list = jsonDecode(raw);
      return List<bool>.generate(total, (i) {
        if (i < list.length) return list[i] == true;
        return false;
      });
    } catch (_) {
      return List<bool>.filled(total, false);
    }
  }

  /// index 완료/해제 저장 (저장 완료까지 await)
  static Future<void> setDone(int index, bool done, int total) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyOf(total);

    List<bool> cur;
    final raw = prefs.getString(key);
    if (raw == null) {
      cur = List<bool>.filled(total, false);
    } else {
      try {
        final List<dynamic> list = jsonDecode(raw);
        cur = List<bool>.generate(total, (i) {
          if (i < list.length) return list[i] == true;
          return false;
        });
      } catch (_) {
        cur = List<bool>.filled(total, false);
      }
    }

    if (index >= 0 && index < cur.length) {
      cur[index] = done;
    }
    await prefs.setString(key, jsonEncode(cur));
  }

  /// 특정 인덱스 완료 여부
  static Future<bool> isDone(int index, int total) async {
    final arr = await getProgress(total);
    return index >= 0 && index < arr.length ? arr[index] : false;
  }

  /// 전체 완료 여부
  static Future<bool> isCompleted(int total) async {
    final arr = await getProgress(total);
    for (final v in arr) {
      if (!v) return false;
    }
    return true;
  }

  /// 회차가 완전히 끝났다면 초기화(리스트 진입 전에 호출)
  static Future<void> resetIfCompleted(int total) async {
    final prefs = await SharedPreferences.getInstance();
    final done = await isCompleted(total);
    if (done) {
      await prefs.remove(_keyOf(total));
    }
  }

  /// 결과 페이지 진입 시 호출: 진행 캐시 제거
  /// - 전체 prefix 삭제(여러 total 값 섞여 있을 때도 정리)
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kKeyPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

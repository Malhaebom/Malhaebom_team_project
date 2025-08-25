import 'dart:math';

/// 회차 진행도(메모리 우선, 필요시 영속화는 나중에 추가)
class InterviewSession {
  static List<bool> _progress = <bool>[];
  static bool _completed = false;

  static void _ensureLen(int n) {
    if (_progress.length != n) {
      _progress = List<bool>.filled(n, false);
    }
  }

  /// 회차 완료로 마킹 (결과 페이지에서 호출)
  static void markCompleted() {
    _completed = true;
  }

  static bool isCompleted() => _completed;

  /// 새 회차 시작 시 초기화(리스트 진입 시 호출)
  static void resetIfCompleted(int itemCount) {
    if (_completed) {
      _progress = List<bool>.filled(itemCount, false);
      _completed = false;
    }
  }

  /// 전체 진행도 가져오기(리스트 새로고침용)
  static List<bool> getProgress(int itemCount) {
    _ensureLen(itemCount);
    return List<bool>.from(_progress); // 복사본
  }

  /// 특정 항목 완료/해제
  static void setDone(int index0, bool done, int itemCount) {
    _ensureLen(itemCount);
    if (index0 >= 0 && index0 < _progress.length) {
      _progress[index0] = done;
    }
  }

  static bool isDone(int index0) {
    return (index0 >= 0 && index0 < _progress.length) && _progress[index0];
  }

  /// 디버그용(선택)
  static int doneCount() => _progress.where((e) => e).length;
}

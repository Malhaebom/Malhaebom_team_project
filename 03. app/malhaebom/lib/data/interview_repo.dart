// lib/data/interview_repo.dart
import 'interview_assets.dart';

class InterviewItem {
  final int number;      // = question_id 역할
  final String title;
  final String speechText;
  final String sound;

  const InterviewItem({
    required this.number,
    required this.title,
    required this.speechText,
    required this.sound,
  });
}

class InterviewRepo {
  static int _asInt(Object? v, int fallback) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static List<InterviewItem> getAll() {
    final src = InterviewAssets.items;
    return List.generate(src.length, (i) {
      final m = src[i] as Map<String, Object?>;

      // 👇 우선순위: assets의 question_id → 없으면 i+1
      final qid = _asInt(m['question_id'], i + 1);

      return InterviewItem(
        number: qid, // 서버에 보낼 question_id로 사용
        title: (m['title'] as String?) ?? '인터뷰하기${i + 1}',
        speechText: (m['speechText'] as String?) ?? '',
        sound: (m['sound'] as String?) ?? '',
      );
    });
  }

  static InterviewItem? getByIndex(int index0) {
    final all = getAll();
    if (index0 < 0 || index0 >= all.length) return null;
    return all[index0];
  }

  // (옵션) question_id로 찾기
  static InterviewItem? getByQuestionId(int qid) {
    for (final item in getAll()) {
      if (item.number == qid) return item;
    }
    return null;
  }
}

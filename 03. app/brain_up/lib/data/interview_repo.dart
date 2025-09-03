// lib/data/interview_repo.dart
import 'interview_assets.dart';

class InterviewItem {
  final int number; // 1..N
  final String title; // "인터뷰하기1" ...
  final String speechText; // 지문
  final String sound; // assets/interview/audio_X.mp3

  const InterviewItem({
    required this.number,
    required this.title,
    required this.speechText,
    required this.sound,
  });
}

class InterviewRepo {
  static List<InterviewItem> getAll() {
    final src = InterviewAssets.items;
    return List.generate(src.length, (i) {
      final m = src[i];
      return InterviewItem(
        number: i + 1,
        title: m['title'] ?? '인터뷰하기${i + 1}',
        speechText: m['speechText'] ?? '',
        sound: m['sound'] ?? '',
      );
    });
  }

  static InterviewItem? getByIndex(int index0) {
    final all = getAll();
    if (index0 < 0 || index0 >= all.length) return null;
    return all[index0];
  }
}

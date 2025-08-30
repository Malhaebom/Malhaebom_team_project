// lib/data/interview_assets.dart
class InterviewAssets {
  static const String base = 'assets/interview';

  /// 인터뷰 항목(텍스트 + 매칭되는 mp3 경로)
  /// audio_0.mp3 ~ audio_11.mp3 순서로 매핑
  static const List<Map<String, String>> items = [
    {
      "title": "인터뷰하기1",
      "speechText": "자기소개를 해주세요.\n(출생지, 나이, 이름 등)",
      "sound": "$base/audio_0.mp3",
    },
    {
      "title": "인터뷰하기2",
      "speechText": "나의 학창시절은 어땠나요?",
      "sound": "$base/audio_1.mp3",
    },
    {
      "title": "인터뷰하기3",
      "speechText": "학창시절 소풍 가셨을 때\n어머니가 도시락을 싸주셨나요?",
      "sound": "$base/audio_2.mp3",
    },
    {
      "title": "인터뷰하기4",
      "speechText": "소풍은 어디로 자주 가셨나요?\n기억에 남는 게임이 있나요?",
      "sound": "$base/audio_3.mp3",
    },
    {
      "title": "인터뷰하기5",
      "speechText": "기억에 남는 특별한\n사건(사고)은 있나요?",
      "sound": "$base/audio_4.mp3",
    },
    {
      "title": "인터뷰하기6",
      "speechText": "옛날 부산은 어땠나요?\n지금 부산은 어떤가요?",
      "sound": "$base/audio_5.mp3",
    },
    {
      "title": "인터뷰하기7",
      "speechText": "부산에서 추천해주고 싶은\n장소가 있나요?",
      "sound": "$base/audio_6.mp3",
    },
    {
      "title": "인터뷰하기8",
      "speechText": "당신의 삶에서 제일 기뻤던\n순간은 언제인가요?",
      "sound": "$base/audio_7.mp3",
    },
    {
      "title": "인터뷰하기9",
      "speechText": "살아오면서 힘들었던 일,\n그리고 이겨낸 경험이 있나요?",
      "sound": "$base/audio_8.mp3",
    },
    {
      "title": "인터뷰하기10",
      "speechText": "당신의 삶에서 후회스러운\n순간은 언제인가요?",
      "sound": "$base/audio_9.mp3",
    },
    {
      "title": "인터뷰하기11",
      "speechText": "자녀분이 어렸을 적 좋았던\n순간을 말씀해 주실 수 있나요?",
      "sound": "$base/audio_10.mp3",
    },
    {
      "title": "인터뷰하기12",
      "speechText": "마지막으로, 자녀분께\n하고 싶은 말이 있다면?",
      "sound": "$base/audio_11.mp3",
    },
  ];
}

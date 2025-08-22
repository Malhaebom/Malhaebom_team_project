import 'package:flutter/foundation.dart';

/// 한 권의 동화에 대한 모든 경로를 묶어둔 모델
class FairytaleAsset {
  final String title; // 화면에 보이는 제목 (예: "아들의 호빵")
  final String titleImg; // 썸네일 이미지
  final String? content; // 소개 문구
  final String video; // 동영상 경로
  final String workbookJson; // 워크북 JSON 경로
  final String workbookImg; // 워크북 이미지 폴더 (파일명은 JSON의 list 값과 조합)
  final String voiceDir; // 음성 폴더

  const FairytaleAsset({
    required this.title,
    required this.titleImg,
    required this.content,
    required this.video,
    required this.workbookJson,
    required this.workbookImg,
    required this.voiceDir,
  });

  /// 폴더 경로 뒤에 슬래시가 중복되지 않도록 정리
  String get workbookImagesBase =>
      workbookImg.endsWith('/')
          ? workbookImg.substring(0, workbookImg.length - 1)
          : workbookImg;

  String get voiceBase =>
      voiceDir.endsWith('/')
          ? voiceDir.substring(0, voiceDir.length - 1)
          : voiceDir;
}

/// 🔹 여기서 책들을 전부 등록
const List<FairytaleAsset> Fairytales = [
  FairytaleAsset(
    title: '어머니의벙어리장갑',
    titleImg: 'assets/fairytale/어머니의벙어리장갑.png',
    content: '1960년도 추운 겨울,\n3남매 가족의 사랑을 그리는 이야기에요.',
    video: 'assets/fairytale/어머니의벙어리장갑.mp4',
    workbookJson: 'assets/fairytale/어머니의벙어리/workbook.json',
    workbookImg: 'assets/fairytale/어머니의벙어리', // 디렉토리
    voiceDir: 'assets/fairytale/어머니의벙어리/voice', // 디렉토리
  ),
  FairytaleAsset(
    title: '아버지와결혼식',
    titleImg: 'assets/fairytale/아버지와결혼식.png',
    content: '1980년대, 부산에 사는 딸과 아버지의\n가슴이 뭉클해지는 이야기에요.',
    video: 'assets/fairytale/아버지와결혼식.mp4',
    workbookJson: 'assets/fairytale/아버지와결혼식/workbook.json',
    workbookImg: 'assets/fairytale/아버지와결혼식',
    voiceDir: 'assets/fairytale/아버지와결혼식/voice',
  ),
  FairytaleAsset(
    title: '아들의 호빵',
    titleImg: 'assets/fairytale/아들의 호빵.png',
    content: '1970년도에 있었던 어머니와 아들의\n따스한 과거를 담은 이야기입니다.',
    video: 'assets/fairytale/아들의 호빵.mp4',
    workbookJson: 'assets/fairytale/아들의 호빵/workbook.json',
    workbookImg: 'assets/fairytale/아들의 호빵',
    voiceDir: 'assets/fairytale/아들의 호빵/voice',
  ),
  FairytaleAsset(
    title: '할머니와바나나',
    titleImg: 'assets/fairytale/할머니와바나나.png',
    content: '1980년도에 있었던 할머니, 손자 주현이의\n3대 가족이 바나나를 통해\n따스한 과거를 담은 이야기입니다.',
    video: 'assets/fairytale/할머니와바나나.mp4',
    workbookJson: 'assets/fairytale/할머니와바나나/workbook.json',
    workbookImg: 'assets/fairytale/할머니와바나나',
    voiceDir: 'assets/fairytale/할머니와바나나/voice',
  ),
];

/// 제목으로 찾기 (없으면 assert 에러)
FairytaleAsset byTitle(String title) {
  return Fairytales.firstWhere(
    (e) => e.title == title,
    orElse: () {
      throw FlutterError('Unknown fairytale title: $title');
    },
  );
}

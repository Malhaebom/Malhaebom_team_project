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
    title: '어머니의 벙어리 장갑',
    titleImg: 'assets/fairytale/어머니의벙어리장갑.png',
    content: '1960년도 추운 겨울,\n3남매 가족의 사랑을\n그리는 이야기에요.',
    video: 'assets/fairytale/mother_mitten.mp4',
    workbookJson: 'assets/fairytale/어머니의벙어리/workbook.json',
    workbookImg: 'assets/fairytale/어머니의벙어리', // 디렉토리
    voiceDir: 'assets/fairytale/어머니의벙어리/voice', // 디렉토리
  ),
  FairytaleAsset(
    title: '아버지와 결혼식',
    titleImg: 'assets/fairytale/아버지와결혼식.png',
    content: '1980년대, 부산에 사는\n딸과 아버지의 가슴이\n뭉클해지는 이야기에요.',
    video: 'assets/fairytale/father_wedding.mp4',
    workbookJson: 'assets/fairytale/아버지와결혼식/workbook.json',
    workbookImg: 'assets/fairytale/아버지와결혼식',
    voiceDir: 'assets/fairytale/아버지와결혼식/voice',
  ),
  FairytaleAsset(
    title: '아들의 호빵',
    titleImg: 'assets/fairytale/아들의 호빵.png',
    content: '1970년도에 있었던\n어머니와 아들의 따스한\n과거를 담은 이야기입니다.',
    video: 'assets/fairytale/hobbang_son.mp4',
    workbookJson: 'assets/fairytale/아들의 호빵/workbook.json',
    workbookImg: 'assets/fairytale/아들의 호빵',
    voiceDir: 'assets/fairytale/아들의 호빵/voice',
  ),
  FairytaleAsset(
    title: '할머니와 바나나',
    titleImg: 'assets/fairytale/할머니와바나나.png',
    content: '1980년도에 있었던 할머니,\n손자 주현이의 3대 가족이\n바나나를 통해 따스한\n과거를 담은 이야기입니다.',
    video: 'assets/fairytale/grandma_banana.mp4',
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

int indexByTitle(String title) {
  final i = Fairytales.indexWhere((e) => e.title == title);
  if (i == -1) {
    throw FlutterError('Unknown fairytale title: $title');
  }
  return i;
}

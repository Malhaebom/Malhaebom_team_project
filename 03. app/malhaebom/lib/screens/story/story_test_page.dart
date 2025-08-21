// lib/screens/story/story_test_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/data/fairytale_data.dart';
import 'package:malhaebom/screens/story/story_test_result_page.dart';
import 'package:malhaebom/theme/colors.dart';

// =========================
// 데이터 모델
// =========================
class StoryQuestion {
  final String category; // ex) '요구-직접화행', '질문', ...
  final String prompt; // 문제 문장 (data의 "title")
  final List<String> choices; // 보기 (data의 "list")
  final int? answerIndex; // 정답 인덱스 (data의 "answer")
  final String? cover; // 커버 이미지 (data의 "image")

  const StoryQuestion({
    required this.category,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    this.cover,
  });
}

// =========================
// 테스트 페이지
// =========================
class StoryTestPage extends StatefulWidget {
  final String title; // ← 동화 제목 (데이터 맵의 키)
  final String storyImg; // ← 백업 커버 이미지(데이터에 image 없을 때 사용)

  const StoryTestPage({super.key, required this.title, required this.storyImg});

  @override
  State<StoryTestPage> createState() => _StoryTestPageState();
}

class _StoryTestPageState extends State<StoryTestPage> {
  static const int _kPointsPerQuestion = 2; // 문제당 2점

  late final List<StoryQuestion> _questions;
  late final List<bool?> _answers; // 정답/오답/미채점(null)
  int _index = 0;
  int? _selected; // 사용자가 고른 보기
  int _pointScore = 0; // 누적 점수(포인트)

  // 정오 기록(결과 페이지로 넘길 용도)
  late final int _validCount; // 정답이 지정된 문제 개수(= 분모/2)

  @override
  void initState() {
    super.initState();
    _questions = _loadQuestionsFromData(widget.title, widget.storyImg);
    _answers = List<bool?>.filled(_questions.length, null);
    _validCount = _questions.where((q) => q.answerIndex != null).length;
  }

  // 데이터 → 화면용 모델 변환
  List<StoryQuestion> _loadQuestionsFromData(
    String title,
    String fallbackCover,
  ) {
    final root = FairytaleData().data[title];
    if (root == null) return const [];

    final cover = (root['image'] as String?) ?? fallbackCover;
    final List tests = (root['test'] as List?) ?? const [];

    return tests
        .map<StoryQuestion>((raw) {
          final type = (raw['type'] ?? '').toString();
          final prompt = (raw['title'] ?? '').toString();
          final choices =
              (raw['list'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
          final a = raw['answer'];

          // answer 인덱스 방어 처리(0-based 가정, 범위 밖이면 0으로 보정)
          int? ans;
          if (a is int) {
            if (a == 0) {
              // 요구사항: 0은 "정답 미지정" → 채점에서 제외
              ans = null;
            } else if (a > 0 && a <= choices.length) {
              // 양수는 1-based로 간주
              ans = a - 1;
            } else {
              // 방어: 범위 밖이면 미지정으로
              ans = null;
            }
          }

          return StoryQuestion(
            category: type,
            prompt: prompt,
            choices: choices,
            answerIndex: ans,
            cover: cover,
          );
        })
        .toList(growable: false);
  }

  void _onSelect(int idx) {
    setState(() => _selected = idx); // 선택만 표시. 즉시 채점/피드백 없음
  }

  void _next() {
    final q = _questions[_index];
    if (q.answerIndex != null && _selected != null) {
      final ok = (_selected == q.answerIndex);
      _answers[_index] = ok;
      if (ok) _pointScore += _kPointsPerQuestion; // 문제당 2점
    } else {
      // 정답 미지정 문제 or 선택 없음 → 점수/통계 둘 다 미반영
      _answers[_index] = null;
    }

    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
      return;
    }

    // --- 집계 ---
    final byCategory = <String, CategoryStat>{};
    final byType = <String, CategoryStat>{};

    CategoryStat _add(Map<String, CategoryStat> m, String key, bool correct) {
      final cur = m[key];
      final next = CategoryStat(
        correct: (cur?.correct ?? 0) + (correct ? 1 : 0),
        total: (cur?.total ?? 0) + 1,
      );
      m[key] = next;
      return next;
    }

    String _baseCat(String raw) {
      if (raw.contains('요구')) return '요구';
      if (raw.contains('질문')) return '질문';
      if (raw.contains('단언')) return '단언';
      if (raw.contains('의례화')) return '의례화';
      return '기타';
    }

    String? _typeCat(String raw) {
      if (raw.contains('직접')) return '직접화행';
      if (raw.contains('간접')) return '간접화행';
      if (raw.contains('질문')) return '질문화행';
      if (raw.contains('단언')) return '단언화행';
      if (raw.contains('의례화')) return '의례화화행';
      return null;
    }

    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.answerIndex == null) continue; // 미지정 문제 제외
      final ok = _answers[i] ?? false;
      _add(byCategory, _baseCat(q.category), ok);
      final t = _typeCat(q.category);
      if (t != null) _add(byType, t, ok);
    }

    final int totalPoints = _validCount * _kPointsPerQuestion;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => StoryResultPage(
              score: _pointScore,
              total: totalPoints,
              byCategory: byCategory,
              byType: byType,
              testedAt: DateTime.now(),
            ),
      ),
    );
  }

  double get _progress =>
      _questions.isEmpty ? 0 : (_index / _questions.length).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          centerTitle: true,
          title: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Text(
            '해당 제목의 테스트가 없어요.',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final q = _questions[_index];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '화행 인지검사',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
            color: AppColors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 10.h),
                    // 문제 번호 + 카테고리
                    Text(
                      '${_index + 1}번. ${q.category}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 24.sp,
                        color: AppColors.btnColorDark,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // 커버
                    _coverImage(widget.storyImg, width: 120.w),

                    SizedBox(height: 10.h),

                    // 문제
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        q.prompt,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          height: 1.55,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // 보기
                    for (int i = 0; i < q.choices.length; i++) ...[
                      _choiceTile(
                        index: i,
                        text: q.choices[i],
                        isSelected: _selected == i,
                        onTap: () => _onSelect(i),
                      ),
                      SizedBox(height: 10.h),
                    ],

                    SizedBox(height: 8.h),

                    // 진행도
                    Row(
                      children: [
                        _roundIndex(_index + 1, size: 30.w),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              height: 10.h,
                              child: LayoutBuilder(
                                builder:
                                    (context, c) => Stack(
                                      children: [
                                        Container(
                                          width: c.maxWidth,
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          width: c.maxWidth * _progress,
                                          color: AppColors.btnColorDark,
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          '${_questions.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 80.h), // FAB 공간 확보
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 다음/완료 버튼: 선택했을 때만 활성화
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD43B),
              foregroundColor: Colors.black,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: (_selected == null) ? null : _next,
            child: Text(
              _index < _questions.length - 1 ? '다음' : '완료',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp),
            ),
          ),
        ),
      ),
    );
  }

  // ===== UI helpers =====
  Widget _coverImage(String src, {double? width}) {
    final radius = 12.r;
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: const Color(0xFFF3F4F6),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child:
              src.startsWith('http')
                  ? Image.network(src, fit: BoxFit.cover)
                  : Image.asset(
                    src,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
        ),
      ),
    );
    return SizedBox(width: (width ?? 160.w), child: box);
  }

  Widget _choiceTile({
    required int index,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color border =
        isSelected ? const Color(0xFF94A3B8) : const Color(0xFFE5E7EB);
    final Color bg = isSelected ? const Color(0xFFF8FAFC) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            _choiceNumber(index + 1, const Color(0xFF111827)),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20.sp,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceNumber(int n, Color color) {
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14.sp,
          color: color,
        ),
      ),
    );
  }

  Widget _roundIndex(int n, {double? size}) {
    final s = size ?? 24.w;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: (s * 0.42),
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

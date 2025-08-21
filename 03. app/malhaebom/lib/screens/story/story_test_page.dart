// lib/screens/story/story_test_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/story/story_test_result_page.dart';
import 'package:malhaebom/theme/colors.dart';

// =========================
// 데이터 모델 & 샘플 질문
// =========================
class StoryQuestion {
  final String category; // ex) '요구-직접화행'
  final String prompt;
  final List<String> choices;
  final int answerIndex;
  final String? cover;

  const StoryQuestion({
    required this.category,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    this.cover,
  });
}

const List<StoryQuestion> kSampleQuestions = [
  StoryQuestion(
    category: '요구-직접화행',
    prompt: '준비물이 필요하면 계란을 팔아서 준비한다.\n형제들이 어머니에게 어떻게 말했을까요?',
    choices: ['계란 주세요.', '계란 먹고 싶어요.', '준비물을 주세요.', '준비를 사주세요.'],
    answerIndex: 0,
  ),
  StoryQuestion(
    category: '요구-간접화행',
    prompt: '물을 마시고 싶은 상황이에요. 적절한 말은 무엇일까요?',
    choices: ['물은 차갑다.', '목이 마르네요.', '물건을 사자.', '배가 고프다.'],
    answerIndex: 1,
  ),
  StoryQuestion(
    category: '거절-직접화행', // 4대 카테고리에 없더라도 집계는 "기타"로 처리
    prompt: '친구가 빌려달라고 했을 때 정중히 거절하려면?',
    choices: ['싫어.', '다음에 줄게.', '미안해, 지금은 어려워.', '네가 사.'],
    answerIndex: 2,
  ),
];

// =========================
// 테스트 페이지
// =========================
class StoryTestPage extends StatefulWidget {
  final String title;
  final String storyImg;

  const StoryTestPage({super.key, required this.title, required this.storyImg});

  @override
  State<StoryTestPage> createState() => _StoryTestPageState();
}

class _StoryTestPageState extends State<StoryTestPage> {
  late final List<StoryQuestion> _questions;
  int _index = 0;
  int? _selected;
  bool _locked = false;
  int _score = 0;

  // 정오 기록(결과 페이지로 넘길 용도)
  late final List<bool?> _answers;

  // 추가 기회 관리
  int _tries = 0; // 0 또는 1
  final Set<int> _disabledChoices = {}; // 첫 오답으로 비활성화된 보기

  // 타이머 (문제당 5초)
  static const int _perQuestionSeconds = 5;
  int _secondsLeft = _perQuestionSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _questions = kSampleQuestions;
    _answers = List<bool?>.filled(_questions.length, null);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _perQuestionSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _locked = true; // 시간초과 → 잠금
          t.cancel();
        }
      });
    });
  }

  void _onSelect(int idx) {
    if (_locked || _disabledChoices.contains(idx)) return;
    final q = _questions[_index];

    // 정답
    if (idx == q.answerIndex) {
      setState(() {
        _selected = idx;
        _locked = true;
        _score++;
        _timer?.cancel();
      });
      return;
    }

    // 오답 + 추가 기회 남음(5초 내 첫 오답)
    if (_secondsLeft > 0 && _tries == 0) {
      setState(() {
        _tries = 1;
        _disabledChoices.add(idx); // 이 보기 비활성화 (재선택 불가)
      });
      return;
    }

    // 오답 + (추가 기회 없음/두 번째 오답) → 잠금
    setState(() {
      _selected = idx;
      _locked = true;
      _timer?.cancel();
    });
  }

  void _next() {
    // 현재 문항 정오 기록 확정
    final q = _questions[_index];
    _answers[_index] = (_selected != null && _selected == q.answerIndex);

    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _locked = false;
        _tries = 0;
        _disabledChoices.clear();
      });
      _startTimer();
    } else {
      _timer?.cancel();

      // --- 집계: ① 4대 카테고리(요구/질문/단언/의례화) ② 유형(직접/간접/질문/단언/의례화) ---
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
        final ok = _answers[i] ?? false;
        _add(byCategory, _baseCat(_questions[i].category), ok);
        final t = _typeCat(_questions[i].category);
        if (t != null) _add(byType, t, ok);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => StoryResultPage(
                score: _score,
                total: _questions.length,
                byCategory: byCategory,
                byType: byType,
                testedAt: DateTime.now(),
              ),
        ),
      );
    }
  }

  double get _progress {
    final done = _index + (_locked ? 1.0 : 0.0);
    return (done / _questions.length).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: Center(
              child: Text(
                '$_secondsLeft 초',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
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
                        fontSize: 16.sp,
                        color: AppColors.btnColorDark,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // 표지(세로 축소)
                    _coverImage(q.cover ?? widget.storyImg, width: 120.w),

                    SizedBox(height: 10.h),

                    // 지문/문제 (크게)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        q.prompt,
                        style: TextStyle(
                          fontSize: 16.sp,
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
                        isCorrect: q.answerIndex == i,
                        isWrongTried: _disabledChoices.contains(i),
                        locked: _locked,
                        onTap: () => _onSelect(i),
                      ),
                      SizedBox(height: 10.h),
                    ],

                    SizedBox(height: 8.h),

                    // 하단 진행도: (현재 번호) — [노란 진행바] — (전체 수)
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
                                          color: const Color(0xFFFFD43B),
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

                    SizedBox(height: 10.h),

                    // 추가 기회 안내 토스트 (첫 오답 직후, 잠기지 않았고 시간이 남아있을 때)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child:
                          (_tries == 1 && !_locked && _secondsLeft > 0)
                              ? _hintBanner('오답입니다. 한 번 더 선택할 수 있어요.')
                              : const SizedBox.shrink(),
                    ),

                    SizedBox(height: 80.h), // FAB 공간 확보
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 다음 버튼 (정답/두번째 오답/시간초과 시 노출)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          _locked
              ? Padding(
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
                    onPressed: _next,
                    child: Text(
                      _index < _questions.length - 1 ? '다음' : '완료',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                ),
              )
              : null,
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
    required bool isCorrect,
    required bool isWrongTried,
    required bool locked,
    required VoidCallback onTap,
  }) {
    // 상태별 색
    Color border = const Color(0xFFE5E7EB);
    Color bg = Colors.white;
    Color label = Colors.black87;

    if (locked) {
      if (isCorrect) {
        border = const Color(0xFF16A34A);
        bg = const Color(0xFFEFFBF2);
      } else if (isSelected && !isCorrect) {
        border = const Color(0xFFDC2626);
        bg = const Color(0xFFFEE2E2);
      }
    } else if (isWrongTried) {
      border = const Color(0xFFDC2626);
      bg = const Color(0xFFFEE2E2);
      label = const Color(0xFF9CA3AF);
    } else if (isSelected) {
      border = const Color(0xFF94A3B8);
      bg = const Color(0xFFF8FAFC);
    }

    final disabledTap = locked || isWrongTried;

    return InkWell(
      onTap: disabledTap ? null : onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Opacity(
        opacity: disabledTap ? 0.9 : 1,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              _choiceNumber(
                index + 1,
                disabledTap ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: label,
                  ),
                ),
              ),
            ],
          ),
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

  Widget _hintBanner(String text) {
    return Container(
      key: const ValueKey('hintBanner'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3BF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF7C5B00)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: const Color(0xFF7C5B00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

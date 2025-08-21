// lib/screens/story/story_test_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  const StoryTestPage({
    super.key,
    required this.title,
    required this.storyImg,
  });

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
  int _tries = 0;                       // 0 또는 1
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
      final byCategory = <String, _CategoryStat>{};
      final byType = <String, _CategoryStat>{};

      _CategoryStat _add(Map<String, _CategoryStat> m, String key, bool correct) {
        final cur = m[key];
        final next = _CategoryStat(
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
        return '기타'; // 결과 카드에는 미표시
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
        final bc = _baseCat(_questions[i].category);
        _add(byCategory, bc, ok);
        final t = _typeCat(_questions[i].category);
        if (t != null) _add(byType, t, ok);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _StoryResultPage(
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
                                builder: (context, c) => Stack(
                                  children: [
                                    Container(width: c.maxWidth, color: const Color(0xFFE5E7EB)),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
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
                      child: (_tries == 1 && !_locked && _secondsLeft > 0)
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
      floatingActionButton: _locked
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
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp),
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
          child: src.startsWith('http')
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
              _choiceNumber(index + 1, disabledTap ? const Color(0xFF9CA3AF) : const Color(0xFF111827)),
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

// =========================
// 결과 페이지 (한 파일 내 선언)
// =========================

class _CategoryStat {
  final int correct;
  final int total;
  const _CategoryStat({required this.correct, required this.total});

  double get correctRatio => total == 0 ? 0 : correct / total;
  double get riskRatio => 1 - correctRatio; // 0(양호) ~ 1(위험)
}

class _StoryResultPage extends StatelessWidget {
  final int score;
  final int total;
  final Map<String, _CategoryStat> byCategory; // 요구/질문/단언/의례화/기타
  final Map<String, _CategoryStat> byType; // 직접/간접/질문/단언/의례화
  final DateTime testedAt;

  const _StoryResultPage({
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    required this.testedAt,
  });

  @override
  Widget build(BuildContext context) {
    final overall = total == 0 ? 0.0 : score / total;
    final showWarn = overall < 0.5;

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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Column(
            children: [
              _attemptChip(testedAt),
              SizedBox(height: 12.h),

              // 카드: 점수 요약 + 카테고리 바 4개
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('인지검사 결과',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4.h),
                    Text('검사 결과 요약입니다.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        )),
                    SizedBox(height: 14.h),
                    _scoreCircle(score, total),
                    SizedBox(height: 16.h),
                    _riskBarRow('요구', byCategory['요구']),
                    SizedBox(height: 12.h),
                    _riskBarRow('질문', byCategory['질문']),
                    SizedBox(height: 12.h),
                    _riskBarRow('단언', byCategory['단언']),
                    SizedBox(height: 12.h),
                    _riskBarRow('의례화', byCategory['의례화']),
                  ],
                ),
              ),

              SizedBox(height: 14.h),

              // 카드: 검사 결과 평가
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('검사 결과 평가',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900)),
                    SizedBox(height: 12.h),
                    if (showWarn) _warnBanner(),
                    ..._buildEvalItems(byType).expand((w) => [w, SizedBox(height: 10.h)]),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 맨 아래: 게임으로 이동(모양만)
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: null, // 모양만 구현
                  icon: const Icon(Icons.videogame_asset_rounded),
                  label: Text(
                    '두뇌 게임으로 이동',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: const Color(0xFFFFD43B),
                    disabledForegroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 위젯 유틸 ---
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _attemptChip(DateTime dt) {
    final s =
        '${dt.year}년 ${dt.month.toString().padLeft(2, '0')}월 ${dt.day.toString().padLeft(2, '0')}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('1회차',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.sp,
                color: AppColors.btnColorDark,
              )),
          SizedBox(width: 10.w),
          Text(s,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                color: const Color(0xFF111827),
              )),
        ],
      ),
    );
  }

  Widget _scoreCircle(int score, int total) {
    return SizedBox(
      width: 140.w,
      height: 140.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF4444), width: 8),
              color: Colors.white,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$score',
                  style: TextStyle(
                    fontSize: 48.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFEF4444),
                    height: 0.9,
                  )),
              Text('/$total',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFEF4444),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskBarRow(String label, _CategoryStat? stat) {
    final eval = _evalFromStat(stat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _riskBar(eval.position)),
            SizedBox(width: 10.w),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.sp,
                    color: const Color(0xFF4B5563))),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: eval.badgeBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: eval.badgeBorder),
              ),
              child: Text(
                eval.text,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.sp,
                  color: eval.textColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _riskBar(double position) {
    // position: 0(양호, 녹색) ~ 1(매우 주의, 빨강)
    return SizedBox(
      height: 16.h,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: w,
              height: 6.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF10B981), // green
                  Color(0xFFF59E0B), // amber
                  Color(0xFFEF4444), // red
                ]),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Positioned(
              left: (w - 18.w) * position,
              child: Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF9CA3AF), width: 2),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _warnBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '인지 기능 저하가 의심됩니다. 전문가와 상담을 권장합니다.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.sp,
                color: const Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 낮은 항목(정답률 < 50%)만 평가 블록 노출
  List<Widget> _buildEvalItems(Map<String, _CategoryStat> t) {
    final items = <Widget>[];

    void addIfLow(String key, String title, String body) {
      final s = t[key];
      if (s == null || s.total == 0) return;
      if (s.correctRatio < 0.5) {
        items.add(_evalBlock('[$title]이 부족합니다.', body));
      }
    }

    addIfLow('직접화행', '직접화행',
        '화자의 의도를 직접적으로 파악하는 능력이 부족합니다. 기본 대화 예시를 활용한 반응 훈련이 필요합니다.');
    addIfLow('간접화행', '간접화행',
        '맥락을 통해 간접적으로 표현된 의도를 해석하는 능력이 미흡합니다. 상황 추론 중심 활동으로 보완하세요.');
    addIfLow('질문화행', '질문화행',
        '질문 의도 파악과 정보 판단이 부족합니다. 핵심 정보 찾기·질문 재구성 훈련을 권장합니다.');
    addIfLow('단언화행', '단언화행',
        '상황에 맞는 진술/감정의 의미 이해가 낮습니다. 상황-의도 매칭 활동으로 개선이 가능합니다.');
    addIfLow('의례화화행', '의례화화행',
        '인사/감사 등 예절적 표현의 의도 이해가 낮습니다. 일상 의례 표현 반복 노출로 강화하세요.');

    if (items.isEmpty) {
      items.add(_evalBlock('전반적으로 양호합니다.', '필요 시 추가 학습을 통해 안정적인 이해를 유지해 보세요.'));
    }
    return items;
  }

  Widget _evalBlock(String title, String body) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14.sp,
                color: const Color(0xFF111827),
              )),
          SizedBox(height: 6.h),
          Text(
            body,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
              color: const Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  _EvalView _evalFromStat(_CategoryStat? s) {
    if (s == null || s.total == 0) {
      return _EvalView(
        text: '데이터 없음',
        textColor: const Color(0xFF6B7280),
        badgeBg: const Color(0xFFF3F4F6),
        badgeBorder: const Color(0xFFE5E7EB),
        position: 0.5,
      );
    }
    final risk = s.riskRatio; // 0~1
    if (risk >= 0.75) {
      return _EvalView(
        text: '매우 주의',
        textColor: const Color(0xFFB91C1C),
        badgeBg: const Color(0xFFFFE4E6),
        badgeBorder: const Color(0xFFFCA5A5),
        position: risk,
      );
    } else if (risk >= 0.5) {
      return _EvalView(
        text: '주의',
        textColor: const Color(0xFFDC2626),
        badgeBg: const Color(0xFFFFEBEE),
        badgeBorder: const Color(0xFFFECACA),
        position: risk,
      );
    } else if (risk >= 0.25) {
      return _EvalView(
        text: '보통',
        textColor: const Color(0xFF92400E),
        badgeBg: const Color(0xFFFFF7ED),
        badgeBorder: const Color(0xFFFCD34D),
        position: risk,
      );
    } else {
      return _EvalView(
        text: '양호',
        textColor: const Color(0xFF065F46),
        badgeBg: const Color(0xFFECFDF5),
        badgeBorder: const Color(0xFF6EE7B7),
        position: risk,
      );
    }
  }
}

class _EvalView {
  final String text;
  final Color textColor;
  final Color badgeBg;
  final Color badgeBorder;
  final double position; // 0~1
  _EvalView({
    required this.text,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.position,
  });
}

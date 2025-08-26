import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

// 프로젝트 실제 페이지/테마 사용
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'interview_session.dart'; // ← 추가: 세션 완료 마킹

// ★ 서버 베이스 URL (에뮬레이터 사용 시)
const String API_BASE = 'http://10.0.2.2:4000/str';

/// 카테고리 집계용
class CategoryStat {
  final int correct;
  final int total;
  const CategoryStat({required this.correct, required this.total});

  double get correctRatio => total == 0 ? 0 : correct / total;
  double get riskRatio => 1 - correctRatio; // 0(좋음) ~ 1(위험)
}

/// 결과 페이지
class StoryResultPage extends StatefulWidget {
  final int score;
  final int total;
  final Map<String, CategoryStat> byCategory; // 요구/질문/단언/의례화
  final Map<String, CategoryStat> byType; // 직접화행/간접화행/질문화행/단언화행/의례화화행
  final DateTime testedAt;

  /// (선택) 진행한 제목
  final String? storyTitle;

  const StoryResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    required this.testedAt,
    this.storyTitle,
  });

  @override
  State<StoryResultPage> createState() => _StoryResultPageState();
}

class _StoryResultPageState extends State<StoryResultPage> {
  bool _posted = false;

  @override
  void initState() {
    super.initState();

    // ✅ 결과 페이지 진입 = 이번 회차 완료 마킹(다음 번 리스트 진입 시 초기화)
    InterviewSession.markCompleted();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postAttemptTimeOnce();
    });
  }

  Future<void> _postAttemptTimeOnce() async {
    if (_posted) return;
    _posted = true;

    try {
      final uri = Uri.parse('$API_BASE/attempt');

      // UTC ISO 형식
      final measuredAtIso = widget.testedAt.toUtc().toIso8601String();

      // 사람이 보기 좋은 KST 문자열(확인용)
      final clientKst = _formatKst(widget.testedAt);

      final body = jsonEncode({
        'attemptTime': measuredAtIso,
        'clientKst': clientKst,
        'storyTitle': widget.storyTitle,
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint(
        '[STR] attempt POST status=${res.statusCode} body=${res.body}',
      );
    } catch (e) {
      debugPrint('[STR] attempt POST error: $e');
    }
  }

  // ---- KST(Asia/Seoul) 변환 & 포맷 ----
  String _formatKst(DateTime dt) {
    final kst = dt.toUtc().add(const Duration(hours: 9));
    final y = kst.year;
    final m = kst.month.toString().padLeft(2, '0');
    final d = kst.day.toString().padLeft(2, '0');
    final hh = kst.hour.toString().padLeft(2, '0');
    final mm = kst.minute.toString().padLeft(2, '0');
    return '$y년 $m월 $d일 $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final overall = widget.total == 0 ? 0.0 : widget.score / widget.total;
    final showWarn = overall < 0.5;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '인지 검사',
          style: TextStyle(
            fontFamily: 'GmarketSans',
            fontWeight: FontWeight.w600, // 얇게
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Column(
            children: [
              _attemptChip(_formatKst(widget.testedAt)),
              SizedBox(height: 12.h),

              // 카드: 점수 요약 + 카테고리 바 4개
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '인지검사 결과',
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '검사 결과 요약입니다.',
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontSize: 13.sp,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500, // 안내문 얇게
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _scoreCircle(widget.score, widget.total),

                    SizedBox(height: 16.h),
                    _riskBarRow('요구', widget.byCategory['요구']),
                    SizedBox(height: 12.h),
                    _riskBarRow('질문', widget.byCategory['질문']),
                    SizedBox(height: 12.h),
                    _riskBarRow('단언', widget.byCategory['단언']),
                    SizedBox(height: 12.h),
                    _riskBarRow('의례화', widget.byCategory['의례화']),
                  ],
                ),
              ),

              SizedBox(height: 14.h),

              // 카드: 검사 결과 평가 (표의 6개 지표 고정 설명)
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '검사 결과 평가',
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    if (showWarn) _warnBanner(),

                    // 6개 지표 설명을 모두 노출
                    ..._buildEvalItems(
                      widget.byType,
                    ).expand((w) => [w, SizedBox(height: 10.h)]),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 맨 아래: 두뇌 게임으로 이동
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const BrainTrainingMainPage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD43B),
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    '두뇌 게임으로 이동',
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w400, // 얇게
                      fontSize: 16.sp,
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
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
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _attemptChip(String formattedKst) {
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
          Text(
            '1회차',
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
              color: AppColors.btnColorDark,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            formattedKst,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w500,
              fontSize: 13.sp,
              color: const Color(0xFF111827),
            ),
          ),
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
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 46.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                  height: 0.9,
                ),
              ),
              Text(
                '/$total',
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskBarRow(String label, CategoryStat? stat) {
    final eval = _evalFromStat(stat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _riskBar(eval.position)),
            SizedBox(width: 10.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GmarketSans',
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
                color: const Color(0xFF4B5563),
              ),
            ),
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
                  fontFamily: 'GmarketSans',
                  fontWeight: FontWeight.w700,
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
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: w,
                height: 6.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF10B981), // green
                      Color(0xFFF59E0B), // amber
                      Color(0xFFEF4444), // red
                    ],
                  ),
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
                    border: Border.all(
                      color: const Color(0xFF9CA3AF),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
                fontFamily: 'GmarketSans',
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
                color: const Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 표 기준 6개 지표 설명 고정 노출
  List<Widget> _buildEvalItems(Map<String, CategoryStat> _) {
    return <Widget>[
      _evalBlock(
        '[반응 시간]',
        '질문 종료 시점부터 응답 시작까지의 시간을 측정합니다. '
            '예) 3초 이내: 상점 / 4–6초: 보통 / 7초 이상: 주의.',
      ),
      _evalBlock(
        '[반복어 비율]',
        '동일 단어·문장이 반복되는 비율입니다. '
            '예) 5% 이하: 상점 / 10% 이하: 보통 / 20% 이상: 주의.',
      ),
      _evalBlock(
        '[평균 문장 길이]',
        '응답의 평균 단어(또는 음절) 수를 봅니다. '
            '적정 범위(예: 15±5어)는 양호, 지나치게 짧거나 긴 경우 감점.',
      ),
      _evalBlock(
        '[화행 적절성 점수]',
        '질문 맥락과 응답 화행의 매칭(적합/비적합)을 판정합니다. '
            '예) 적합 12회: 상점 / 6회: 보통 / 0회: 주의.',
      ),
      _evalBlock(
        '[회상어 점수]',
        '사람·장소·사건 등 회상 관련 키워드 포함과 풍부성을 평가합니다. '
            '키워드 다수 포함: 상점 / 부족: 보통 / 없음: 주의.',
      ),
      _evalBlock(
        '[문법 완성도]',
        '비문 여부, 조사·부착, 주어·서술어 일치 등 문법적 오류를 분석합니다. '
            '오류 없음: 상점 / 일부 오류: 보통 / 잦은 오류: 주의.',
      ),
    ];
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
          Text(
            title,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w500, // 본문 얇게
              fontSize: 13.sp,
              color: const Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  _EvalView _evalFromStat(CategoryStat? s) {
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

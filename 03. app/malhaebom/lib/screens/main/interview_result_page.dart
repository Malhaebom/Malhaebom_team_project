import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'interview_session.dart';

const String API_BASE = 'http://10.0.2.2:4000/str';

const TextScaler fixedScale = TextScaler.linear(1.0);

/// 카테고리 집계
class CategoryStat {
  final int correct;
  final int total;
  const CategoryStat({required this.correct, required this.total});

  double get correctRatio => total == 0 ? 0 : correct / total;
  double get riskRatio => 1 - correctRatio;
}

/// 인터뷰 결과 페이지
class InterviewResultPage extends StatefulWidget {
  final int score;
  final int total;
  final Map<String, CategoryStat> byCategory;
  final Map<String, CategoryStat> byType;
  final DateTime testedAt;
  final String? interviewTitle;

  const InterviewResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    required this.testedAt,
    this.interviewTitle,
  });

  @override
  State<InterviewResultPage> createState() => _InterviewResultPageState();
}

class _InterviewResultPageState extends State<InterviewResultPage> {
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    // 회차 완료 처리(로컬 캐시 정리)
    InterviewSession.markCompleted();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postAttemptOnce();
    });
  }

  Future<void> _postAttemptOnce() async {
    if (_posted) return;
    _posted = true;

    try {
      final uri = Uri.parse('$API_BASE/attempt');
      final measuredAtIso = widget.testedAt.toUtc().toIso8601String();
      final clientKst = _formatKst(widget.testedAt);

      final body = jsonEncode({
        'attemptTime': measuredAtIso,
        'clientKst': clientKst,
        'interviewTitle': widget.interviewTitle,
        'score': widget.score,
        'total': widget.total,
        'byCategory': widget.byCategory.map(
          (k, v) => MapEntry(k, {'correct': v.correct, 'total': v.total}),
        ),
        'byType': widget.byType.map(
          (k, v) => MapEntry(k, {'correct': v.correct, 'total': v.total}),
        ),
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      // ignore: avoid_print
      print('[INTV] POST /attempt -> ${res.statusCode} ${res.body}');
    } catch (e) {
      // ignore: avoid_print
      print('[INTV] POST /attempt error: $e');
    }
  }

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
    // ✅ 페이지 전체 글자 크기 고정
    final fixedMedia = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    final overall = widget.total == 0 ? 0.0 : widget.score / widget.total;
    final showWarn = overall < 0.5;

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return MediaQuery(
      data: fixedMedia,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: _appBarH(context),
          title: Text(
            '화행 인지검사',
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
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

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '인지검사 결과',
                        style: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '검사 결과 요약입니다.',
                        style: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontSize: 18.sp,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      _scoreCircle(widget.score, widget.total),

                      SizedBox(height: 16.h),
                      _riskBarRow('반응 시간', widget.byCategory['반응 시간']),
                      SizedBox(height: 12.h),
                      _riskBarRow('반복어 비율', widget.byCategory['반복어 비율']),
                      SizedBox(height: 12.h),
                      _riskBarRow('평균 문장 길이', widget.byCategory['평균 문장 길이']),
                      SizedBox(height: 12.h),
                      _riskBarRow('화행 적절성', widget.byCategory['화행 적절성']),
                      SizedBox(height: 12.h),
                      _riskBarRow('회상어 점수', widget.byCategory['회상어 점수']),
                      SizedBox(height: 12.h),
                      _riskBarRow('문법 완성도', widget.byCategory['문법 완성도']),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '검사 결과 평가',
                        style: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      if (showWarn) _warnBanner(),
                      ..._buildEvalItems(
                        widget.byType,
                      ).expand((w) => [w, SizedBox(height: 10.h)]),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const BrainTrainingMainPage(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: Icon(
                      Icons.videogame_asset_rounded,
                      size: 22.sp * 1.25,
                    ), // 아이콘 포함
                    label: Text(
                      '두뇌 게임으로 이동',
                      textScaler: fixedScale, // 시스템 글꼴 배율 무시
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w900, // 두 번째 파일과 동일 굵기
                        fontSize: 22.sp, // 두 번째 파일과 동일 크기
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD43B),
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----- UI 유틸 -----

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
            textScaler: fixedScale,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w900,
              fontSize: 18.sp,
              color: AppColors.btnColorDark,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            formattedKst,
            textScaler: fixedScale, // ← 시스템 글씨 키워도 여기선 고정
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 점수 원: 내부 숫자/분모 모두 컨테이너 크기 비례 + 스케일 고정
  Widget _scoreCircle(int score, int total) {
    final double d = 140.w; // 원 지름
    final double big = d * 0.40; // 큰 숫자 폰트
    final double small = d * 0.20; // /분모 폰트

    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: d,
            height: d,
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
                textScaler: fixedScale,
                strutStyle: StrutStyle(
                  forceStrutHeight: true,
                  height: 1,
                  fontSize: big,
                ),
                style: TextStyle(
                  fontSize: big,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                ),
              ),
              Text(
                '/$total',
                textScaler: fixedScale,
                strutStyle: StrutStyle(
                  forceStrutHeight: true,
                  height: 1,
                  fontSize: small,
                ),
                style: TextStyle(
                  fontSize: small,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
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
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
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
                  fontWeight: FontWeight.w900,
                  fontSize: 17.sp,
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
              '인지 기능 저하가 의심됩니다.\n전문가와 상담을 권장합니다.',
              style: TextStyle(
                fontFamily: 'GmarketSans',
                fontWeight: FontWeight.w600,
                fontSize: 19.sp,
                color: const Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEvalItems(Map<String, CategoryStat> _) {
    return <Widget>[
      _evalBlock(
        '[반응 시간]',
        '반복어 비율 종료 시점부터 응답 시작까지의 시간을 측정합니다. '
            '예) 3초 이내: 상점 / 4-6초: 보통 / 7초 이상: 주의.',
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
        '반복어 비율 맥락과 응답 화행의 매칭(적합/비적합)을 판정합니다. '
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
              fontWeight: FontWeight.w900,
              fontSize: 20.sp,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 19.sp,
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

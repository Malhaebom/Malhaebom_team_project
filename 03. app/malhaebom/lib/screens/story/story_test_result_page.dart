import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
// import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart'; // <- 네가 추가

/// 카테고리 집계용
class CategoryStat {
  final int correct;
  final int total;
  const CategoryStat({required this.correct, required this.total});

  double get correctRatio => total == 0 ? 0 : correct / total;
  double get riskRatio => 1 - correctRatio; // 0(좋음) ~ 1(위험)
}

/// 결과 페이지
class StoryResultPage extends StatelessWidget {
  final int score;
  final int total;
  final Map<String, CategoryStat> byCategory; // 요구/질문/단언/의례화
  final Map<String, CategoryStat> byType; // 직접화행/간접화행/질문화행/단언화행/의례화화행
  final DateTime testedAt;

  /// 선택: 어떤 동화로 테스트했는지 제목 표시하고 싶으면 넘겨줘
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

  // ---- KST(Asia/Seoul) 변환 & 포맷 ----
  String _formatKst(DateTime dt) {
    // 어떤 타임존에서 들어와도 UTC로 환산 후 +9h 하여 KST로 표시
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
              _attemptChip(_formatKst(testedAt)),
              SizedBox(height: 12.h),

              // 카드: 점수 요약 + 카테고리 바 4개
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '인지검사 결과',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '검사 결과 요약입니다.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    Text(
                      '검사 결과 평가',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    if (showWarn) _warnBanner(),

                    // 부족한 항목만 노출
                    ..._buildEvalItems(
                      byType,
                    ).expand((w) => [w, SizedBox(height: 10.h)]),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 맨 아래: 두뇌 게임으로 이동
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 결과 페이지를 대체하고 두뇌훈련 메인으로
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => BrainTrainingMainPage(),
                      ),
                      (route) => false,
                    );
                    // 만약 스택을 모두 비우고 이동하려면 위 대신 pushAndRemoveUntil 사용
                    // Navigator.of(context).pushAndRemoveUntil(
                    //   MaterialPageRoute(builder: (_) => BrainTrainingMainPage()),
                    //   (route) => false,
                    // );
                  },
                  icon: const Icon(Icons.videogame_asset_rounded),
                  label: Text(
                    '두뇌 게임으로 이동',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16.sp,
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
              fontWeight: FontWeight.w900,
              fontSize: 13.sp,
              color: AppColors.btnColorDark,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            formattedKst,
            style: TextStyle(
              fontWeight: FontWeight.w700,
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
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                  height: 0.9,
                ),
              ),
              Text(
                '/$total',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w800,
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

  List<Widget> _buildEvalItems(Map<String, CategoryStat> t) {
    final items = <Widget>[];
    void addIfLow(String key, String title, String body) {
      final s = t[key];
      if (s == null || s.total == 0) return;
      if (s.correctRatio < 0.5) {
        items.add(_evalBlock('[$title]이 부족합니다.', body));
      }
    }

    addIfLow(
      '직접화행',
      '직접화행',
      '기본 대화에 대한 이해가 부족하여 화자의 의도를 바로 파악하는 데 어려움이 보입니다. 대화 응용 훈련으로 개선할 수 있습니다.',
    );
    addIfLow(
      '간접화행',
      '간접화행',
      '간접적으로 표현된 의도를 해석하는 능력이 미흡합니다. 맥락 추론 훈련을 통해 보완이 필요합니다.',
    );
    addIfLow(
      '질문화행',
      '질문화행',
      '대화에서 주고받는 정보 판단과 질문 의도 파악이 부족합니다. 정보 파악 중심의 활동이 필요합니다.',
    );
    addIfLow(
      '단언화행',
      '단언화행',
      '상황에 맞는 감정/진술을 이해하고 표현 의도를 읽는 능력이 부족합니다. 상황·정서 파악 활동을 권합니다.',
    );
    addIfLow(
      '의례화화행',
      '의례화화행',
      '인사·감사 등 예절적 표현의 의도 이해가 낮습니다. 일상 의례 표현 중심의 학습을 권장합니다.',
    );

    if (items.isEmpty) {
      items.add(
        _evalBlock('전반적으로 양호합니다.', '필요 시 추가 학습을 통해 더 안정적인 이해를 유지해 보세요.'),
      );
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
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.sp,
              color: const Color(0xFF111827),
            ),
          ),
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

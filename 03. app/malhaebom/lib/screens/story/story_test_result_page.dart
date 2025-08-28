import 'dart:convert';
import 'dart:io' show Platform; // ★ 추가
import 'package:flutter/foundation.dart' show kIsWeb; // ★ 추가
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';

// ★ 서버 베이스 URL (dart-define > 자동감지)
final String API_BASE =
    (() {
      const defined = String.fromEnvironment('API_BASE', defaultValue: '');
      if (defined.isNotEmpty) return defined;

      if (kIsWeb) return 'http://localhost:4000'; // Flutter Web 디버그
      if (Platform.isAndroid) return 'http://10.0.2.2:4000'; // Android 에뮬레이터
      if (Platform.isIOS) return 'http://localhost:4000'; // iOS 시뮬레이터

      // 실기기 기본값: 같은 Wi-Fi의 PC IP로 바꿔 두세요.
      return 'http://192.168.0.23:4000';
    })();

// ✅ 버튼/칩/원 내부처럼 “넘치면 안 되는 컨테이너”에서 쓸 고정 스케일러
const TextScaler fixedScale = TextScaler.linear(1.0);

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _postAttemptTimeOnce());
  }

  Future<void> _postAttemptTimeOnce() async {
    if (_posted) return;
    _posted = true;

    try {
      final uri = Uri.parse('$API_BASE/attempt');
      final measuredAtIso = widget.testedAt.toUtc().toIso8601String();
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

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return Scaffold(
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
            color: AppColors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Column(
            children: [
              _attemptChip(_formatKst(widget.testedAt)), // ✅ 시간 텍스트 스케일 고정
              SizedBox(height: 12.h),

              // 카드: 점수 요약 + 카테고리 바 4개
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '인지검사 결과',
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '검사 결과 요약입니다.',
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontSize: 18.sp,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 14.h),

                    _scoreCircle(widget.score, widget.total), // ✅ 원 내부 텍스트 고정

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

              // 카드: 검사 결과 평가
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '검사 결과 평가',
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
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

              // 맨 아래: 두뇌 게임으로 이동
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: _brainCta(), // ✅ 아이콘/텍스트 함께 스케일 or 함께 고정
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

  // ✅ 시간 칩: 텍스트 스케일 고정 + 잘림 방지(한 줄/ellipsis)
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
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
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
                textScaler: fixedScale, // 뱃지 내부도 넘침 방지
                style: TextStyle(
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
              '인지 기능 저하가 의심됩니다.\n전문가와 상담을 권장합니다.',
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19.sp,
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
      if (s.correctRatio < 0.4) {
        items.add(_evalBlock('[$title]이 부족합니다.', body));
      }
    }

    addIfLow(
      '직접화행',
      '직접화행',
      '기본 대화에 대한 이해가 부족하여 화자의 의도를 바로 파악하는 데\n어려움이 보입니다. 대화 응용\n훈련으로 개선할 수 있습니다.',
    );
    addIfLow(
      '간접화행',
      '간접화행',
      '간접적으로 표현된 의도를 해석하는 능력이 미흡합니다. 맥락 추론\n훈련을 통해 보완이 필요합니다.',
    );
    addIfLow(
      '질문화행',
      '질문화행',
      '대화에서 주고받는 정보 판단과 질문\n의도 파악이 부족합니다. 정보 파악\n중심의 활동이 필요합니다.',
    );
    addIfLow(
      '단언화행',
      '단언화행',
      '상황에 맞는 감정/진술을\n이해하고 표현 의도를\n읽는 능력이 부족합니다.\n상황·정서 파악 활동을 권합니다.',
    );
    addIfLow(
      '의례화화행',
      '의례화화행',
      '인사·감사 등 예절적 표현의 의도\n이해가 낮습니다. 일상 의례 표현\n중심의 학습을 권장합니다.',
    );

    if (items.isEmpty) {
      items.add(
        _evalBlock('전반적으로 양호합니다.', '필요 시 추가 학습을 통해 더\n안정적인 이해를 유지해 보세요.'),
      );
    }
    return items;
  }

  Widget _evalBlock(String title, String body) {
    return Container(
      width: double.infinity,
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
            textScaler: const TextScaler.linear(1.0),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20.sp,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            body,
            textScaler: const TextScaler.linear(1.0),
            style: TextStyle(
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

  // ✅ 아이콘/텍스트를 함께 고정 스케일로 맞추고, 아이콘 크기를 폰트에 연동
  Widget _brainCta() {
    final double font = 22.sp;
    final double iconSize = font * 1.25; // 텍스트 대비 살짝 크게

    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BrainTrainingMainPage()),
          (route) => false,
        );
      },
      icon: Icon(Icons.videogame_asset_rounded, size: iconSize),
      label: Text(
        '두뇌 게임으로 이동',
        textScaler: fixedScale,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: font),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFD43B),
        foregroundColor: Colors.black,
        shape: const StadiumBorder(),
        elevation: 0,
      ),
    );
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

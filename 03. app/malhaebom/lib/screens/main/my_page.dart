// lib/screens/main/my_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/main/interview_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/back_to_home.dart';
import 'package:malhaebom/screens/users/login_page.dart';

// 결과 상세 페이지의 CategoryStat 타입을 그대로 사용
import 'package:malhaebom/screens/main/interview_result_page.dart' as ir;

import 'result_history_page.dart';

const TextScaler _fixedScale = TextScaler.linear(1.0);

// 로컬 저장 키
const String PREF_LATEST_ATTEMPT = 'latest_attempt_v1';
const String PREF_ATTEMPT_COUNT = 'attempt_count_v1';

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with TickerProviderStateMixin {
  final List<String> title = ["회원정보 수정하기", "로그아웃", "자주 묻는 질문"];
  final List<Icon> icon = const [
    Icon(Icons.edit, color: AppColors.text, size: 26),
    Icon(Icons.logout, color: AppColors.text, size: 26),
    Icon(Icons.question_answer, color: AppColors.text, size: 26),
  ];

  // 로컬 캐시만 사용 (빠르게 바로 그림)
  AttemptSummary? _latest;
  int _attemptCount = 0;
  bool _loading = true;

  // 접힘/펼침 상태
  bool _isReportExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadLatest(); // 로컬에서 바로 읽음
  }

  Future<void> _loadLatest() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    // latest
    AttemptSummary? latest;
    final s = prefs.getString(PREF_LATEST_ATTEMPT);
    if (s != null && s.isNotEmpty) {
      try {
        latest = AttemptSummary.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }

    // count
    final cnt = prefs.getInt(PREF_ATTEMPT_COUNT) ?? (latest == null ? 0 : 1);

    setState(() {
      _latest = latest;
      _attemptCount = cnt;
      _loading = false;
    });
  }

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final fixedMedia = MediaQuery.of(context).copyWith(textScaler: _fixedScale);

    return BackToHome(
      child: MediaQuery(
        data: fixedMedia,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadLatest,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
                child: Column(
                  children: [
                    // ===== 설정 섹션 =====
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            SizedBox(height: 5.h),
                            Row(
                              children: [
                                SizedBox(width: 10.w),
                                Text(
                                  "설정",
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 26.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: List.generate(title.length, (index) {
                                return InkWell(
                                  onTap: () async {
                                    if (title[index] == "로그아웃") {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.clear();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("로그아웃 되었습니다."),
                                        ),
                                      );
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginPage(),
                                        ),
                                        (route) => false,
                                      );
                                    } else if (title[index] == "회원정보 수정하기") {
                                      // TODO
                                    } else if (title[index] == "자주 묻는 질문") {
                                      // TODO
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey,
                                          width: 1.w,
                                        ),
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.h,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              SizedBox(width: 10.w),
                                              icon[index],
                                              SizedBox(width: 5.w),
                                              Flexible(
                                                child: Text(
                                                  title[index],
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 22.sp,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.navigate_next,
                                          size: 40.h,
                                          color: AppColors.text,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                            SizedBox(height: 15.h),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // ===== 나의 인지 리포트 (접힘/펼침) =====
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            SizedBox(height: 5.h),

                            // --- 헤더 (탭으로 펼치기) ---
                            // 기존 Row 하나짜리 헤더 → 2줄(Column)로 변경
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(
                                () => _isReportExpanded = !_isReportExpanded,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1줄: 타이틀 (좌측 정렬)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                      ),
                                      child: Text(
                                        "나의 인지 리포트",
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 26.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 6.h),

                                    // 2줄: 우측 정렬(이전 기록 보기 + 화살표)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const ResultHistoryPage(),
                                              ),
                                            );
                                            if (!mounted) return;
                                            _loadLatest();
                                          },
                                          icon: const Icon(Icons.history),
                                          label: const Text("이전 기록 보기"),
                                        ),
                                        SizedBox(width: 4.w),
                                        AnimatedRotation(
                                          duration:
                                              const Duration(milliseconds: 200),
                                        turns: _isReportExpanded ? 0.5 : 0.0,
                                          child: const Icon(Icons.expand_more),
                                        ),
                                        SizedBox(width: 6.w),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // --- 펼쳐지는 내용 ---
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 220),
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: _loading
                                    ? _skeleton()
                                    : (_latest == null
                                        ? _emptyLatest(context)
                                        : _latestCard(
                                            context,
                                            _latest!,
                                            _attemptCount,
                                          )),
                              ),
                              crossFadeState: _isReportExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====== 비어있을 때 (멘트 개선) ======
  Widget _emptyLatest(BuildContext context) {
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_alt_outlined,
            size: 40.sp,
            color: AppColors.text,
          ),
          SizedBox(height: 10.h),
          Text(
            '첫 검사를 아직 안 하셨어요',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20.sp,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '3분이면 끝나요 🙂 지금 검사하러 가볼까요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16.sp,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InterviewListPage()),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('검사 시작하기'),
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
    );
  }

  // ====== 스켈레톤 ======
  Widget _skeleton() => Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(6, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Container(
                height: 18.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }),
        ),
      );

  // ====== 최신 결과 카드 ======
  Widget _latestCard(
      BuildContext context, AttemptSummary a, int attemptCount) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // === 가운데 정렬된 헤더(회차 배지 + 제목) ===
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (attemptCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      '${attemptCount}회차',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                        color: const Color(0xFF374151),
                        fontFamily: 'GmarketSans',
                      ),
                    ),
                  ),
                if (attemptCount > 0) SizedBox(width: 8.w),
                Text(
                  '인지검사 결과',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 22.sp,
                    fontFamily: 'GmarketSans',
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // 날짜/라벨도 가운데 정렬
          Text(
            a.kstLabel ?? '최근 검사 요약입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              fontFamily: 'GmarketSans',
            ),
          ),

          SizedBox(height: 12.h),
          _scoreCircle(a.score, a.total),
          SizedBox(height: 12.h),
          _riskBarRow('반응 시간', a.byCategory['반응 시간']),
          SizedBox(height: 10.h),
          _riskBarRow('반복어 비율', a.byCategory['반복어 비율']),
          SizedBox(height: 10.h),
          _riskBarRow('평균 문장 길이', a.byCategory['평균 문장 길이']),
          SizedBox(height: 10.h),
          _riskBarRow('화행 적절성', a.byCategory['화행 적절성']),
          SizedBox(height: 10.h),
          _riskBarRow('회상어 점수', a.byCategory['회상어 점수']),
          SizedBox(height: 10.h),
          _riskBarRow('문법 완성도', a.byCategory['문법 완성도']),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ir.InterviewResultPage(
                      score: a.score,
                      total: a.total,
                      byCategory: a.byCategory,
                      byType: a.byType ?? <String, ir.CategoryStat>{},
                      testedAt: a.testedAt ?? DateTime.now(),
                      interviewTitle: a.interviewTitle,
                      persist: false, // 상세 보기 진입 시 회차 증가 방지
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('자세히 보기'),
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
    );
  }

  // ====== 요약 카드에 필요한 유틸 ======
  Widget _riskBarRow(String label, ir.CategoryStat? stat) {
    final ev = _evalFromStat(stat);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _riskBar(ev.position)),
        SizedBox(width: 10.w),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16.sp,
            color: const Color(0xFF4B5563),
            fontFamily: 'GmarketSans',
          ),
        ),
        SizedBox(width: 6.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: ev.badgeBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ev.badgeBorder),
          ),
          child: Text(
            ev.text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.sp,
              color: ev.textColor,
              fontFamily: 'GmarketSans',
            ),
          ),
        ),
      ],
    );
  }

  Widget _riskBar(double position) => SizedBox(
        height: 16.h,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(alignment: Alignment.centerLeft, children: [
            Container(
              width: w,
              height: 6.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)]),
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
                    border: Border.all(color: const Color(0xFF9CA3AF), width: 2)),
              ),
            ),
          ]);
        }),
      );

  Widget _scoreCircle(int score, int total) {
    final double d = 120.w;
    final double big = d * 0.40;
    final double small = d * 0.20;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEF4444), width: 8),
                color: Colors.white)),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$score',
              textScaler: _fixedScale,
              style: TextStyle(
                  fontSize: big,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                  fontFamily: 'GmarketSans')),
          Text('/$total',
              textScaler: _fixedScale,
              style: TextStyle(
                  fontSize: small,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                  fontFamily: 'GmarketSans')),
        ]),
      ]),
    );
  }

  _EvalView _evalFromStat(ir.CategoryStat? s) {
    if (s == null || s.total == 0) {
      return _EvalView(
        text: '데이터 없음',
        textColor: const Color(0xFF6B7280),
        badgeBg: const Color(0xFFF3F4F6),
        badgeBorder: const Color(0xFFE5E7EB),
        position: 0.5,
      );
    }
    final risk = s.riskRatio;
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

// ===== 모델 =====
class AttemptSummary {
  final int score;
  final int total;
  final Map<String, ir.CategoryStat> byCategory;
  final Map<String, ir.CategoryStat>? byType;
  final DateTime? testedAt;
  final String? kstLabel;
  final String? interviewTitle;

  AttemptSummary({
    required this.score,
    required this.total,
    required this.byCategory,
    this.byType,
    this.testedAt,
    this.kstLabel,
    this.interviewTitle,
  });

  factory AttemptSummary.fromJson(Map<String, dynamic> j) {
    Map<String, ir.CategoryStat> _mapStats(dynamic x) {
      if (x is Map) {
        final out = <String, ir.CategoryStat>{};
        x.forEach((key, val) {
          if (val is Map) {
            final correct = (val['correct'] as num?)?.toInt() ?? 0;
            final total = (val['total'] as num?)?.toInt() ?? 0;
            out[key.toString()] = ir.CategoryStat(
              correct: correct,
              total: total,
            );
          }
        });
        return out;
      }
      return <String, ir.CategoryStat>{};
    }

    DateTime? ts;
    final rawTs = j['attemptTime'] ?? j['testedAt'] ?? j['createdAt'];
    if (rawTs is String) ts = DateTime.tryParse(rawTs);

    return AttemptSummary(
      score: (j['score'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      byCategory: _mapStats(j['byCategory']),
      byType: _mapStats(j['byType']),
      testedAt: ts,
      kstLabel: j['clientKst'] as String?,
      interviewTitle: j['interviewTitle'] as String?,
    );
  }
}

class _EvalView {
  final String text;
  final Color textColor;
  final Color badgeBg;
  final Color badgeBorder;
  final double position;
  _EvalView({
    required this.text,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.position,
  });
}

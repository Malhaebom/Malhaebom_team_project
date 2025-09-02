// lib/screens/main/interview_result_page.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'interview_session.dart';

// --- 서버 전송 스위치 & 베이스 URL ---
const bool kUseServer = bool.fromEnvironment('USE_SERVER', defaultValue: true);

final String API_BASE = (() {
  const defined = String.fromEnvironment('API_BASE', defaultValue: '');
  if (defined.isNotEmpty) return defined;
  // ✅ 기본값을 공인 IP로 통일 (에뮬레이터/로컬 분기 제거)
  return 'http://211.188.63.38:4000';
})();

const TextScaler fixedScale = TextScaler.linear(1.0);

// 로컬 저장 키
const String PREF_LATEST_ATTEMPT = 'latest_attempt_v1';
const String PREF_ATTEMPT_COUNT = 'attempt_count_v1';

// ✅ 인지/동화 키 세트
const Set<String> kCognitionKeys = {
  '반응 시간',
  '반복어 비율',
  '평균 문장 길이',
  '화행 적절성',
  '회상어 점수',
  '문법 완성도',
};
const Set<String> kStoryKeys = {'요구', '질문', '단언', '의례화'};

// ===== 모델 =====
class CategoryStat {
  final int correct;
  final int total;
  const CategoryStat({required this.correct, required this.total});
  double get correctRatio => total == 0 ? 0 : correct / total;
  double get riskRatio => 1 - correctRatio;

  factory CategoryStat.fromJson(Map<String, dynamic> j) => CategoryStat(
        correct: (j['correct'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
      );
}

class InterviewResultPage extends StatefulWidget {
  final int score;
  final int total;
  final Map<String, CategoryStat> byCategory;
  final Map<String, CategoryStat> byType;
  final DateTime testedAt;
  final String? interviewTitle;
  final bool persist;
  final int? fixedAttemptOrder;
  final String? kstLabel; // ✅ 추가: 서버에서 받은 레이블 그대로 사용

  const InterviewResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    required this.testedAt,
    this.interviewTitle,
    this.persist = true,
    this.fixedAttemptOrder,
    this.kstLabel,
  });

  @override
  State<InterviewResultPage> createState() => _InterviewResultPageState();
}

class _InterviewResultPageState extends State<InterviewResultPage> {
  static const Duration _httpTimeout = Duration(seconds: 12);

  bool _posted = false;
  int _attemptOrder = 1; // 화면 표시용 회차

  @override
  void initState() {
    super.initState();
    if (widget.persist) {
      InterviewSession.markCompleted();
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOnce());
    } else {
      if (widget.fixedAttemptOrder != null) {
        _attemptOrder = widget.fixedAttemptOrder!;
      } else {
        _loadAttemptCountOnly();
      }
    }
  }

  // -------- 공통 헤더 --------
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('auth_token') ?? '').trim();
    String userKey = (prefs.getString('user_key') ?? '').trim();
    final loginId = (prefs.getString('login_id') ?? '').trim();
    if (userKey.isEmpty && loginId.isNotEmpty) {
      userKey = loginId;
      await prefs.setString('user_key', userKey);
    }
    return {
      'accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userKey.isNotEmpty) 'x-user-key': userKey,
    };
  }

  Future<void> _loadAttemptCountOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final cnt = prefs.getInt(PREF_ATTEMPT_COUNT) ?? 1;
    if (mounted) setState(() => _attemptOrder = cnt);
  }

  // ---------- 유틸: 맵에서 원하는 키만 추출 ----------
  Map<String, CategoryStat> _filterKeys(
    Map<String, CategoryStat> source,
    Set<String> allow,
  ) {
    final out = <String, CategoryStat>{};
    for (final k in source.keys) {
      if (allow.contains(k)) out[k] = source[k]!;
    }
    return out;
  }

  // ---------- 인지용 소스 ----------
  Map<String, CategoryStat> _buildCognitionSource() {
    final merged = <String, CategoryStat>{}
      ..addAll(widget.byCategory)
      ..addAll(widget.byType);
    return _filterKeys(merged, kCognitionKeys);
  }

  // ---------- 동화용 소스(타입별) ----------
  Map<String, CategoryStat> _buildStorySource() {
    final merged = <String, CategoryStat>{}
      ..addAll(widget.byCategory)
      ..addAll(widget.byType);
    return _filterKeys(merged, kStoryKeys);
  }

  // ---------- cognition riskBars(반드시 6키 모두 포함) ----------
  Map<String, double> _buildCognitionRiskBars(Map<String, CategoryStat> src) {
    final bars = <String, double>{};
    for (final key in kCognitionKeys) {
      final s = src[key];
      final v =
          (s == null || s.total == 0) ? 0.5 : (1 - (s.correct / s.total)).clamp(0.0, 1.0);
      bars[key] = v;
    }
    return bars;
  }

  // 공통 risk map
  Map<String, double> _riskMapFrom(Map<String, CategoryStat> m) {
    return m.map((k, v) => MapEntry(k, v.total == 0 ? 0.5 : (1 - v.correct / v.total).clamp(0.0, 1.0)));
  }

  Map<String, dynamic> _buildAttemptPayload({required int attemptOrder}) {
    final measuredAtIso = widget.testedAt.toUtc().toIso8601String();
    final clientKst = _formatKst(widget.testedAt);

    final cogSrc = _buildCognitionSource();
    final storySrc = _buildStorySource();

    final riskBars = _buildCognitionRiskBars(cogSrc);
    final riskBarsByType = _riskMapFrom(storySrc);

    int score = widget.score;
    int total = widget.total;
    if (total == 0) {
      total = cogSrc.values.fold(0, (s, e) => s + e.total);
      score = cogSrc.values.fold(0, (s, e) => s + e.correct);
    }

    return {
      'attemptOrder': attemptOrder,
      'clientAttemptOrder': attemptOrder, // ✅ 서버 호환 키 추가
      'attemptTime': measuredAtIso,
      'clientKst': clientKst,
      'interviewTitle': widget.interviewTitle,
      'score': score,
      'total': total,
      'byCategory': widget.byCategory.map((k, v) => MapEntry(k, {'correct': v.correct, 'total': v.total})),
      'byType': widget.byType.map((k, v) => MapEntry(k, {'correct': v.correct, 'total': v.total})),
      'riskBars': riskBars,
      'riskBarsByType': riskBarsByType,
    };
  }

  Future<void> _cacheLatestLocally(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PREF_LATEST_ATTEMPT, jsonEncode(payload));
  }

  Future<int> _bumpAttemptCount() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(PREF_ATTEMPT_COUNT) ?? 0) + 1;
    await prefs.setInt(PREF_ATTEMPT_COUNT, next);
    return next;
  }

  // (1) 유저키 로드 유틸
  Future<String> _loadUserKey() async {
    final prefs = await SharedPreferences.getInstance();
    final loginId = (prefs.getString('login_id') ?? '').trim();
    if (loginId.isNotEmpty) return loginId;
    final userKey = (prefs.getString('user_key') ?? '').trim();
    return userKey.isNotEmpty ? userKey : 'guest';
  }

  // (2) 서버로 내 신원 전달용(쿼리)
  Future<Map<String, String>> _identityForApi() async {
    final key = await _loadUserKey();
    if (key == 'guest' || key.isEmpty) return {};
    return {'userKey': key};
  }

  String _normTitle(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  // (3) 서버 최신 회차 → 다음 회차 계산 (헤더 포함)
  Future<int?> _serverNextAttempt(Map<String, String> identity) async {
    if (!kUseServer || identity.isEmpty) return null;
    try {
      final headers = await _authHeaders();
      final qp = {
        ...identity,
        if (_normTitle(widget.interviewTitle).isNotEmpty) 'title': _normTitle(widget.interviewTitle),
      };
      final uri = Uri.parse('$API_BASE/ir/latest').replace(queryParameters: qp);
      final res = await http.get(uri, headers: headers).timeout(_httpTimeout);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      if (j is! Map || j['ok'] != true) return null;
      final latest = j['latest'];
      if (latest is Map) {
        final ord = latest['clientAttemptOrder'] ?? latest['clientRound'] ?? latest['attemptOrder'];
        if (ord is num) return ord.toInt() + 1;
        return 1;
      }
      return 1;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendOnce() async {
    if (_posted) return;
    _posted = true;

    final idn = await _identityForApi();
    int next = (await _serverNextAttempt(idn)) ?? (await _bumpAttemptCount());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PREF_ATTEMPT_COUNT, next);
    } catch (_) {}
    if (mounted) setState(() => _attemptOrder = next);

    final payload = _buildAttemptPayload(attemptOrder: next);
    await _cacheLatestLocally(payload);

    if (!kUseServer) return;

    try {
      final headers = await _authHeaders()..['Content-Type'] = 'application/json; charset=utf-8';
      final userKey = idn['userKey'] ?? headers['x-user-key'] ?? '';
      final base = Uri.parse('$API_BASE/ir/attempt');
      final uri = userKey.isEmpty ? base : base.replace(queryParameters: {'userKey': userKey});

      final res = await http
          .post(uri, headers: headers, body: jsonEncode({...payload, if (userKey.isNotEmpty) 'userKey': userKey}))
          .timeout(_httpTimeout);

      // 서버가 최종 회차를 돌려주면 로컬 동기화
      try {
        final jr = jsonDecode(res.body);
        if (jr is Map) {
          final saved = jr['saved'];
          final ord = (saved is Map) ? (saved['clientAttemptOrder'] ?? saved['attemptOrder']) : null;
          if (ord is num) {
            final finalOrder = ord.toInt();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(PREF_ATTEMPT_COUNT, finalOrder);
            if (mounted) setState(() => _attemptOrder = finalOrder);
          }
        }
      } catch (_) {}
    } catch (_) {
      // 조용히 실패
    }
  }

  // ---- KST 포맷 ----
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
    final fixedMedia = MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0));
    final cogSrc = _buildCognitionSource();

    final overall = widget.total == 0 ? 0.0 : widget.score / widget.total;
    final showWarn = overall < 0.5;

    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88;
      if (shortest >= 600) return 72;
      return kToolbarHeight;
    }

    final formattedKst = (widget.kstLabel != null && widget.kstLabel!.trim().isNotEmpty)
        ? widget.kstLabel!
        : _formatKst(widget.testedAt);

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
            '인지 검사',
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
                _attemptChip(_attemptOrder, formattedKst),
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
                      _riskBarRow('반응 시간', cogSrc['반응 시간']),
                      SizedBox(height: 12.h),
                      _riskBarRow('반복어 비율', cogSrc['반복어 비율']),
                      SizedBox(height: 12.h),
                      _riskBarRow('평균 문장 길이', cogSrc['평균 문장 길이']),
                      SizedBox(height: 12.h),
                      _riskBarRow('화행 적절성', cogSrc['화행 적절성']),
                      SizedBox(height: 12.h),
                      _riskBarRow('회상어 점수', cogSrc['회상어 점수']),
                      SizedBox(height: 12.h),
                      _riskBarRow('문법 완성도', cogSrc['문법 완성도']),
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
                      ..._buildEvalItems().expand((w) => [w, SizedBox(height: 10.h)]),
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
                        MaterialPageRoute(builder: (_) => const BrainTrainingMainPage()),
                        (route) => false,
                      );
                    },
                    icon: Icon(Icons.videogame_asset_rounded, size: 22.sp * 1.25),
                    label: Text(
                      '두뇌 게임으로 이동',
                      textScaler: fixedScale,
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w900,
                        fontSize: 22.sp,
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
  Widget _card({required Widget child}) => Container(
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

  Widget _attemptChip(int order, String formattedKst) => Container(
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
              '${order}회차',
              textScaler: fixedScale,
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
              textScaler: fixedScale,
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

  Widget _scoreCircle(int score, int total) {
    final double d = 140.w;
    final double big = d * 0.40;
    final double small = d * 0.20;
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
        Padding(
          padding: EdgeInsets.only(bottom: 6.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 18.sp,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
              _statusChip(eval),
            ],
          ),
        ),
        _riskBar(eval.position),
      ],
    );
  }

  Widget _riskBar(double position) => SizedBox(
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
                        Color(0xFF10B981),
                        Color(0xFFF59E0B),
                        Color(0xFFEF4444),
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
                      border: Border.all(color: const Color(0xFF9CA3AF), width: 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _statusChip(_EvalView eval) => Container(
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
      );

  Widget _warnBanner() => Container(
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

  // 설명 블록은 고정 텍스트
  List<Widget> _buildEvalItems() => <Widget>[
        _evalBlock('[반응 시간]', '반복어 비율 종료 시점부터 응답 시작까지의 시간을 측정합니다. 예) 3초 이내: 상점 / 4-6초: 보통 / 7초 이상: 주의.'),
        _evalBlock('[반복어 비율]', '동일 단어·문장이 반복되는 비율입니다. 예) 5% 이하: 상점 / 10% 이하: 보통 / 20% 이상: 주의.'),
        _evalBlock('[평균 문장 길이]', '응답의 평균 단어(또는 음절) 수를 봅니다. 적정 범위(예: 15±5어)는 양호, 지나치게 짧거나 긴 경우 감점.'),
        _evalBlock('[화행 적절성 점수]', '맥락과 응답 화행의 매칭을 판정합니다. 예) 적합 12회: 상점 / 6회: 보통 / 0회: 주의.'),
        _evalBlock('[회상어 점수]', '사람·장소·사건 등 회상 관련 키워드의 포함과 풍부성 평가. 키워드 다수: 상점 / 부족: 보통 / 없음: 주의.'),
        _evalBlock('[문법 완성도]', '비문, 조사·부착, 주어·서술어 일치 등 문법적 오류를 분석. 오류 없음: 상점 / 일부: 보통 / 잦음: 주의.'),
      ];

  Widget _evalBlock(String title, String body) => Container(
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
    final risk = s.riskRatio;
    if (risk > 0.75) {
      return _EvalView(
        text: '매우 주의',
        textColor: const Color(0xFFB91C1C),
        badgeBg: const Color(0xFFFFE4E6),
        badgeBorder: const Color(0xFFFCA5A5),
        position: risk,
      );
    } else if (risk > 0.5) {
      return _EvalView(
        text: '주의',
        textColor: const Color(0xFFDC2626),
        badgeBg: const Color(0xFFFFEBEE),
        badgeBorder: const Color(0xFFFECACA),
        position: risk,
      );
    } else if (risk > 0.25) {
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
  final double position;
  _EvalView({
    required this.text,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.position,
  });
}

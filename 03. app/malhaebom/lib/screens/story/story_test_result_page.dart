// lib/screens/story/story_test_result_page.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';

// --- 서버 전송 스위치 & 베이스 URL(옵션) ---
const bool kUseServer = bool.fromEnvironment('USE_SERVER', defaultValue: true);
final String API_BASE =
    (() {
      const defined = String.fromEnvironment('API_BASE', defaultValue: '');
      if (defined.isNotEmpty) return defined;
      if (kIsWeb) return 'http://localhost:4000';
      if (Platform.isAndroid) return 'http://10.0.2.2:4000';
      if (Platform.isIOS) return 'http://localhost:4000';
      return 'http://192.168.0.23:4000';
    })();

// --- 로컬 저장 키(동화별) ---
const String PREF_STORY_LATEST_PREFIX = 'story_latest_attempt_v1_';
const String PREF_STORY_COUNT_PREFIX = 'story_attempt_count_v1_';

const TextScaler fixedScale = TextScaler.linear(1.0);

// ✅ 역슬래시 1개가 맞음
String normalizeTitle(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

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
  final Map<String, CategoryStat> byType; // 직접/간접/질문/단언/의례화 ...
  final DateTime testedAt;
  final String? storyTitle;
  final Map<String, double>? riskBarsByType;

  /// true: 실제 테스트 직후(저장+회차증가+옵션 서버전송)
  /// false: 조회용(증가/저장 안 함)
  final bool persist;
  final int? fixedAttemptOrder; // 👈 추가: 읽기전용 모드에서 표시만 할 회차

  const StoryResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    required this.testedAt,
    this.storyTitle,
    this.persist = true,
    this.fixedAttemptOrder,
    this.riskBarsByType,
  });

  @override
  State<StoryResultPage> createState() => _StoryResultPageState();
}

class _StoryResultPageState extends State<StoryResultPage> {
  bool _synced = false;
  int _attemptOrder = 1; // 칩에 표기할 회차

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.persist) {
        await _persistOnce(); // 저장 + 회차증가 (+옵션 서버)
      } else {
        // ✅ 읽기 전용: 전달된 fixedAttemptOrder가 있으면 그대로 사용
        if (widget.fixedAttemptOrder != null) {
          setState(() => _attemptOrder = widget.fixedAttemptOrder!);
        } else {
          // 백업: 회차 정보가 없을 때만 로컬 값을 보여주되, 절대 증가시키지 않음
          await _loadCountOnly();
        }
      }
    });
  }

  Map<String, double> _riskMapFrom(Map<String, CategoryStat> m) {
    return m.map(
      (k, v) => MapEntry(
        k,
        v.total == 0 ? 0.5 : (1 - v.correct / v.total).clamp(0.0, 1.0),
      ),
    );
  }

  // ---- 저장 페이로드 생성 ----
  Map<String, dynamic> _buildPayload({
    required String titleOriginal,
    required String titleKey,
    required int attemptOrder, // 동화별 클라 회차
  }) {
    return {
      'storyTitle': titleOriginal,
      'storyKey': titleKey, // ← 책 구분용
      'attemptOrder': attemptOrder, // ← 동화별 회차(클라)
      'attemptTime': widget.testedAt.toUtc().toIso8601String(),
      'clientKst': _formatKst(widget.testedAt),
      'score': widget.score,
      'total': widget.total,
      'byCategory': widget.byCategory.map(
        (k, v) => MapEntry(k, {'correct': v.correct, 'total': v.total}),
      ),
      'byType': widget.byType.map(
        (k, v) => MapEntry(k, {'correct': v.correct, 'total': v.total}),
      ),
      // riskBar 수치 동봉
      'riskBars': _riskMapFrom(widget.byCategory),
      'riskBarsByType': _riskMapFrom(widget.byType),
    };
  }

  /// ---- 유저 식별자 로드 (user_key 통일) ----
  /// 로그인 시(예시):
  ///  - 일반: prefs.setString('user_key', userId)
  ///  - SNS : prefs.setString('user_key', '${type.toLowerCase()}:$snsUserId')
  Future<Map<String, String>> _identityForApi() async {
    final prefs = await SharedPreferences.getInstance();

    String? readAny(List<String> keys) {
      for (final k in keys) {
        final vs = prefs.getString(k);
        if (vs != null && vs.isNotEmpty) return vs;
        final vi = prefs.getInt(k);
        if (vi != null) return vi.toString();
        final vd = prefs.getDouble(k);
        if (vd != null) return vd.toString();
        final vb = prefs.getBool(k);
        if (vb != null) return vb ? '1' : '0';
      }
      return null;
    }

    // 1) user_key가 이미 있으면 그대로 사용
    final direct = readAny(['user_key', 'userKey']);
    if (direct != null && direct.isNotEmpty) {
      return {'userKey': direct};
    }

    // 2) 로컬 ID 시도
    final localId = readAny([
      'user_id',
      'userId',
      'userid',
      'phone',
      'phoneNumber',
      'phone_number',
    ]);
    if (localId != null && localId.isNotEmpty) {
      await prefs.setString('user_key', localId);
      return {'userKey': localId};
    }

    // 3) SNS 시도 (type:id 형태로 userKey 생성)
    String? snsType =
        readAny([
          'sns_login_type',
          'snsLoginType',
          'login_provider',
          'provider',
          'social_type',
          'loginType',
        ])?.toLowerCase();
    final snsId = readAny([
      'sns_user_id',
      'snsUserId',
      'oauth_id',
      'kakao_user_id',
      'google_user_id',
      'naver_user_id',
    ]);

    if (snsId != null &&
        snsId.isNotEmpty &&
        (snsType == 'kakao' || snsType == 'google' || snsType == 'naver')) {
      final key = '$snsType:$snsId';
      await prefs.setString('user_key', key);
      return {'userKey': key};
    }

    // 4) ★ 최후 fallback: auth_user(JSON)에서 복구
    final raw = prefs.getString('auth_user');
    if (raw != null && raw.isNotEmpty) {
      try {
        final u = jsonDecode(raw) as Map<String, dynamic>;
        final uid = (u['user_id'] ?? '').toString();
        final t = (u['sns_login_type'] ?? '').toString().toLowerCase();
        if (t.isNotEmpty && uid.isNotEmpty) {
          final key = '$t:$uid';
          await prefs.setString('user_key', key);
          return {'userKey': key};
        }
        if (uid.isNotEmpty) {
          await prefs.setString('user_key', uid);
          return {'userKey': uid};
        }
      } catch (_) {}
    }

    debugPrint('[STR] identity -> EMPTY (no user_key/userId/snsId)');
    return {};
  }

  // ---- 서버 최신 회차 조회 → "다음 회차" 계산 (있으면 우선 사용) ----
  Future<int?> _serverNextAttempt(
    String titleKey,
    Map<String, String> identity,
  ) async {
    if (!kUseServer || identity.isEmpty) return null;
    try {
      final uri = Uri.parse(
        '$API_BASE/str/latest',
      ).replace(queryParameters: {...identity, 'storyKey': titleKey});
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      if (j is! Map || j['ok'] != true) return null;
      final latest = j['latest'];
      if (latest is Map) {
        final ord = latest['clientAttemptOrder'] ?? latest['attemptOrder'];
        if (ord is num) {
          final next = ord.toInt() + 1;
          debugPrint(
            '[STR] serverNextAttempt("$titleKey") -> ${ord.toInt()} + 1 = $next',
          );
          return next;
        }
        // 서버에 기록은 있으나 회차 필드 없으면 1로 시작
        return 1;
      }
      // 서버 기록 아예 없으면 1회차
      return 1;
    } catch (e) {
      debugPrint('[STR] serverNextAttempt error: $e');
      return null;
    }
  }

  // ---- 로컬 최신 저장 ----
  Future<void> _cacheLatestLocally(
    String title,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$PREF_STORY_LATEST_PREFIX$title',
      jsonEncode(payload),
    );
  }

  // ---- 회차 증가(동화별, 로컬) ----
  Future<int> _bumpCount(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$PREF_STORY_COUNT_PREFIX$title';
    final prev = prefs.getInt(key) ?? 0;
    final next = prev + 1;
    await prefs.setInt(key, next);
    debugPrint('[STR] _bumpCount("$title"): $prev -> $next');
    return next;
  }

  // ---- 현재 회차 로드(동화별) ----
  Future<void> _loadCountOnly() async {
    final title = normalizeTitle(widget.storyTitle ?? '동화');
    final prefs = await SharedPreferences.getInstance();
    final cnt = prefs.getInt('$PREF_STORY_COUNT_PREFIX$title') ?? 1;
    if (mounted) setState(() => _attemptOrder = cnt);
  }

  // ---- 저장 루틴 ----
  Future<void> _persistOnce() async {
    if (_synced) return;
    _synced = true;

    final originalTitle = widget.storyTitle ?? '동화';
    final keyTitle = normalizeTitle(originalTitle);

    // 0) 우선 identity 확보
    final identity = await _identityForApi();

    // 1) 서버 기준 "다음 회차"가 있으면 그것을 우선 사용, 없으면 로컬 +1
    int next =
        (await _serverNextAttempt(keyTitle, identity)) ??
        (await _bumpCount(keyTitle));

    // 서버에서 1회차라고 알려줬는데 로컬이 엉켜 있었다면 로컬도 덮어쓰기
    if (kUseServer && identity.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('$PREF_STORY_COUNT_PREFIX$keyTitle', next);
      } catch (_) {}
    }

    if (mounted) setState(() => _attemptOrder = next);

    // 2) payload 생성(회차/키 포함)
    final payload = _buildPayload(
      titleOriginal: originalTitle,
      titleKey: keyTitle,
      attemptOrder: next,
    );

    // 3) 로컬 최신 캐시 (키는 정규화 제목 사용)
    await _cacheLatestLocally(keyTitle, payload);

    // 4) 옵션: 서버 전송 (+ user_key)
    if (kUseServer) {
      try {
        final merged = {...payload, ...identity};

        // headers에도 같이 싣기
        final headers = <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          if (identity['userKey'] != null) 'x-user-key': identity['userKey']!,
        };

        // querystring에도 같이 싣기 (프록시/커스텀헤더 차단 대비)
        final base = Uri.parse('$API_BASE/str/attempt');
        final uri =
            identity.isEmpty
                ? base
                : base.replace(
                  queryParameters: {'userKey': identity['userKey']!},
                );

        debugPrint('[STR] POST $uri');
        debugPrint('[STR] headers: $headers');
        debugPrint('[STR] body.identity.present = ${identity.isNotEmpty}');

        // (선택) 사전 whoami 확인
        try {
          final who = Uri.parse(
            '$API_BASE/str/whoami',
          ).replace(queryParameters: identity);
          final whoRes = await http.get(who);
          debugPrint('[STR] whoami -> ${whoRes.statusCode} ${whoRes.body}');
        } catch (_) {}

        final res = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(merged),
        );
        debugPrint('[STR] POST /str/attempt -> ${res.statusCode} ${res.body}');

        // 서버가 최종 회차를 돌려주면 로컬을 덮어씌워 동기화(선택적)
        try {
          final jr = jsonDecode(res.body);
          if (jr is Map) {
            final ord = jr['clientAttemptOrder'] ?? jr['attemptOrder'];
            if (ord is num) {
              final serverOrder = ord.toInt();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(
                '$PREF_STORY_COUNT_PREFIX$keyTitle',
                serverOrder,
              );
              if (mounted) setState(() => _attemptOrder = serverOrder);
              debugPrint('[STR] sync local count to server -> $serverOrder');
            }
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('[STR] POST error: $e');
      }
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
    final overall = widget.total == 0 ? 0.0 : widget.score / widget.total;
    final showWarn = overall < 0.5;
    final evalSource =
        (widget.byType.isNotEmpty &&
                widget.byType.values.any((s) => s.total > 0))
            ? widget.byType
            : widget.byCategory;

    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88;
      if (shortest >= 600) return 72;
      return kToolbarHeight;
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
              _attemptChip(_attemptOrder, _formatKst(widget.testedAt)),
              SizedBox(height: 12.h),

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
                      evalSource,
                    ).expand((w) => [w, SizedBox(height: 10.h)]),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: _brainCta(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 위젯 유틸 ---
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
          textScaler: fixedScale,
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

  // ✅ 윗줄 라벨/칩 + 아래 게이지
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
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
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

  // 상태칩 공용 위젯
  Widget _statusChip(_EvalView eval) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    decoration: BoxDecoration(
      color: eval.badgeBg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: eval.badgeBorder),
    ),
    child: Text(
      eval.text,
      textScaler: fixedScale,
      style: TextStyle(
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

  List<Widget> _buildEvalItems(Map<String, CategoryStat> _) {
    final bars = widget.riskBarsByType ?? const {};
    final items = <Widget>[];
    double? r(String k) =>
        bars.containsKey(k) ? bars[k]!.clamp(0.0, 1.0) : null;
    void add(String key, String title, String mild, String severe) {
      final v = r(key);
      if (v == null) return;
      if (v > 0.75) {
        items.add(_evalBlock('[$title]이 매우 부족합니다.', severe));
      } else if (v > 0.5) {
        items.add(_evalBlock('[$title]이 부족합니다.', mild));
      }
    }

    add(
      '직접화행',
      '직접화행',
      '기본 대화 의도 파악이 부족합니다. 대화 응용 훈련으로 개선하세요.',
      '직접화행 이해가 크게 낮습니다. 실제 상황 역할놀이로 강화하세요.',
    );
    add(
      '간접화행',
      '간접화행',
      '간접적 표현 해석이 약합니다. 맥락 추론 훈련이 필요합니다.',
      '간접화행 이해가 크게 낮습니다. 은유·완곡표현 중심 반복 훈련을 권장합니다.',
    );
    add(
      '질문화행',
      '질문화행',
      '질문 의도 파악이 부족합니다. 정보 파악 활동을 권장합니다.',
      '질문화행 이해가 크게 낮습니다. WH-질문 중심 단계적 훈련이 필요합니다.',
    );
    add(
      '단언화행',
      '단언화행',
      '상황에 맞는 진술 이해가 부족합니다. 상황·정서 파악 활동을 권합니다.',
      '단언화행 이해가 크게 낮습니다. 원인–결과 설명 훈련을 권합니다.',
    );
    add(
      '의례화화행',
      '의례화화행',
      '예절적 표현 이해가 낮습니다. 일상 의례 표현 학습을 권장합니다.',
      '의례화화행 이해가 크게 낮습니다. 실제 사례 기반 반복 학습을 권합니다.',
    );

    if (items.isEmpty) {
      items.add(_evalBlock('전반적으로 양호합니다.', '필요 시 추가 학습으로 안정적 이해를 유지하세요.'));
    }
    return items;
  }

  Widget _evalBlock(String title, String body) => Container(
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

  // CTA
  Widget _brainCta() {
    final double font = 22.sp;
    final double iconSize = font * 1.25;
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
  final double position; // 0~1
  _EvalView({
    required this.text,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.position,
  });
}

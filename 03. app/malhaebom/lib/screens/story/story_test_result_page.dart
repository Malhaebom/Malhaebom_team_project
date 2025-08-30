// ==========================================
// File: lib/screens/story/story_test_result_page.dart
// 결과 페이지
// - 저장(POST) 응답의 회차/시간을 즉시 칩에 반영
// - 이어서 /str/latest 재조회로 검증/덮어쓰기
// - 실패 시 1회차로 보정하지 않음(스피너 또는 기존값 유지)
// ==========================================

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';

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

const String PREF_STORY_LATEST_PREFIX = 'story_latest_attempt_v1_';
const TextScaler fixedScale = TextScaler.linear(1.0);

// 공백만 통일(서버는 따옴표 제거 비교까지 수행)
String normalizeTitle(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

class CategoryStat {
  final int correct;
  final int total;
  const CategoryStat({required this.correct, required this.total});
  double get correctRatio => total == 0 ? 0 : correct / total;
  double get riskRatio => 1 - correctRatio;
}

class StoryResultPage extends StatefulWidget {
  final int score;
  final int total;
  final Map<String, CategoryStat> byCategory; // 요구/질문/단언/의례화
  final Map<String, CategoryStat> byType; // 직접/간접/질문/단언/의례화
  final DateTime testedAt; // 클라 테스트 시간
  final String? storyTitle;
  final bool persist; // true: 저장 모드, false: 조회 모드

  const StoryResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    required this.testedAt,
    this.storyTitle,
    this.persist = true,
  });

  @override
  State<StoryResultPage> createState() => _StoryResultPageState();
}

class _StoryResultPageState extends State<StoryResultPage> {
  /// null = 로딩중, 값 존재 시 = 확정/선반영된 회차
  int? _attemptOrder;

  /// null = 로딩중, 값 존재 시 = 서버 전달 KST 또는 attemptTime 포맷
  String? _attemptKst;

  bool _working = false;

  @override
  void initState() {
    super.initState();
    // 시작 시 어느 것도 보정하지 않고 로딩 상태로 둔다.
    _attemptOrder = null;
    _attemptKst = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _finalizeFromServer(); // persist면 저장→선반영→최신조회, 아니면 최신조회만
      // 실패해도 1회차로 강제 표기하지 않음(사용자 혼란 방지)
    });
  }

  // -------------------- 네트워크 시퀀스 --------------------

  /// 저장→선반영→최신조회(덮어쓰기)
  Future<void> _finalizeFromServer() async {
    if (!kUseServer || _working) return;
    _working = true;
    try {
      final identity = await _identityForApi();
      final originalTitle = widget.storyTitle ?? '동화';
      final keyTitle = normalizeTitle(originalTitle);

      // 1) persist면 저장하고 응답으로 즉시 칩을 선반영
      if (widget.persist) {
        await _postAttemptAndPrefill(
          identity: identity,
          originalTitle: originalTitle,
          keyTitle: keyTitle,
        );
      }

      // 2) 어떤 경우에도 최신을 다시 조회해서 확정 덮어쓰기
      await _loadLatestAndBind(identity: identity, keyTitle: keyTitle);

      // 3) 로컬 latest 캐시(선택)
      if (_attemptOrder != null) {
        try {
          final latest = await _getLatestRaw(
            identity: identity,
            keyTitle: keyTitle,
          );
          if (latest != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              '$PREF_STORY_LATEST_PREFIX$keyTitle',
              jsonEncode(latest),
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[STR] finalize error: $e');
    } finally {
      _working = false;
    }
  }

  /// POST /str/attempt → 응답(saved.clientAttemptOrder/clientKst)으로 즉시 칩 선반영
  Future<void> _postAttemptAndPrefill({
    required Map<String, String> identity,
    required String originalTitle,
    required String keyTitle,
  }) async {
    try {
      final payload = _buildPayload(
        titleOriginal: originalTitle,
        titleKey: keyTitle,
      );

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        if (identity['userKey'] != null) 'x-user-key': identity['userKey']!,
      };
      final uri =
          identity.isEmpty
              ? Uri.parse('$API_BASE/str/attempt')
              : Uri.parse(
                '$API_BASE/str/attempt',
              ).replace(queryParameters: {'userKey': identity['userKey']!});

      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({...payload, ...identity}),
      );
      if (res.statusCode != 200) {
        debugPrint(
          '[STR] POST /str/attempt fail ${res.statusCode} ${res.body}',
        );
        return;
      }
      final j = jsonDecode(res.body);
      if (j is! Map || j['ok'] != true) return;

      final saved = j['saved'];
      if (saved is Map) {
        // 회차
        int? ord;
        final v = saved['clientAttemptOrder'] ?? saved['attemptOrder'];
        if (v is num) ord = v.toInt();
        if (v is String) ord = int.tryParse(v);

        // 시간
        String? kst = saved['clientKst'];
        if (kst is! String || kst.trim().isEmpty) {
          final at = saved['attemptTime'];
          if (at is String) {
            final t = DateTime.tryParse(at);
            if (t != null) kst = _formatKst(t);
          }
        }

        if (mounted && ord != null) {
          setState(() {
            _attemptOrder = ord; // ← 즉시 갱신
            _attemptKst = kst ?? _formatKst(widget.testedAt); // ← 즉시 갱신
          });
        }
      }
    } catch (e) {
      debugPrint('[STR] post attempt error: $e');
    }
  }

  /// GET /str/latest → 화면 바인딩(선반영 값을 덮어씀)
  Future<void> _loadLatestAndBind({
    required Map<String, String> identity,
    required String keyTitle,
  }) async {
    try {
      final latest = await _getLatestRaw(
        identity: identity,
        keyTitle: keyTitle,
      );
      if (latest == null) return;

      int? ord;
      final v = latest['clientAttemptOrder'] ?? latest['attemptOrder'];
      if (v is num) ord = v.toInt();
      if (v is String) ord = int.tryParse(v);

      String? kst = latest['clientKst'];
      if (kst is! String || kst.trim().isEmpty) {
        final at = latest['attemptTime'];
        if (at is String) {
          final t = DateTime.tryParse(at);
          if (t != null) kst = _formatKst(t);
        }
      }

      if (mounted && ord != null) {
        setState(() {
          _attemptOrder = ord; // 최신값으로 확정
          _attemptKst = kst ?? _formatKst(widget.testedAt); // 최신값으로 확정
        });
      }
    } catch (e) {
      debugPrint('[STR] loadLatestAndBind error: $e');
    }
  }

  Future<Map<String, dynamic>?> _getLatestRaw({
    required Map<String, String> identity,
    required String keyTitle,
  }) async {
    if (!kUseServer || identity.isEmpty) return null;
    final uri = Uri.parse(
      '$API_BASE/str/latest',
    ).replace(queryParameters: {...identity, 'storyKey': keyTitle});
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! Map || j['ok'] != true) return null;
    final latest = j['latest'];
    if (latest is Map<String, dynamic>) return latest;
    return null;
  }

  // -------------------- 공용 빌더/유틸 --------------------

  Map<String, double> _riskMapFrom(Map<String, CategoryStat> m) {
    return m.map(
      (k, v) => MapEntry(
        k,
        v.total == 0 ? 0.5 : (1 - v.correct / v.total).clamp(0.0, 1.0),
      ),
    );
  }

  Map<String, dynamic> _buildPayload({
    required String titleOriginal,
    required String titleKey,
  }) {
    return {
      'storyTitle': titleOriginal,
      'storyKey': titleKey,
      // attemptOrder는 보내지 않음(서버가 계산)
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
      'riskBars': _riskMapFrom(widget.byCategory),
      'riskBarsByType': _riskMapFrom(widget.byType),
    };
  }

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

    final direct = readAny(['user_key', 'userKey']);
    if (direct != null && direct.isNotEmpty) return {'userKey': direct};

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
    return {};
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

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    final overall = widget.total == 0 ? 0.0 : widget.score / widget.total;
    final showWarn = overall < 0.5;

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
              _attemptChip(
                _attemptOrder,
                _attemptKst ?? _formatKst(widget.testedAt),
              ),
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
                      widget.byType,
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

  /// 칩: null이면 스피너 + "불러오는 중…"
  Widget _attemptChip(int? order, String formattedKst) {
    final loading = order == null;
    final display = loading ? '불러오는 중…' : '${order}회차';
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
          if (loading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8.w),
          ],
          Text(
            display,
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
  }

  Widget _scoreCircle(int score, int total) {
    final double d = 140.w, big = d * 0.40, small = d * 0.20;
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

  List<Widget> _buildEvalItems(Map<String, CategoryStat> t) {
    final items = <Widget>[];
    void addIfLow(String key, String title, String body) {
      final s = t[key];
      if (s == null || s.total == 0) return;
      if (s.correctRatio < 0.4) items.add(_evalBlock('[$title]이 부족합니다.', body));
    }

    addIfLow('직접화행', '직접화행', '기본 대화 의도 파악이 미흡합니다. 대화 응용 훈련으로 개선하세요.');
    addIfLow('간접화행', '간접화행', '간접적 표현 해석이 약합니다. 맥락 추론 훈련이 필요합니다.');
    addIfLow('질문화행', '질문화행', '질문 의도 파악이 부족합니다. 정보 파악 활동을 권장합니다.');
    addIfLow('단언화행', '단언화행', '상황에 맞는 진술 이해가 부족합니다. 상황·정서 파악 활동을 권합니다.');
    addIfLow('의례화화행', '의례화화행', '예절적 표현 이해가 낮습니다. 일상 의례 표현 학습을 권장합니다.');
    if (items.isEmpty)
      items.add(_evalBlock('전반적으로 양호합니다.', '필요 시 추가 학습으로 안정적 이해를 유지하세요.'));
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

  Widget _brainCta() {
    final double font = 22.sp, iconSize = font * 1.25;
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
  final double position;
  _EvalView({
    required this.text,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.position,
  });
}

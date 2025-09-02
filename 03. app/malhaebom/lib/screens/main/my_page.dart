// lib/screens/main/my_page.dart
// (파일 전체 — 변경 포인트: 인터뷰 '자세히 보기' push 시 kstLabel 전달)
import 'dart:convert';
import 'dart:io' show Platform; // ✅
import 'package:flutter/foundation.dart' show kIsWeb; // ✅
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/main/interview_info_page.dart';
import 'package:malhaebom/screens/story/story_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // ✅

import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/back_to_home.dart';
import 'package:malhaebom/screens/users/login_page.dart';

// 결과 상세 페이지의 CategoryStat 타입을 그대로 사용
import 'package:malhaebom/screens/main/interview_result_page.dart' as ir;

// 동화 결과 상세
import 'package:malhaebom/screens/story/story_test_result_page.dart' as sr;

// ✅ ResultHistoryPage + HistoryMode 둘 다 가져오기
import 'result_history_page.dart' show ResultHistoryPage, HistoryMode;

// ✅ Fairytale data alias import
import 'package:malhaebom/data/fairytale_assets.dart' as ft;

const TextScaler _fixedScale = TextScaler.linear(1.0);

// ===== 서버 설정(StoryResultPage와 동일 규칙) =====
const bool kUseServer = bool.fromEnvironment('USE_SERVER', defaultValue: true);
final String API_BASE =
    (() {
      const defined = String.fromEnvironment('API_BASE', defaultValue: '');
      if (defined.isNotEmpty) return defined;
      return 'http://211.188.63.38:4000';
    })();

// ===== 로컬 저장 키 =====
const String PREF_LATEST_ATTEMPT = 'latest_attempt_v1';
const String PREF_ATTEMPT_COUNT = 'attempt_count_v1';
const String PREF_STORY_LATEST_PREFIX = 'story_latest_attempt_v1_';
const String PREF_STORY_COUNT_PREFIX = 'story_attempt_count_v1_';

// 게스트 캐시 전체 삭제
Future<void> _clearGuestCaches(SharedPreferences prefs) async {
  await prefs.remove(PREF_LATEST_ATTEMPT);
  await prefs.remove(PREF_ATTEMPT_COUNT);
  for (final title in kStoryTitles) {
    final keyTitle = _norm(title);
    await prefs.remove('$PREF_STORY_LATEST_PREFIX$keyTitle');
    await prefs.remove('$PREF_STORY_COUNT_PREFIX$keyTitle');
    await prefs.remove('$PREF_STORY_LATEST_PREFIX$title');
    await prefs.remove('$PREF_STORY_COUNT_PREFIX$title');
  }
}

Future<void> _bootstrapGuestEphemeral() async {
  final prefs = await SharedPreferences.getInstance();
  final hasLogin =
      ((prefs.getString('login_id') ?? '').trim().isNotEmpty) ||
      ((prefs.getString('user_key') ?? '').trim().isNotEmpty);
  if (!hasLogin) {
    await _clearGuestCaches(prefs);
  }
}

Future<void> _purgeStoryLocal(SharedPreferences prefs, String title) async {
  final keyTitle = _norm(title);
  await prefs.remove('$PREF_STORY_LATEST_PREFIX$keyTitle');
  await prefs.remove('$PREF_STORY_COUNT_PREFIX$keyTitle');
  // 과거 호환 키도 함께 제거
  await prefs.remove('$PREF_STORY_LATEST_PREFIX$title');
  await prefs.remove('$PREF_STORY_COUNT_PREFIX$title');
}

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

const List<String> kStoryTitles = <String>[
  '어머니의 벙어리 장갑',
  '아버지와 결혼식',
  '아들의 호빵',
  '할머니와 바나나',
  '꽁당보리밥',
];

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with TickerProviderStateMixin {
  AttemptSummary? _latest;
  int _attemptCount = 0;
  bool _loading = true;

  late TabController _storyTabController;
  bool _storyLoading = true;
  final Map<String, StorySummary?> _storyLatest = {};
  final Map<String, int> _storyAttemptCounts = {};

  bool _hasUserKey = false;

  @override
  void initState() {
    super.initState();
    _storyTabController = TabController(
      length: kStoryTitles.length,
      vsync: this,
    );

    // ✅ 탭 선택이 바뀌면 콘텐츠를 다시 그려서 높이가 자연스럽게 늘어나도록
    _storyTabController.addListener(() {
      if (!mounted) return;
      // indexIsChanging 동안은 애니메이션 중일 수 있어요. 바뀐 뒤에만 setState.
      if (!_storyTabController.indexIsChanging) {
        setState(() {});
      }
    });

    Future.microtask(() async {
      await _bootstrapGuestEphemeral();
      await _loadAll();
      await _checkUserKey();
    });
  }

  @override
  void dispose() {
    _storyTabController.dispose();
    super.dispose();
  }

  Future<void> _syncUserKeyWithLoginId() async {
    final prefs = await SharedPreferences.getInstance();
    String loginId = (prefs.getString('login_id') ?? '').trim();
    String userKey = (prefs.getString('user_key') ?? '').trim();

    if (loginId.isEmpty) {
      final raw = prefs.getString('auth_user');
      if (raw != null && raw.isNotEmpty) {
        try {
          final u = jsonDecode(raw) as Map<String, dynamic>;
          final lid = (u['login_id'] ?? '').toString().trim();
          if (lid.isNotEmpty) {
            loginId = lid;
            await prefs.setString('login_id', loginId);
          }
        } catch (_) {}
      }
    }

    if (loginId.isNotEmpty) {
      if (userKey != loginId) {
        await prefs.setString('user_key', loginId);
      }
    } else if (userKey.isNotEmpty) {
      await prefs.setString('login_id', userKey);
    }
  }

  Future<void> _loadAll() async {
    await _syncUserKeyWithLoginId();
    await Future.wait([_loadLatest(), _loadStoryLatest()]);
    await _checkUserKey();
  }

  Future<void> _resetCognitionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PREF_LATEST_ATTEMPT);
    await prefs.remove(PREF_ATTEMPT_COUNT);
    if (!mounted) return;
    setState(() {
      _latest = null;
      _attemptCount = 0;
    });
  }

  Future<void> _startCognition({bool resetLocal = false}) async {
    if (resetLocal) {
      await _resetCognitionLocal();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InterviewInfoPage()),
    );
    if (!mounted) return;
    await _loadLatest();
  }

  Future<void> _checkUserKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = (prefs.getString('user_key') ?? '').trim();
    if (!mounted) return;
    setState(() => _hasUserKey = key.isNotEmpty);
  }

  Future<void> _loadLatest() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    AttemptSummary? latestFromServer = await _fetchCognitionLatestFromServer();
    if (latestFromServer != null) {
      final attemptNo = latestFromServer.attemptOrder ?? 1;
      if (!mounted) return;
      setState(() {
        _latest = latestFromServer;
        _attemptCount = attemptNo;
        _loading = false;
      });
      return;
    }

    AttemptSummary? latest;
    final s = prefs.getString(PREF_LATEST_ATTEMPT);
    if (s != null && s.isNotEmpty) {
      try {
        latest = AttemptSummary.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    final cnt = prefs.getInt(PREF_ATTEMPT_COUNT) ?? (latest == null ? 0 : 1);

    if (!mounted) return;
    setState(() {
      _latest = latest;
      _attemptCount = cnt;
      _loading = false;
    });
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('auth_token') ?? '').trim();
    final userKey = (prefs.getString('user_key') ?? '').trim();

    final headers = <String, String>{'accept': 'application/json'};
    if (userKey.isNotEmpty) headers['x-user-key'] = userKey;
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, String>> _identityParams() async {
    final prefs = await SharedPreferences.getInstance();
    final loginId = (prefs.getString('login_id') ?? '').trim();
    if (loginId.isNotEmpty) {
      if ((prefs.getString('user_key') ?? '').trim() != loginId) {
        await prefs.setString('user_key', loginId);
      }
      return {'userKey': loginId};
    }
    final direct =
        ((prefs.getString('user_key') ?? prefs.getString('userKey')) ?? '')
            .trim();
    if (direct.isNotEmpty) {
      if ((prefs.getString('login_id') ?? '').trim() != direct) {
        await prefs.setString('login_id', direct);
      }
      return {'userKey': direct};
    }
    final raw = prefs.getString('auth_user');
    if (raw != null && raw.isNotEmpty) {
      try {
        final u = jsonDecode(raw) as Map<String, dynamic>;
        final lid = (u['login_id'] ?? '').toString().trim();
        if (lid.isNotEmpty) {
          await prefs.setString('login_id', lid);
          await prefs.setString('user_key', lid);
          return {'userKey': lid};
        }
      } catch (_) {}
    }
    return {};
  }

  Future<StorySummary?> _fetchStoryLatestFromServer(String storyTitle) async {
    if (!kUseServer) return null;
    final headers = await _authHeaders();
    if (!headers.containsKey('Authorization') &&
        !headers.containsKey('x-user-key')) {
      return null;
    }
    final uri = Uri.parse(
      '$API_BASE/str/latest',
    ).replace(queryParameters: {'storyKey': _norm(storyTitle)});
    try {
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      if (j is! Map || j['ok'] != true) return null;
      final latest = j['latest'];
      if (latest == null) return null;
      return StorySummary.fromJson(latest as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AttemptSummary?> _fetchCognitionLatestFromServer({
    String? interviewTitle,
  }) async {
    if (!kUseServer) return null;
    final headers = await _authHeaders();
    if (!headers.containsKey('Authorization') &&
        !headers.containsKey('x-user-key')) {
      return null;
    }
    final id = await _identityParams();
    final qp = <String, String>{...id};
    if ((interviewTitle ?? '').trim().isNotEmpty) {
      qp['title'] = _norm(interviewTitle!);
    }
    final uri = Uri.parse('$API_BASE/ir/latest').replace(queryParameters: qp);
    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      if (j is! Map || j['ok'] != true) return null;
      final latest = j['latest'];
      if (latest == null) return null;
      return AttemptSummary.fromJson(latest as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadStoryLatest() async {
    setState(() => _storyLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // 과거 오남용 키 제거(있다면)
    await prefs.remove('$PREF_STORY_COUNT_PREFIX동화');

    // ✅ 로그인 여부
    final isLoggedIn =
        ((prefs.getString('login_id') ?? '').trim().isNotEmpty) ||
        ((prefs.getString('user_key') ?? '').trim().isNotEmpty);

    for (final title in kStoryTitles) {
      final keyTitle = _norm(title);

      // 1) 서버 조회
      final latestFromServer = await _fetchStoryLatestFromServer(title);

      if (isLoggedIn) {
        // ✅ 로그인 상태: 서버가 진실
        if (latestFromServer == null) {
          // 서버에 기록이 "없다"면 로컬 캐시를 즉시 제거하고 화면에서도 숨김
          await _purgeStoryLocal(prefs, title);
          _storyLatest[title] = null;
          _storyAttemptCounts[title] = 0;
        } else {
          // 서버 결과를 그대로 채택 (로컬 캐시는 굳이 덮어쓰지 않아도 OK)
          _storyLatest[title] = latestFromServer;
          _storyAttemptCounts[title] = latestFromServer.attemptOrder ?? 1;
        }
        continue; // 게스트 폴백 로직은 건너뜀
      }

      // 2) 게스트(미로그인): 예전처럼 로컬 폴백 허용
      StorySummary? latestFromLocal;
      final js =
          prefs.getString('$PREF_STORY_LATEST_PREFIX$keyTitle') ??
          prefs.getString('$PREF_STORY_LATEST_PREFIX$title');
      if (js != null && js.isNotEmpty) {
        try {
          latestFromLocal = StorySummary.fromJson(
            jsonDecode(js) as Map<String, dynamic>,
          );
        } catch (_) {}
      }

      final chosen = latestFromServer ?? latestFromLocal;

      int attemptCount =
          prefs.getInt('$PREF_STORY_COUNT_PREFIX$keyTitle') ??
          prefs.getInt('$PREF_STORY_COUNT_PREFIX$title') ??
          (chosen == null ? 0 : 1);
      if (latestFromServer?.attemptOrder != null) {
        attemptCount = latestFromServer!.attemptOrder!;
      }

      _storyLatest[title] = chosen;
      _storyAttemptCounts[title] = attemptCount;
    }

    setState(() => _storyLoading = false);
  }

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _goToStoryDetail(String storyTitle) {
    final asset = ft.byTitle(storyTitle);
    final idx = ft.indexByTitle(storyTitle);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                StoryDetailPage(title: asset.title, storyImg: asset.titleImg),
        settings: RouteSettings(
          arguments: {'storyIndex': idx, 'storyAsset': asset},
        ),
      ),
    );
  }

  Future<void> _openHistory(HistoryMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultHistoryPage(mode: mode)),
    );
    if (!mounted) return;
    _loadLatest();
    _loadStoryLatest();
  }

  bool _isLargeTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 840;
  bool _isTablet(BuildContext context) {
    final s = MediaQuery.sizeOf(context).shortestSide;
    return s >= 600 && s < 840;
  }

  double _tabBarHeight(BuildContext context) {
    if (_isLargeTablet(context)) return 56;
    if (_isTablet(context)) return 52;
    return 44;
  }

  double _tabFontSp(BuildContext context) {
    if (_isLargeTablet(context)) return 20.sp;
    if (_isTablet(context)) return 19.sp;
    return 18.sp;
  }

  double _tabHPad(BuildContext context) {
    if (_isLargeTablet(context)) return 16.w;
    if (_isTablet(context)) return 14.w;
    return 12.w;
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
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
                child: Column(
                  children: [
                    _logoutButton(context),
                    SizedBox(height: 20.h),
                    _myCognitionReportCard(context),
                    SizedBox(height: 20.h),
                    _myStoryHistoryCard(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // == 로그인/로그아웃 토글 버튼 ==
  Widget _logoutButton(BuildContext context) {
    final isLoggedIn = _hasUserKey;
    final title = isLoggedIn ? '로그아웃' : '로그인';
    final leadingIcon = isLoggedIn ? Icons.logout : Icons.login;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          if (isLoggedIn) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
            await prefs.remove('auth_user');
            await prefs.remove('user_key');
            await prefs.remove('login_id');
            await prefs.remove('sns_user_id');
            await prefs.remove('sns_login_type');
            await prefs.remove('user_id');
            await prefs.remove(PREF_LATEST_ATTEMPT);
            await prefs.remove(PREF_ATTEMPT_COUNT);
            await _clearGuestCaches(prefs);

            if (!mounted) return;
            setState(() => _hasUserKey = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("로그아웃 되었습니다.")));

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
            if (!mounted) return;
            await _syncUserKeyWithLoginId();
            await _checkUserKey();
            await _loadAll();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1.w)),
          ),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(width: 10.w),
                  Icon(leadingIcon, color: AppColors.text, size: 26),
                  SizedBox(width: 5.w),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22.sp,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              Icon(Icons.navigate_next, size: 40.h, color: AppColors.text),
            ],
          ),
        ),
      ),
    );
  }

  // == 나의 인지 검사 결과 ==
  Widget _myCognitionReportCard(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(height: 5.h),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openHistory(HistoryMode.cognition),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 8.h,
                    horizontal: 10.w,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "나의 인지 검사 결과",
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.navigate_next,
                        size: 34.h,
                        color: AppColors.text,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child:
                  _loading
                      ? _skeleton()
                      : (_latest == null
                          ? _emptyLatest(context)
                          : _latestCard(context, _latest!, _attemptCount)),
            ),
          ],
        ),
      ),
    );
  }

  // == 나의 동화 검사 결과 ==
  Widget _myStoryHistoryCard(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(height: 5.h),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openHistory(HistoryMode.story),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 8.h,
                    horizontal: 10.w,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "나의 동화 검사 결과",
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.navigate_next,
                        size: 34.h,
                        color: AppColors.text,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            _storyLoading
                ? Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: _skeleton(),
                )
                : Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Column(
                    children: [
                      SizedBox(
                        height: _tabBarHeight(context),
                        child: TabBar(
                          controller: _storyTabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          labelPadding: EdgeInsets.symmetric(
                            horizontal: _tabHPad(context),
                          ),
                          indicatorPadding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppColors.btnColorDark,
                          unselectedLabelColor: const Color(0xFF6B7280),
                          indicatorColor: AppColors.btnColorDark,
                          tabs: [
                            for (final t in kStoryTitles)
                              _CompactTab(t, fontSize: _tabFontSp(context)),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder:
                            (child, anim) =>
                                SizeTransition(sizeFactor: anim, child: child),
                        child: _buildCurrentStoryTabBody(context),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStoryTabBody(BuildContext context) {
    final idx = _storyTabController.index;
    final t = kStoryTitles[idx];
    final s = _storyLatest[t];
    final attemptCount = _storyAttemptCounts[t] ?? 0;

    // AnimatedSwitcher가 키를 보고 부드럽게 갈아끼우도록 KeyedSubtree 사용
    return KeyedSubtree(
      key: ValueKey('story-$idx'),
      child:
          (s == null)
              ? _emptyStory(t)
              : _storyCard(context, t, s, attemptCount),
    );
  }

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
            ' 3분이면 끝나요 🙂\n지금 검사하러 가볼까요?',
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
              onPressed: () => _startCognition(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                '검사 시작하기',
                style: TextStyle(
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GmarketSans',
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
    );
  }

  Widget _emptyStory(String storyTitle) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 40.sp, color: AppColors.text),
          SizedBox(height: 10.h),
          Text(
            '아직 "$storyTitle" \n결과가 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18.sp,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '동화를 감상하고 테스트를 완료하면\n여기에 결과가 표시됩니다.',
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
              onPressed: () => _goToStoryDetail(storyTitle),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                '검사 시작하기',
                style: TextStyle(
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GmarketSans',
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
    );
  }

  Widget _latestCard(BuildContext context, AttemptSummary a, int attemptCount) {
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
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                    builder:
                        (_) => ir.InterviewResultPage(
                          score: a.score,
                          total: a.total,
                          byCategory: a.byCategory,
                          byType: a.byType ?? <String, ir.CategoryStat>{},
                          testedAt: a.testedAt ?? DateTime.now(),
                          interviewTitle: a.interviewTitle,
                          persist: false,
                          fixedAttemptOrder: a.attemptOrder,
                          kstLabel: a.kstLabel, // ✅ 전달
                        ),
                  ),
                );
              },
              icon: Icon(Icons.open_in_new, size: 26.sp),
              label: Text(
                '자세히 보기',
                style: TextStyle(
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GmarketSans',
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
    );
  }

  Widget _storyCard(
    BuildContext context,
    String storyTitle,
    StorySummary s,
    int attemptCount,
  ) {
    const order = ['요구', '질문', '단언', '의례화'];

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
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      storyTitle,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22.sp,
                        fontFamily: 'GmarketSans',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            s.kstLabel ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              fontFamily: 'GmarketSans',
            ),
          ),
          SizedBox(height: 12.h),
          _scoreCircle(s.score, s.total),
          SizedBox(height: 12.h),
          ...order
              .where((k) => s.byCategory.containsKey(k))
              .map(
                (k) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _riskBarRow(k, s.byCategory[k]),
                ),
              ),
          SizedBox(height: 6.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: () async {
                final byCat = s.byCategory.map(
                  (k, v) => MapEntry(
                    k,
                    sr.CategoryStat(correct: v.correct, total: v.total),
                  ),
                );
                final byType = s.byType.map(
                  (k, v) => MapEntry(
                    k,
                    sr.CategoryStat(correct: v.correct, total: v.total),
                  ),
                );
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => sr.StoryResultPage(
                          score: s.score,
                          total: s.total,
                          byCategory: byCat,
                          byType: byType,
                          testedAt: s.testedAt ?? DateTime.now(),
                          storyTitle: storyTitle,
                          persist: false,
                          fixedAttemptOrder: s.attemptOrder,
                          riskBarsByType: s.riskBarsByType,
                          kstLabel: s.kstLabel,
                        ),
                  ),
                );
                if (!mounted) return;
                _loadStoryLatest();
              },
              icon: Icon(Icons.open_in_new, size: 26.sp),
              label: Text(
                '자세히 보기',
                style: TextStyle(
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GmarketSans',
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
    );
  }

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

  Widget _riskBarRow(String label, ir.CategoryStat? stat) {
    final ev = _evalFromStat(stat);
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
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                    color: const Color(0xFF4B5563),
                    fontFamily: 'GmarketSans',
                  ),
                ),
              ),
              _statusChip(ev),
            ],
          ),
        ),
        _riskBar(ev.position),
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

  Widget _statusChip(_EvalView ev) => Container(
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
  );

  Widget _scoreCircle(int score, int total) {
    final double d = 120.w;
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
                textScaler: _fixedScale,
                style: TextStyle(
                  fontSize: big,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                  fontFamily: 'GmarketSans',
                ),
              ),
              Text(
                '/$total',
                textScaler: _fixedScale,
                style: TextStyle(
                  fontSize: small,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                  fontFamily: 'GmarketSans',
                ),
              ),
            ],
          ),
        ],
      ),
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

// ===== 모델 (인터뷰 요약) =====
class AttemptSummary {
  final int score;
  final int total;
  final Map<String, ir.CategoryStat> byCategory;
  final Map<String, ir.CategoryStat>? byType;
  final DateTime? testedAt;
  final String? kstLabel;
  final String? interviewTitle;
  final int? attemptOrder;

  AttemptSummary({
    required this.score,
    required this.total,
    required this.byCategory,
    this.byType,
    this.testedAt,
    this.kstLabel,
    this.interviewTitle,
    this.attemptOrder,
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

    final ord =
        j['clientAttemptOrder'] ?? j['clientRound'] ?? j['attemptOrder'];
    int? ordInt;
    if (ord is num) {
      ordInt = ord.toInt();
    } else if (ord is String) {
      ordInt = int.tryParse(ord);
    }

    return AttemptSummary(
      score: (j['score'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      byCategory: _mapStats(j['byCategory']),
      byType: _mapStats(j['byType']),
      testedAt: ts,
      kstLabel: j['clientKst'] as String?,
      interviewTitle: j['interviewTitle'] as String?,
      attemptOrder: ordInt,
    );
  }
}

// ===== 모델 (동화 결과) =====
class StorySummary {
  final String? storyTitle;
  final int score;
  final int total;
  final Map<String, ir.CategoryStat> byCategory;
  final Map<String, ir.CategoryStat> byType;
  final DateTime? testedAt;
  final String? kstLabel;
  final int? attemptOrder;
  final Map<String, double> riskBarsByType;

  StorySummary({
    required this.storyTitle,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    this.testedAt,
    this.kstLabel,
    this.attemptOrder,
    this.riskBarsByType = const {},
  });

  factory StorySummary.fromJson(Map<String, dynamic> j) {
    Map<String, double> _parseBars(dynamic x) {
      if (x is Map) {
        return x.map(
          (k, v) => MapEntry(
            '$k',
            (v is num)
                ? v.toDouble()
                : double.tryParse('$v')?.clamp(0.0, 1.0) ?? 0.0,
          ),
        );
      }
      if (x is String && x.trim().isNotEmpty) {
        try {
          return (jsonDecode(x) as Map).map(
            (k, v) => MapEntry(
              '$k',
              (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0,
            ),
          );
        } catch (_) {}
      }
      return const {};
    }

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

    final ord = (j['clientAttemptOrder'] ?? j['attemptOrder']);
    final ordInt = (ord is num) ? ord.toInt() : null;

    return StorySummary(
      storyTitle: j['storyTitle'] as String?,
      score: (j['score'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      byCategory: _mapStats(j['byCategory']),
      byType: _mapStats(j['byType']),
      testedAt: ts,
      kstLabel: j['clientKst'] as String?,
      attemptOrder: ordInt,
      riskBarsByType: _parseBars(j['riskBarsByType']),
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

class _CompactTab extends StatelessWidget {
  const _CompactTab(this.text, {Key? key, required this.fontSize})
    : super(key: key);
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Align(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              fontFamily: 'GmarketSans',
            ),
          ),
        ),
      ),
    );
  }
}

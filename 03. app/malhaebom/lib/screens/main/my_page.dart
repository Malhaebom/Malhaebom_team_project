// lib/screens/main/my_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/main/interview_list_page.dart';
import 'package:malhaebom/screens/story/story_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ===== 로컬 저장 키 =====
const String PREF_LATEST_ATTEMPT = 'latest_attempt_v1';
const String PREF_ATTEMPT_COUNT = 'attempt_count_v1';
const String PREF_STORY_LATEST_PREFIX = 'story_latest_attempt_v1_';
const String PREF_STORY_COUNT_PREFIX = 'story_attempt_count_v1_';

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

// 동화책 제목 목록(탭 라벨)
const List<String> kStoryTitles = <String>[
  '어머니의 벙어리 장갑',
  '아버지와 결혼식',
  '아들의 호빵',
  '할머니와 바나나',
];

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with TickerProviderStateMixin {
  // ===== 인지검사 =====
  AttemptSummary? _latest;
  int _attemptCount = 0;
  bool _loading = true;

  // ===== 내 동화 기록 =====
  late TabController _storyTabController;
  bool _storyLoading = true;
  final Map<String, StorySummary?> _storyLatest = {};
  final Map<String, int> _storyAttemptCounts = {};

  @override
  void initState() {
    super.initState();
    _storyTabController = TabController(
      length: kStoryTitles.length,
      vsync: this,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _storyTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadLatest(), _loadStoryLatest()]);
  }

  // ===== 인지검사 로드 =====
  Future<void> _loadLatest() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    AttemptSummary? latest;
    final s = prefs.getString(PREF_LATEST_ATTEMPT);
    if (s != null && s.isNotEmpty) {
      try {
        latest = AttemptSummary.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }

    final cnt = prefs.getInt(PREF_ATTEMPT_COUNT) ?? (latest == null ? 0 : 1);

    setState(() {
      _latest = latest;
      _attemptCount = cnt;
      _loading = false;
    });
  }

  // ===== 동화별 최신 결과 로드 =====
  Future<void> _loadStoryLatest() async {
    setState(() => _storyLoading = true);
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('$PREF_STORY_COUNT_PREFIX동화');

    for (final title in kStoryTitles) {
      final keyTitle = _norm(title);

      String? js =
          prefs.getString('$PREF_STORY_LATEST_PREFIX$keyTitle') ??
          prefs.getString('$PREF_STORY_LATEST_PREFIX$title');

      StorySummary? latest;
      if (js != null && js.isNotEmpty) {
        try {
          latest =
              StorySummary.fromJson(jsonDecode(js) as Map<String, dynamic>);
        } catch (_) {}
      }
      _storyLatest[title] = latest;

      int? cnt =
          prefs.getInt('$PREF_STORY_COUNT_PREFIX$keyTitle') ??
          prefs.getInt('$PREF_STORY_COUNT_PREFIX$title');

      _storyAttemptCounts[title] = cnt ?? (latest == null ? 0 : 1);
    }

    setState(() => _storyLoading = false);
  }

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  /// ✅ 제목으로 FairytaleAsset/Index를 찾아서 StoryDetailPage로 진입
  void _goToStoryDetail(String storyTitle) {
    final asset = ft.byTitle(storyTitle);
    final idx = ft.indexByTitle(storyTitle);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryDetailPage(
          title: asset.title,
          storyImg: asset.titleImg,
        ),
        settings: RouteSettings(
          arguments: {
            'storyIndex': idx,
            'storyAsset': asset,
          },
        ),
      ),
    );
  }

  /// ✅ 공통: 이전 기록 페이지로 이동(모드에 따라 서로 다른 화면 구성)
  Future<void> _openHistory(HistoryMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultHistoryPage(mode: mode)),
    );
    if (!mounted) return;
    // 돌아오면 최신 데이터 리프레시
    _loadLatest();
    _loadStoryLatest();
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
                padding:
                    EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
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

  // == 로그아웃 단독 버튼 ==
  Widget _logoutButton(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("로그아웃 되었습니다.")),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 1.w),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(width: 10.w),
                  const Icon(Icons.logout, color: AppColors.text, size: 26),
                  SizedBox(width: 5.w),
                  Text(
                    '로그아웃',
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

  // == 나의 인지 검사 결과 (헤더 탭 누르면 -> 인지 기록 화면) ==
  Widget _myCognitionReportCard(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(height: 5.h),
            // 🔸 헤더 전체 탭 + 우측 꺾쇠
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openHistory(HistoryMode.cognition),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
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
                      Icon(Icons.navigate_next,
                          size: 34.h, color: AppColors.text),
                    ],
                  ),
                ),
              ),
            ),

            // 본문
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: _loading
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

  // == 나의 동화 검사 결과 (헤더 탭 누르면 -> 동화 기록 화면) ==
  Widget _myStoryHistoryCard(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SizedBox(height: 5.h),
            // 🔸 헤더 전체 탭 + 우측 꺾쇠
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openHistory(HistoryMode.story),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
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
                      Icon(Icons.navigate_next,
                          size: 34.h, color: AppColors.text),
                    ],
                  ),
                ),
              ),
            ),

            // 본문
            _storyLoading
                ? Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: _skeleton(),
                  )
                : Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _storyTabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          labelPadding:
                              EdgeInsets.symmetric(horizontal: 14.w),
                          labelColor: AppColors.btnColorDark,
                          unselectedLabelColor: const Color(0xFF6B7280),
                          indicatorColor: AppColors.btnColorDark,
                          labelStyle: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'GmarketSans',
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'GmarketSans',
                          ),
                          tabs: [for (final t in kStoryTitles) Tab(text: t)],
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          height: 520.h,
                          child: TabBarView(
                            controller: _storyTabController,
                            children: [
                              for (final t in kStoryTitles)
                                SingleChildScrollView(
                                  child: (_storyLatest[t] == null)
                                      ? _emptyStory(t) // 첫 검사 전
                                      : _storyCard(
                                          context,
                                          t,
                                          _storyLatest[t]!,
                                          _storyAttemptCounts[t] ?? 0,
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ====== 비어있을 때 (인지검사) ======
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
          Icon(Icons.psychology_alt_outlined,
              size: 40.sp, color: AppColors.text),
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
            '3분이면 끝나요 🙂\n지금 검사하러 가볼까요?',
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

  // ====== 비어있을 때 (동화) : 버튼에서만 디테일로 이동 ======
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

  // ====== 최신 결과 카드(인지검사) ======
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
                        horizontal: 10.w, vertical: 6.h),
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
                    builder: (_) => ir.InterviewResultPage(
                      score: a.score,
                      total: a.total,
                      byCategory: a.byCategory,
                      byType: a.byType ?? <String, ir.CategoryStat>{},
                      testedAt: a.testedAt ?? DateTime.now(),
                      interviewTitle: a.interviewTitle,
                      persist: false,
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

  // ====== 동화 결과 카드 ======
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
                        horizontal: 10.w, vertical: 6.h),
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
              .map((k) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _riskBarRow(k, s.byCategory[k]),
                  )),
          SizedBox(height: 6.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: () async {
                final byCat = s.byCategory.map(
                  (k, v) =>
                      MapEntry(k, sr.CategoryStat(correct: v.correct, total: v.total)),
                );
                final byType = s.byType.map(
                  (k, v) =>
                      MapEntry(k, sr.CategoryStat(correct: v.correct, total: v.total)),
                );
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => sr.StoryResultPage(
                      score: s.score,
                      total: s.total,
                      byCategory: byCat,
                      byType: byType,
                      testedAt: s.testedAt ?? DateTime.now(),
                      storyTitle: storyTitle,
                      persist: false,
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

  // ====== 공통 스켈레톤 ======
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

  // ====== 공용 UI 유틸 ======
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

// ===== 모델 (인지검사) =====
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
            out[key.toString()] =
                ir.CategoryStat(correct: correct, total: total);
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

// ===== 모델 (동화 결과) =====
class StorySummary {
  final String? storyTitle;
  final int score;
  final int total;
  final Map<String, ir.CategoryStat> byCategory;
  final Map<String, ir.CategoryStat> byType;
  final DateTime? testedAt;
  final String? kstLabel;

  StorySummary({
    required this.storyTitle,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    this.testedAt,
    this.kstLabel,
  });

  factory StorySummary.fromJson(Map<String, dynamic> j) {
    Map<String, ir.CategoryStat> _mapStats(dynamic x) {
      if (x is Map) {
        final out = <String, ir.CategoryStat>{};
        x.forEach((key, val) {
          if (val is Map) {
            final correct = (val['correct'] as num?)?.toInt() ?? 0;
            final total = (val['total'] as num?)?.toInt() ?? 0;
            out[key.toString()] =
                ir.CategoryStat(correct: correct, total: total);
          }
        });
        return out;
      }
      return <String, ir.CategoryStat>{};
    }

    DateTime? ts;
    final rawTs = j['attemptTime'] ?? j['testedAt'] ?? j['createdAt'];
    if (rawTs is String) ts = DateTime.tryParse(rawTs);

    return StorySummary(
      storyTitle: j['storyTitle'] as String?,
      score: (j['score'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      byCategory: _mapStats(j['byCategory']),
      byType: _mapStats(j['byType']),
      testedAt: ts,
      kstLabel: j['clientKst'] as String?,
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

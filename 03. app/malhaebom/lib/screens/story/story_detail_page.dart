// Flutter UI 제작 기본 라이브러리
import 'package:malhaebom/screens/story/story_testInfo_page.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/data/fairytale_assets.dart';
// 앱 공통 색상 정의
import 'package:malhaebom/theme/colors.dart';
// 화면 크기에 맞춰 UI 요소 크기를 자동 조정하는 패키지
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 오버레이/사용 페이지 라우팅
import 'watch_how_overlay_page.dart';

// 녹음 페이지 라우팅 추가
import 'package:malhaebom/screens/story/story_record_page.dart';

// 워크북 오버레이
import 'package:malhaebom/screens/story/story_workbook_overlay.dart';

/// ===== 전역 리소스 & 디자인 상수 =====
const String kCoverAsset = 'assets/story/mother_gloves_cover.png';
const String kIcoLock = 'assets/icons/ico_lock.png';
const String kIcoCheck = 'assets/icons/ico_check.png';
const String kIcoPencil = 'assets/icons/ico_pencil.png';
const String kIcoDrama = 'assets/icons/ico_drama.png';

const String kFont = 'GmarketSans'; // 상단바와 본문 통일 폰트
const Color kDivider = Color(0xFFE5E7EB);
const Color kTextDark = Color(0xFF202124);
const Color kTextSub = Color(0xFF6B7280);

/// 스토리(이야기) 상세 페이지
class StoryDetailPage extends StatefulWidget {
  const StoryDetailPage({
    super.key,
    required this.title, // 초기 페이지 제목 (스토리 이름)
    required this.storyImg,
    this.legacyDefault = false, // true면 진입 시 레거시(페이지 교체) 모드로 시작
  });

  final String title;
  final String storyImg;
  final bool legacyDefault;

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  late int _pageIndex;
  late PageController _pageCtrl;
  late bool _legacyMode; // true: 이전 방식(Navigator 교체), false: 슬라이드

  @override
  void initState() {
    super.initState();
    _legacyMode = widget.legacyDefault;
    final initIndex = Fairytales.indexWhere((t) => t.title == widget.title);
    _pageIndex = (initIndex >= 0) ? initIndex : 0;
    _pageCtrl = PageController(initialPage: _pageIndex, viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _legacyMode = !_legacyMode;
    });
  }

  void _goPrev() {
    final total = Fairytales.length;
    final prevIndex = (_pageIndex > 0) ? _pageIndex - 1 : total - 1;
    if (_legacyMode) {
      final prevTale = Fairytales[prevIndex];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => StoryDetailPage(
                title: prevTale.title,
                storyImg: prevTale.titleImg,
                legacyDefault: true,
              ),
        ),
      );
    } else {
      _animateTo(prevIndex);
    }
  }

  void _goNext() {
    final total = Fairytales.length;
    final nextIndex = (_pageIndex < total - 1) ? _pageIndex + 1 : 0;
    if (_legacyMode) {
      final nextTale = Fairytales[nextIndex];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => StoryDetailPage(
                title: nextTale.title,
                storyImg: nextTale.titleImg,
                legacyDefault: true,
              ),
        ),
      );
    } else {
      _animateTo(nextIndex);
    }
  }

  void _animateTo(int index) {
    setState(() => _pageIndex = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tale = Fairytales[_pageIndex]; // 현재 선택된 동화
    final totalTales = Fairytales.length;

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return Scaffold(
      // ===== 상단 AppBar =====
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        // automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: _appBarH(context),
        title: Text(
          tale.title,
          key: ValueKey('appbar_${tale.title}'),
          textScaler: const TextScaler.linear(1.0),
          style: TextStyle(
            fontFamily: kFont,
            fontWeight: FontWeight.w700,
            fontSize: 20.sp,
            color: AppColors.white,
          ),
        ),
        // actions: [
        //   // 모드 토글 버튼: 슬라이드 <-> 레거시
        //   IconButton(
        //     tooltip: _legacyMode ? '슬라이드 모드로 전환' : '이전 방식(페이지 이동)으로 전환',
        //     onPressed: _toggleMode,
        //     icon: Icon(
        //       _legacyMode ? Icons.swipe : Icons.open_in_new,
        //       color: Colors.white,
        //     ),
        //   ),
        //   SizedBox(width: 6.w),
        // ],
      ),
      backgroundColor: AppColors.background,

      // ===== 본문 =====
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
        children: [
          // --- 표지 배너 (동화 이미지: 좌우 스와이프 PageView) ---
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kDivider),
            ),
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
            child: SizedBox(
              height: 190.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _pageIndex = i),
                    itemCount: totalTales,
                    physics:
                        _legacyMode
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final t = Fairytales[index];
                      return AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: index == _pageIndex ? 1.0 : 0.95,
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: Image.asset(t.titleImg, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),

                  // 왼쪽/오른쪽 네비게이션 버튼
                  Positioned(
                    left: 0,
                    child: IconButton(
                      onPressed: _goPrev,
                      icon: const Icon(Icons.chevron_left),
                      color: Colors.black54,
                      iconSize: 28.sp,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      onPressed: _goNext,
                      icon: const Icon(Icons.chevron_right),
                      color: Colors.black54,
                      iconSize: 28.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 14.h),

          // --- 서브 카피 ---
          Center(
            child: Text(
              '동화 시청만으로 인지검사와 다양한 활동까지!',
              textAlign: TextAlign.center,
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w400,
                fontSize: 14.sp,
                color: kTextSub,
                height: 1.35,
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // --- 알약 버튼 4개 ---
          _ActionPill(
            iconAsset: kIcoLock,
            fallbackIcon: Icons.lock_outline,
            title: '동화보기',
            subtitle: '영상으로 재생되는\n동화 시청하기',
            onTap: () {
              Navigator.of(context).push(
                WatchHowOverlayPage.route(
                  title: tale.title,
                  storyImg: tale.titleImg,
                ),
              );
            },
          ),
          SizedBox(height: 12.h),

          _ActionPill(
            iconAsset: kIcoCheck,
            fallbackIcon: Icons.assignment_turned_in_outlined,
            title: '화행 인지검사',
            subtitle: '동화 퀴즈 풀고\n인지능력 진단받기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StoryTestinfoPage(
                        title: tale.title,
                        storyImg: tale.titleImg,
                      ),
                ),
              );
            },
          ),
          SizedBox(height: 12.h),

          // 워크북: 오버레이 → '워크북 풀기' → 진행 페이지
          _ActionPill(
            iconAsset: kIcoPencil,
            fallbackIcon: Icons.brush_outlined,
            title: '워크북 풀어보기',
            subtitle: '재밌고 간단한 활동으로\n인지능력 강화하기',
            onTap: () {
              final ft = Fairytales[_pageIndex];
              Navigator.push(
                context,
                StoryWorkbookOverlayPage.route(
                  title: ft.title,
                  storyImg: ft.titleImg,
                  workbookJson: ft.workbookJson,
                  workbookImgBase: ft.workbookImg,
                ),
              );
            },
          ),
          SizedBox(height: 12.h),

          _ActionPill(
            iconAsset: kIcoDrama,
            fallbackIcon: Icons.record_voice_over_outlined,
            title: '동화 연극하기',
            subtitle: '이야기 주인공의\n대사 따라하기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                      // TODO: 실제 총 대사 수를 tale 데이터에 넣으셨다면 가져오도록 교체하세요.
                      StoryRecordPage(title: tale.title, totalLines: 38),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ===== 알약형 액션 버튼 =====
class _ActionPill extends StatelessWidget {
  final String? iconAsset;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget iconW =
        (iconAsset != null)
            ? Image.asset(
              iconAsset!,
              width: 22.w,
              height: 22.w,
              errorBuilder:
                  (_, __, ___) => Icon(
                    fallbackIcon,
                    size: 25.sp,
                    color: const Color(0xFF374151),
                  ),
            )
            : Icon(fallbackIcon, size: 25.sp, color: const Color(0xFF374151));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: kDivider),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: iconW,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontFamily: kFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 23.sp,
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontFamily: kFont,
                        fontWeight: FontWeight.w400,
                        fontSize: 15.5.sp,
                        color: kTextSub,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

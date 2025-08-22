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
    required this.title, // 페이지 제목 (스토리 이름)
    required this.storyImg,
  });

  final String title;
  final String storyImg;

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tale = byTitle(widget.title); // 스토리 메타
    final currentIndex = Fairytales.indexWhere((t) => t.title == widget.title);
    final totalTales = Fairytales.length;

    return Scaffold(
      // ===== 상단 AppBar =====
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          child: AppBar(
            backgroundColor: AppColors.btnColorDark,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              widget.title,
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w500,
                fontSize: 30.sp,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),

      backgroundColor: AppColors.background,

      // ===== 본문 =====
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
        children: [
          // --- 표지 배너 (동화 이미지) ---
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kDivider),
            ),
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 160.h,
                    maxHeight: 180.h,
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.asset(widget.storyImg, fit: BoxFit.cover),
                    ),
                  ),
                ),
                // 왼쪽 버튼 (이전 동화 또는 마지막 동화로)
                Positioned(
                  left: 0,
                  child: IconButton(
                    onPressed: () {
                      print('왼쪽 버튼 클릭됨!');
                      print('현재 인덱스: $currentIndex, 총 동화 수: $totalTales');
                      final previousIndex = currentIndex > 0 ? currentIndex - 1 : totalTales - 1;
                      final previousTale = Fairytales[previousIndex];
                      print('이전 동화: ${previousTale.title}');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryDetailPage(
                            title: previousTale.title,
                            storyImg: previousTale.titleImg,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.black54,
                    iconSize: 28.sp,
                  ),
                ),
                // 오른쪽 버튼 (다음 동화 또는 첫 번째 동화로)
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () {
                      print('오른쪽 버튼 클릭됨!');
                      print('현재 인덱스: $currentIndex, 총 동화 수: $totalTales');
                      final nextIndex = currentIndex < totalTales - 1 ? currentIndex + 1 : 0;
                      final nextTale = Fairytales[nextIndex];
                      print('다음 동화: ${nextTale.title}');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryDetailPage(
                            title: nextTale.title,
                            storyImg: nextTale.titleImg,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.black54,
                    iconSize: 28.sp,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // --- 서브 카피 ---
          Center(
            child: Text(
              '동화 시청만으로 인지검사와 다양한 활동까지!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w400,
                fontSize: 13.sp,
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
            subtitle: '영상으로 재생되는 동화 시청하기',
            onTap: () {
              Navigator.of(context).push(
                WatchHowOverlayPage.route(
                  title: widget.title,
                  storyImg: widget.storyImg,
                ),
              );
            },
          ),
          SizedBox(height: 12.h),

          _ActionPill(
            iconAsset: kIcoCheck,
            fallbackIcon: Icons.assignment_turned_in_outlined,
            title: '화행 인지검사',
            subtitle: '동화 퀴즈 풀고 인지능력 진단받기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StoryTestinfoPage(
                        title: widget.title,
                        storyImg: widget.storyImg,
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
            subtitle: '재밌고 간단한 활동으로 인지능력 강화하기',
            onTap: () {
              Navigator.push(
                context,
                StoryWorkbookOverlayPage.route(
                  title: widget.title,
                  storyImg: widget.storyImg, // 오버레이에서도 이 이미지를 활용
                  workbookJson: tale.workbookJson,
                  workbookImgBase: tale.workbookImg,
                ),
              );
            },
          ),
          SizedBox(height: 12.h),

          _ActionPill(
            iconAsset: kIcoDrama,
            fallbackIcon: Icons.record_voice_over_outlined,
            title: '동화 연극하기',
            subtitle: '이야기 주인공의 대사 따라하기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          StoryRecordPage(title: widget.title, totalLines: 38),
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
                    size: 22.sp,
                    color: const Color(0xFF374151),
                  ),
            )
            : Icon(fallbackIcon, size: 22.sp, color: const Color(0xFF374151));

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
                      style: TextStyle(
                        fontFamily: kFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 20.sp,
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFont,
                        fontWeight: FontWeight.w400,
                        fontSize: 12.5.sp,
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

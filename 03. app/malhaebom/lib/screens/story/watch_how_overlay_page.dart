import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/data/fairytale_assets.dart';
import 'watch_usage_page.dart';

const _kFont = 'GmarketSans';
const _overlayBg = Color(0xCC2B2B2B); // 오버레이 딤
const _ctaYellow = Color(0xFFFACC15); // 메인 코인색

// ▼ 프리뷰 이미지(선택)

// 프리뷰(오버레이 미리보기용) - 로컬 에셋 이미지 사용
const String kPreviewImageAsset = './assets/images/overlayfairy.png';

/// 오버레이 형태의 "동화 시청 방법"
class WatchHowOverlayPage extends StatelessWidget {
  const WatchHowOverlayPage({
    super.key,
    required this.title,
    required this.storyImg,
  });

  final String title;
  final String storyImg;

  static PageRoute<void> route({
    required String title,
    required String storyImg,
  }) => PageRouteBuilder(
    opaque: false,
    barrierColor: _overlayBg,
    pageBuilder:
        (_, __, ___) => WatchHowOverlayPage(title: title, storyImg: storyImg),
    transitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder:
        (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // 중앙 카드
            Center(
              child: Container(
                width: 320.w,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 파란 헤더
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                      child: Container(
                        width: double.infinity,
                        color: AppColors.btnColorDark,
                        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.18),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Text(
                                '동화 시청 방법',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.sp,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              '어떻게 사용하나요?',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 18.sp,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 프리뷰(이미지) + 재생 아이콘
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 6.h),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Image.asset(
                                kPreviewImageAsset,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.play_circle_fill,
                            size: 56.sp,
                            color: AppColors.btnColorDark,
                          ),
                        ],
                      ),
                    ),
                    // 설명 리스트
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                      child: Column(
                        children: [
                          _row(
                            icon: Icons.play_arrow_rounded,
                            text: '동영상을 재생해줘요.',
                          ),
                          SizedBox(height: 8.h),
                          _row(
                            icon: Icons.crop_free, // 전체 화면 아이콘
                            text: '동영상을 전체 화면으로 보여줘요.',
                            dim: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 우상단 '나가기' — 워크북 오버레이와 동일 스타일/크기
            Positioned(
              top: 10.h,
              right: 14.w,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.85),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(color: Colors.white.withOpacity(0.55)),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '나가기',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 18.sp,
                  ),
                ),
              ),
            ),

            // 하단 CTA
            Positioned(
              left: 24.w,
              right: 24.w,
              bottom: 28.h,
              child: GestureDetector(
                onTap: () {
                  try {
                    final tale = byTitle(title);
                    debugPrint('[WatchHowOverlay] title="$title" -> video="${tale.video}"');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => WatchUsagePage(
                              title: title,
                              videoSource: tale.video,
                              storyImg: storyImg,
                            ),
                      ),
                    );
                  } catch (e) {
                    debugPrint('[WatchHowOverlay][ERROR] $e');
                    final all = Fairytales.map((f) => f.title).join(', ');
                    debugPrint('[WatchHowOverlay] Available titles: $all');
                  }
                },
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ctaYellow,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Text(
                    '동화 보러가기',
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.sp,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String text,
    bool dim = false,
  }) {
    final color = dim ? Colors.black38 : Colors.black87;
    final weight = dim ? FontWeight.w400 : FontWeight.w500;
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: color),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: _kFont,
              fontWeight: weight,
              fontSize: 14.sp,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

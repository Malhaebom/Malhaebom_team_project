import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';
import 'story_workbook_page.dart';

const String _kFont = 'GmarketSans';

class StoryWorkbookOverlayPage extends StatelessWidget {
  final String title;
  final String storyImg;
  final String workbookJson;
  final String workbookImgBase;
  final String? fingerAsset; // 손가락 일러스트(옵션)

  const StoryWorkbookOverlayPage({
    super.key,
    required this.title,
    required this.storyImg,
    required this.workbookJson,
    required this.workbookImgBase,
    this.fingerAsset,
  });

  static Route route({
    required String title,
    required String storyImg,
    required String workbookJson,
    required String workbookImgBase,
    String? fingerAsset,
  }) {
    return MaterialPageRoute(
      builder:
          (_) => StoryWorkbookOverlayPage(
            title: title,
            storyImg: storyImg,
            workbookJson: workbookJson,
            workbookImgBase: workbookImgBase,
            fingerAsset: fingerAsset,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      minTextAdapt: true,
      builder: (ctx, __) {
        const fixedScale = TextScaler.linear(1.0); // 전역 글자 스케일 고정
        final mq = MediaQuery.maybeOf(ctx) ?? const MediaQueryData();
        return MediaQuery(
          data: mq.copyWith(textScaler: fixedScale),
          child: Scaffold(
            backgroundColor: Colors.black.withOpacity(0.75),
            body: SafeArea(
              child: Stack(
                children: [
                  // 우상단 '나가기'
                  Positioned(
                    right: 14.w,
                    top: 10.h,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.85),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.55),
                          ),
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

                  // 가운데 카드 + 버튼
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(28.w, 48.h, 28.w, 24.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ===== 카드 (크기 축소) =====
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 280.w),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ===== 파란 헤더 =====
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.btnColorDark,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(18.r),
                                        topRight: Radius.circular(18.r),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '그림으로 쉽게 푸는 워크북',
                                          style: TextStyle(
                                            fontFamily: _kFont,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 13.sp,
                                            color: Colors.white.withOpacity(
                                              0.80,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 3.h),
                                        Text(
                                          '맞는 답안 고르기',
                                          style: TextStyle(
                                            fontFamily: _kFont,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 21.sp,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ===== 본문 =====
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16.w,
                                      14.h,
                                      16.w,
                                      16.h,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '정답을 체크해 주세요!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: _kFont,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 18.sp,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        SizedBox(height: 10.h),

                                        // 문제 예시 파란 캡슐
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 7.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF5A78CF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '영희네 가족이 물건을 마련하는 방법은 무엇인가요?',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: _kFont,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.sp,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),

                                        SizedBox(height: 10.h),

                                        // === 정사각 2×2 네모 박스 ===
                                        // 겉: 더 진한 회색 테두리, 칸: 은은한 테두리 + 얕은 그림자
                                        Container(
                                          width: 200.w,
                                          height: 200.w, // 정사각형
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF6B7280,
                                              ), // 진한 회색(확실히 보이게)
                                              width: 2.0,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(6.w),
                                          child: GridView.builder(
                                            itemCount: 4,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  mainAxisSpacing: 6.w,
                                                  crossAxisSpacing: 6.w,
                                                ),
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemBuilder: (_, i) {
                                              final cell = Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF9CA3AF,
                                                    ), // 칸별 은은한 테두리
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      blurRadius: 3,
                                                      offset: const Offset(
                                                        1,
                                                        1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              // 오른쪽 아래 칸에 손가락 일러스트 삽입
                                              if (i == 3) {
                                                return Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: cell,
                                                    ),
                                                    // 칸 내부 중앙에 손가락
                                                    Center(
                                                      child:
                                                          (fingerAsset != null)
                                                              ? Image.asset(
                                                                fingerAsset!,
                                                                width: 42.w,
                                                                height: 42.w,
                                                                fit:
                                                                    BoxFit
                                                                        .contain,
                                                              )
                                                              : Icon(
                                                                Icons.touch_app,
                                                                size: 36.sp,
                                                                color:
                                                                    const Color(
                                                                      0xFF6B7280,
                                                                    ),
                                                              ),
                                                    ),
                                                  ],
                                                );
                                              }
                                              return cell;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 18.h),

                          // ===== 노란 CTA =====
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 280.w),
                            child: SizedBox(
                              width: double.infinity,
                              height: 60.h,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD43B),
                                  foregroundColor: Colors.black,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => StoryWorkbookPage(
                                            title: title,
                                            jsonAssetPath: workbookJson,
                                            imageBaseDir: workbookImgBase,
                                          ),
                                    ),
                                  );
                                },
                                child: Text(
                                  '워크북 풀기',
                                  style: TextStyle(
                                    fontFamily: _kFont,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

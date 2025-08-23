// lib/screens/story/story_main_page.dart
// 데이터(Fairytales)는 그대로 사용. 파란 AppBar(얇고 큼) + 큼직한 카드 UI
// 세부 설명(소개 문구) 글자만 더 작게 + 최대 3줄로 보이게 조정.

import 'package:malhaebom/screens/story/story_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/widgets/back_to_home.dart';
import 'package:malhaebom/data/fairytale_assets.dart';

const String _kFont = 'GmarketSans';

class StoryMainPage extends StatefulWidget {
  const StoryMainPage({super.key});

  @override
  State<StoryMainPage> createState() => _StoryMainPageState();
}

class _StoryMainPageState extends State<StoryMainPage> {
  @override
  Widget build(BuildContext context) {
    final tales = Fairytales; // ✅ 데이터는 건드리지 않음

    return ScreenUtilInit(
      minTextAdapt: true,
      builder:
          (_, __) => BackToHome(
            child: Scaffold(
              // ===== 파란 AppBar (얇고 크게) =====
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(62.h),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: AppBar(
                    automaticallyImplyLeading: true,
                    centerTitle: true,
                    backgroundColor: AppColors.btnColorDark,
                    elevation: 0,
                    title: Text(
                      '회상 동화',
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500, // 얇게
                        fontSize: 28.sp, // 크게
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              backgroundColor: AppColors.background,

              // ===== 본문: 큼직한 카드 리스트 =====
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 24.h),
                  child: Column(
                    children: List.generate(tales.length, (index) {
                      final tale = tales[index];
                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => StoryDetailPage(
                                        title: tale.title,
                                        storyImg: tale.titleImg,
                                      ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(22.r),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(22.r),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 좌측 썸네일 — 크게
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18.r),
                                    child: Container(
                                      width: 92.w,
                                      height: 92.w,
                                      color: const Color(0xFFF3F4F6),
                                      child: Image.asset(
                                        tale.titleImg,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),

                                  // 우측 텍스트
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 제목 — 크게/진하게
                                        Text(
                                          tale.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: _kFont,
                                            fontSize: 19.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF111827),
                                            height: 1.1,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        // 소개 — ✅ 더 작게 + 최대 3줄 (가독성 + 내용 노출 밸런스)
                                        Text(
                                          tale.content ?? '소개 문구가 준비 중입니다.',
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 3, // ← 줄 수를 늘려서 더 많이 보이게
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontFamily: _kFont,
                                            fontSize:
                                                13.sp, // ← 기존 14.5 → 13로 축소
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF6B7280),
                                            height: 1.4, // 줄간격 약간 키움
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

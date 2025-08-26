// home_menu_button.dart
import 'dart:math' as math;               // ⬅️ 추가
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';

class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.iconAsset,
    required this.colorIndex,
    required this.btnName,
    required this.btnText,
    required this.nextPage,
  });

  final double screenWidth;
  final double screenHeight;
  final String iconAsset;
  final int colorIndex;
  final String btnName;
  final String btnText;
  final Widget nextPage;

  @override
  Widget build(BuildContext context) {
    final List<Color> colorList = [
      AppColors.btnColorDark,
      AppColors.btnColorLight,
      AppColors.yellow,
    ];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => nextPage),
        );
      },
      child: SizedBox(
        width: screenWidth * 0.4,
        height: screenHeight * 0.25,
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            // ✅ 컨테이너 실제 높이에 맞춘 내부 비율(태블릿에서도 안 터지게)
            final iconH   = h * 0.34;                 // 아이콘 영역
            final gapH    = h * 0.06;                 // 아이콘-텍스트 사이
            // 폰트 사이즈는 ScreenUtil 값과 컨테이너 비율 중 작은 값으로 캡핑
            final titleFs = math.min(18.sp, h * 0.16);
            final subFs   = math.min(13.sp, h * 0.10);

            return Container(
              decoration: BoxDecoration(
                color: colorList[colorIndex],
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(60, 0, 0, 0),
                    spreadRadius: 5,
                    blurRadius: 10,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 아이콘은 컨테이너 높이에 맞춰 안전하게 축소
                  SizedBox(
                    height: iconH,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Image.asset(iconAsset),
                    ),
                  ),

                  SizedBox(height: gapH),

                  // 제목: 1줄, 중앙정렬, 상한 캡
                  Text(
                    btnName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: titleFs,
                      height: 1.15, // 줄간격 압축
                    ),
                  ),

                  SizedBox(height: h * 0.01),

                  // 서브텍스트: 2줄까지, 중앙정렬, 상한 캡
                  Flexible(
                    child: Text(
                      btnText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: subFs,
                        height: 1.2, // 줄간격 조금만
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

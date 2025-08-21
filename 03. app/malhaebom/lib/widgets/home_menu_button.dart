import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      child: Container(
        width: screenWidth * 0.4,
        height: screenHeight * 0.25,
        decoration: BoxDecoration(
          color: colorList[colorIndex],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(60, 0, 0, 0),
              spreadRadius: 5,
              blurRadius: 10,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(iconAsset, height: screenHeight * 0.08),

              SizedBox(height: 15.h),

              Column(
                children: [
                  Text(
                    btnName,
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    btnText,
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w400,
                      fontSize: 13.sp,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    textScaler: const TextScaler.linear(1.0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

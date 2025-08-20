import 'package:malhaebom/screens/main/main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/liquid_circle_progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTrainingResultPage extends StatefulWidget {
  const BrainTrainingResultPage({
    super.key,
    required this.category,
    required this.data,
  });

  final String category;
  final Map<String, dynamic> data;

  @override
  State<BrainTrainingResultPage> createState() =>
      _BrainTrainingResultPageState();
}

class _BrainTrainingResultPageState extends State<BrainTrainingResultPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        title: Center(
          child: Text(
            "테스트 결과",
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
          ),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  LiquidCircleProgressWidget(value: 0.6),

                  SizedBox(width: 20.w),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "레벤님의",
                        style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w600,
                          fontSize: 20.sp,
                        ),
                      ),
                      Text(
                        "${widget.category} 영역 테스트 결과,\n${widget.data.length}개 중 3개를 맞혔어요! ",
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Column(
                          children: List.generate(widget.data.keys.length, (
                            index,
                          ) {
                            return InkWell(
                              onTap: () {},
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey,
                                      width: 1.w,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 5.h),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(width: 10.w),

                                            // 오답
                                            Icon(
                                              Icons
                                                  .indeterminate_check_box_rounded,
                                              color: AppColors.red,
                                              size: 24.h,
                                            ),

                                            // 정답
                                            // Icon(
                                            //   Icons.check_box_rounded,
                                            //   color: AppColors.green,
                                            //   size: 24.h,
                                            // ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              widget.data.keys.toList()[index],
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16.sp,
                                                color: AppColors.text,
                                                fontFamily: 'GmarketSans',
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          Icons.navigate_next,
                                          size: 30.h,
                                          color: AppColors.text,
                                        ),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        SizedBox(width: 10.w),
                                        Flexible(
                                          child: Text(
                                            widget.data[widget.data.keys
                                                .toList()[index]]["title"],
                                            style: TextStyle(fontSize: 13.sp),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                      ],
                                    ),

                                    SizedBox(height: 5.h),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),

                        SizedBox(height: 15.h),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30.h),

              // 홈으로
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MainPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text("홈으로"),
                ),
              ),

              SizedBox(height: 10.h),

              // 다시 풀기
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.blue,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text("다시풀기"),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}

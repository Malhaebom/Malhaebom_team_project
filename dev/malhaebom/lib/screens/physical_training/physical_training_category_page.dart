import 'package:malhaebom/screens/physical_training/physical_training_detail_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/liquid_circle_progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/data/exercise_data.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PhysicalTrainingCategoryPage extends StatefulWidget {
  const PhysicalTrainingCategoryPage({super.key, required this.category});

  final String category;

  @override
  State<PhysicalTrainingCategoryPage> createState() =>
      _PhysicalTrainingCategoryPageState();
}

class _PhysicalTrainingCategoryPageState
    extends State<PhysicalTrainingCategoryPage> {
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    loadData(widget.category);
  }

  void loadData(String category) {
    switch (category) {
      case "운동전 스트레칭":
        setState(() {
          data = ExerciseData.before;
        });
        break;

      case "운동후 스트레칭":
        setState(() {
          data = ExerciseData.after;
        });
        break;

      case "유산소 운동":
        setState(() {
          data = ExerciseData.aerobic;
        });
        break;

      case "근력 운동":
        setState(() {
          data = ExerciseData.strength;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          widget.category,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
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
                  LiquidCircleProgressWidget(value: 0.5),

                  SizedBox(width: 20.w),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "레벤님!",
                        style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w600,
                          fontSize: 20.sp,
                        ),
                      ),
                      Text(
                        "오늘의 운동을 모두 하지 못했어요.\n건강한 몸을 만들어봅시다!",
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
                          children: List.generate(data.keys.length, (index) {
                            return InkWell(
                              onTap: () {
                                // 페이지 이동
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => PhysicalTrainingDetailPage(
                                          title: data.keys.toList()[index],
                                          data: data[data.keys.toList()[index]],
                                        ),
                                  ),
                                );
                              },
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

                                            // 수행전
                                            Icon(
                                              Icons
                                                  .check_box_outline_blank_rounded,
                                              color: AppColors.grey,
                                              size: 24.h,
                                            ),

                                            // // 수행완료
                                            // Icon(
                                            //   Icons.check_box_rounded,
                                            //   color: AppColors.green,
                                            //   size: 24.h,
                                            // ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              data.keys.toList()[index],
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
                                            data[data.keys
                                                .toList()[index]]["caption"],
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
            ],
          ),
        ),
      ),
    );
  }
}

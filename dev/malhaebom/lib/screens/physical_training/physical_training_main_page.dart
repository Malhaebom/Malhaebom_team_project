import 'package:malhaebom/screens/physical_training/physical_training_category_page.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/brain_training_btn.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PhysicalTrainingMainPage extends StatefulWidget {
  const PhysicalTrainingMainPage({super.key});

  @override
  State<PhysicalTrainingMainPage> createState() =>
      _PhysicalTrainingMainPageState();
}

class _PhysicalTrainingMainPageState extends State<PhysicalTrainingMainPage> {
  List<Color> btnColorList = [
    Color(0xFFff0000),
    Color(0xFFf08a2c),
    Color(0xFFe8b100),
    Color(0xFF4bbb06),
  ];

  List<String> btnIconList = [
    "assets/icons/before_activity.png",
    "assets/icons/after_activity.png",
    "assets/icons/aerobic_exercise.png",
    "assets/icons/strength_training.png",
  ];

  List<String> btnTextList = ["운동전 스트레칭", "운동후 스트레칭", "유산소 운동", "근력 운동"];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          "신체 단련",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Column(
            children: [
              Text(
                "오늘은 운동을 해볼까요?\n원하는 운동을 선택해보세요.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),

              SizedBox(height: 20.h),

              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 15.w),
                      child: ListView.builder(
                        itemCount: 2,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              TrainingBtn(
                                screenHeight: screenHeight,
                                screenWidth: screenWidth,
                                btnColor: btnColorList[index * 2],
                                btnIcon: btnIconList[index * 2],
                                btnText: btnTextList[index * 2],
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              PhysicalTrainingCategoryPage(
                                                category:
                                                    btnTextList[index * 2],
                                              ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20.h),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 15.w),
                      child: ListView.builder(
                        itemCount: 2,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              TrainingBtn(
                                screenHeight: screenHeight,
                                screenWidth: screenWidth,
                                btnColor: btnColorList[index * 2 + 1],
                                btnIcon: btnIconList[index * 2 + 1],
                                btnText: btnTextList[index * 2 + 1],
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              PhysicalTrainingCategoryPage(
                                                category:
                                                    btnTextList[index * 2 + 1],
                                              ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20.h),
                            ],
                          );
                        },
                      ),
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

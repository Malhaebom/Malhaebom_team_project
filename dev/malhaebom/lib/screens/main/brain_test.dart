import 'package:malhaebom/screens/main/brain_test_result.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTestPage extends StatefulWidget {
  const BrainTestPage({super.key});

  @override
  State<BrainTestPage> createState() => _BrainTestPageState();
}

class _BrainTestPageState extends State<BrainTestPage> {
  List<bool> checking = [false, false, false, false, false];
  List<String> content = [
    "며칠 전에 들었던 이야기를 잊는다.",
    "약속을 하고 잊은 때가 있다.",
    "약 먹는 시간을 놓치기도 한다.",
    "물건 이름이 금방 생각나지 않는다.",
    "전에 가본 장소를 기억하지 못한다.",
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background),
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  SizedBox(height: 20.h),
                  Text(
                    "두뇌건강 체크리스트",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 25.sp,
                      fontFamily: 'GmarketSans',
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    "최근 6개월 간의\n해당 사항에 체크해주세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    height: screenHeight * 0.5,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage("assets/images/brain_test_note.png"),
                        fit: BoxFit.contain,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(25),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 40.h),
                          ListView.builder(
                            itemCount: 5,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checking[index],
                                      onChanged: (value) {
                                        setState(() {
                                          checking[index] = value!;
                                        });
                                      },
                                      activeColor: AppColors.blue,
                                      checkColor: Colors.white,
                                    ),
                                    Expanded(
                                      child: Text(
                                        content[index],
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 100.h),
                ],
              ),

              Column(
                children: [
                  CustomSubmitButton(
                    btnText: "결과 보기",
                    isActive: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  BrainTestResultPage(checking: checking),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

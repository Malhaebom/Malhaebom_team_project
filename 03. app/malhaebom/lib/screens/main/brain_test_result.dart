import 'package:malhaebom/screens/main/home_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTestResultPage extends StatefulWidget {
  const BrainTestResultPage({super.key, required this.checking});

  final List<bool> checking;

  @override
  State<BrainTestResultPage> createState() => _BrainTestResultPageState();
}

class _BrainTestResultPageState extends State<BrainTestResultPage> {
  late int cnt;
  int statusCode = 0;

  List<String> statusIcon = [
    "assets/icons/great.png",
    "assets/icons/good.png",
    "assets/icons/bad.png",
  ];

  List<String> statusTitle = ["좋음", "보통", "나쁨"];

  List<String> statusContent = [
    "일상생활과 기억력 유지에\n 어려움이 거의 없습니다!\n지금처럼 꾸준히 유지해주세요.",
    "일상에서 가벼운 기억 혼동이 있을 수 있습니다.\n 지금부터 관리하면 충분히 회복할 수 있어요.",
    "최근 기억력 저하가\n자주 나타나고 있을 수 있습니다.\n 빠른 시일 내 전문가 상담 또는 인지훈련을\n권장드립니다.",
  ];

  void getStatus(int cnt) {
    if (cnt == 0 || cnt == 1) {
      setState(() {
        statusCode = 0;
      });
    } else if (cnt == 2 || cnt == 3) {
      setState(() {
        statusCode = 1;
      });
    } else {
      setState(() {
        statusCode = 2;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    cnt = widget.checking.where((e) => e).length;

    getStatus(cnt);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
      ),
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
                    "나의 두뇌 건강은?",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 25.sp,
                      fontFamily: 'GmarketSans',
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    "현재 나의 두뇌 건강 상태는 어떨까요?",
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
                          Image.asset(
                            statusIcon[statusCode],
                            height: screenHeight * 0.15,
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                statusTitle[statusCode],
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            statusContent[statusCode],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 15.sp,
                            ),
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
                    btnText: "홈으로",
                    isActive: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
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

import 'package:malhaebom/screens/main/home_page.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/liquid_circle_progress_widget.dart';
import 'package:malhaebom/screens/brain_training/brain_training_test_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTrainingResultPage extends StatefulWidget {
  const BrainTrainingResultPage({
    super.key,
    required this.category,
    required this.data,
    required this.answers,
  });

  final String category;
  final Map<String, dynamic> data;
  final dynamic answers;

  @override
  State<BrainTrainingResultPage> createState() =>
      _BrainTrainingResultPageState();
}

class _BrainTrainingResultPageState extends State<BrainTrainingResultPage> {
  late int correctAnswers;
  late double correctPercentage;

  @override
  void initState() {
    super.initState();
    calculateResults();
  }

  void calculateResults() {
    correctAnswers = 0;
    final keys = widget.data.keys.toList();
    
    // answers 타입에 따른 처리
    if (widget.answers is List<int>) {
      // 단순 선택형 문제들 (시공간파악, 기억집중, 문제해결능력, 계산능력, 언어능력)
      List<int> simpleAnswers = widget.answers as List<int>;
      
      for (int i = 0; i < simpleAnswers.length; i++) {
        if (i < keys.length) {
          final userAnswer = simpleAnswers[i];
          final correctAnswer = widget.data[keys[i]]["answer"];
          
          bool isCorrect = userAnswer == correctAnswer;
          if (isCorrect) {
            correctAnswers++;
          }
        }
      }
    } else if (widget.answers is List<List>) {
      // 복잡한 터치 패턴 문제들 (알록달록, 음악과터치)
      List<List> complexAnswers = widget.answers as List<List>;
      
      for (int i = 0; i < complexAnswers.length; i++) {
        if (i < keys.length) {
          final userAnswer = complexAnswers[i];
          final correctAnswer = widget.data[keys[i]]["answer"];
          
          // 현재는 단순화하여 처리 (실제로는 터치 패턴 비교 로직 필요)
          bool isCorrect = userAnswer.length == correctAnswer.length;
          if (isCorrect) {
            correctAnswers++;
          }
        }
      }
    }
    
    // 0.0 ~ 1.0 범위의 비율로 계산 (LiquidCircleProgressWidget에서 *100 처리)
    correctPercentage = widget.data.length > 0 ? correctAnswers / widget.data.length : 0.0;
    
    // 디버깅: 값 전달 경로 추적
    print('=== 값 전달 경로 추적 ===');
    print('correctAnswers: $correctAnswers');
    print('widget.data.length: ${widget.data.length}');
    print('correctPercentage 계산: $correctAnswers / ${widget.data.length} = $correctPercentage');
    print('correctPercentage * 100: ${correctPercentage * 100}');
    print('(correctPercentage * 100).toInt(): ${(correctPercentage * 100).toInt()}');
    print('=== 추적 완료 ===');
  }

  void _retryWrongQuestion(int questionIndex) {
    // 틀린 문제로 돌아가기
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BrainTrainingTestPage(
          title: widget.category,
          retryIndex: questionIndex,
          retryAnswers: widget.answers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.text),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => BrainTrainingMainPage()),
                (route) => false,
              );
            },
          ),
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
                  // LiquidCircleProgressWidget 복원
                  LiquidCircleProgressWidget(value: correctPercentage),

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
                        "${widget.category} 영역 테스트 결과,\n${widget.data.length}개 중 $correctAnswers개를 맞혔어요! ",
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
                            final keys = widget.data.keys.toList();
                            final correctAnswer = widget.data[keys[index]]["answer"];
                            
                            // answers 타입에 따른 정답 판정
                            bool isCorrect = false;
                            
                            if (widget.answers is List<int>) {
                              // 단순 선택형 문제들
                              List<int> simpleAnswers = widget.answers as List<int>;
                              if (index < simpleAnswers.length) {
                                final userAnswer = simpleAnswers[index];
                                isCorrect = userAnswer == correctAnswer;
                              }
                            } else if (widget.answers is List<List>) {
                              // 복잡한 터치 패턴 문제들
                              List<List> complexAnswers = widget.answers as List<List>;
                              if (index < complexAnswers.length) {
                                final userAnswer = complexAnswers[index];
                                // 현재는 단순화하여 처리
                                isCorrect = userAnswer.length == correctAnswer.length;
                              }
                            }
                            
                                                         return InkWell(
                               onTap: () {
                                 // 틀린 문제인 경우에만 재시도 가능
                                 if (!isCorrect) {
                                   _retryWrongQuestion(index);
                                 }
                               },
                                                             child: Container(
                                 decoration: BoxDecoration(
                                   color: !isCorrect ? Colors.red.withOpacity(0.1) : null,
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

                                            // 정답/오답 아이콘
                                            Icon(
                                              isCorrect 
                                                  ? Icons.check_box_rounded
                                                  : Icons.indeterminate_check_box_rounded,
                                              color: isCorrect ? AppColors.green : AppColors.red,
                                              size: 24.h,
                                            ),
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
                                           isCorrect 
                                               ? Icons.navigate_next
                                               : Icons.navigate_next,
                                           size: 30.h,
                                           color: isCorrect ? AppColors.text : AppColors.red,
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
                      MaterialPageRoute(builder: (context) => HomePage()),
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

import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  bool isActiveAppBtn = true;
  bool isActiveCompanyBtn = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /*
                    브레인업 소개 탭
                  */
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isActiveAppBtn = true;
                          isActiveCompanyBtn = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isActiveAppBtn ? AppColors.blue : AppColors.white,
                        foregroundColor:
                            isActiveAppBtn ? AppColors.white : AppColors.text,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        textStyle: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text("서비스 소개"),
                    ),
                  ),

                  SizedBox(width: 15.w),

                  /*
                    회사 소개 탭
                  */
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isActiveAppBtn = false;
                          isActiveCompanyBtn = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isActiveCompanyBtn
                                ? AppColors.blue
                                : AppColors.white,
                        foregroundColor:
                            isActiveCompanyBtn ? AppColors.white : Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        textStyle: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text("회사 소개"),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 15.h),

            isActiveAppBtn ? AppInfo() : CompanyInfo(),
          ],
        ),
      ),
    );
  }
}

/* 

  서비스 소개 탭

*/
class AppInfo extends StatelessWidget {
  const AppInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 10.h,
                decoration: BoxDecoration(color: AppColors.purple),
              ),
              SizedBox(height: 10.h),
              Text(
                "브레인업",
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                "어르신들의 기억을 지키고, 삶의 이야기를 되살리는 브레인업은 노인을 위한 인지강화 교육 앱입니다. 일상 속 이야기와 회상 활동을 통해 복잡하지 않게, 어렵지 않게, 누구나 쉽게 두뇌 건강을 관리할 수 있는 모바일 앱입니다.",
                style: TextStyle(fontSize: 15.sp),
              ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        Image.asset("assets/images/app_info_img1.png", width: double.infinity),

        SizedBox(height: 40.h),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 10.h,
                decoration: BoxDecoration(color: AppColors.purple),
              ),
              SizedBox(height: 10.h),
              Text(
                "이런 분들께 추천합니다!",
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                "최근 기억력이 예전 같지 않다고 느끼시는 어르신,\n부모님, 조부모님의 인지 건강이 걱정되는 가족,\n노인 대상 프로그램을 운영하는 요양기관, 복지관, 주간보호센터",
                style: TextStyle(fontSize: 15.sp),
              ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        Image.asset("assets/images/app_info_img2.png", width: double.infinity),

        SizedBox(height: 40.h),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 10.h,
                decoration: BoxDecoration(color: AppColors.purple),
              ),
              SizedBox(height: 10.h),
              Text(
                "소중한 기억을 지키는 일,\n브레인업이 함께 하겠습니다!",
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                "주식회사 레벤그리다는 어르신의 오늘을 더 따뜻하게, 내일을 더 건강하게 만들기 위해 브레인업을 만들었습니다.",
                style: TextStyle(fontSize: 15.sp),
              ),
            ],
          ),
        ),

        SizedBox(height: 40.h),
      ],
    );
  }
}

/* 

  회사 소개 탭

*/
class CompanyInfo extends StatelessWidget {
  CompanyInfo({super.key});

  final List<String> logo = [
    "assets/images/lebengrida.png",
    "assets/images/youtube.png",
    "assets/images/naver_store.png",
    "assets/images/naver_blog.png",
    "assets/images/naver_band.png",
    "assets/images/facebook.png",
    "assets/images/instagram.png",
  ];
  final List<String> title = [
    "홈페이지",
    "유튜브",
    "스마트 스토어",
    "블로그",
    "밴드",
    "페이스북",
    "인스타그램",
  ];
  final List<Uri> url = [
    Uri.parse("https://lebengrida.co.kr/"),
    Uri.parse(
      "https://www.youtube.com/@%EB%A0%88%EB%B2%A4%EA%B7%B8%EB%A6%AC%EB%8B%A4%ED%95%9C%EA%B5%AD%EB%AC%B8%ED%99%94%EB%8B%A4",
    ),
    Uri.parse("https://smartstore.naver.com/lebengrida"),
    Uri.parse("https://blog.naver.com/lebengrida"),
    Uri.parse("https://band.us/band/80747795"),
    Uri.parse("https://www.facebook.com/lebengridaKCDlab"),
    Uri.parse("https://www.instagram.com/lebengrida_kcdlab"),
  ];

  Future<void> _launchUrl(url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 10.h,
                decoration: BoxDecoration(color: AppColors.purple),
              ),
              SizedBox(height: 10.h),
              Text(
                "레벤그리다",
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                "(주)레벤그리다는 다문화 관련 기업 및 교육 기업들과 협업을 통해 교육 프로그래밍 개발과 다양성 교육 및 행사를 진행하는 기업입니다.",
                style: TextStyle(fontSize: 15.sp),
              ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        Image.asset(
          "assets/images/brand_info_img1.jpg",
          width: double.infinity,
        ),

        SizedBox(height: 40.h),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 10.h,
                decoration: BoxDecoration(color: AppColors.purple),
              ),
              SizedBox(height: 10.h),
              Text(
                "뇌든든! 정상적으로 살아가기 위해 생각하고, 기억하고, 말하고, 실행하는 인지기능 향상!",
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                "정부의 치매국가책임제 추진을 계기로 ‘치매’에 대한 사회적 관심이 고조되고 있는 가운데 치매예방을 위한 신개념의 교육 프로그램이 각광을 받고 있습니다. 주식회사 레벤그리다문화양성연구원은 어르신들의 인지장애 예방 인지교육 프로그램을 제공하는 시니어 교육 전문 기업입니다.",
                style: TextStyle(fontSize: 15.sp),
              ),
            ],
          ),
        ),

        SizedBox(height: 20.sp),

        Image.asset(
          "assets/images/brand_info_img2.png",
          width: double.infinity,
        ),

        SizedBox(height: 40.sp),

        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "레벤그리다는 사람의 소중함을 알고있습니다.",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
            ),
            Text(
              "앞으로의 날들은 매우 가치있다는 것을 알고있습니다.",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
            ),
            Text(
              "고객님들의 삶에 언제나 따스함이 깃들도록 함께하겠습니다.",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
            ),

            SizedBox(height: 40.h),
          ],
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 10.h,
                decoration: BoxDecoration(color: AppColors.purple),
              ),
              SizedBox(height: 10.h),
              Text(
                "바로가기",
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: 5.h),

              InkWell(
                onTap: () {
                  _launchUrl(Uri.parse("https://youtu.be/ErNlR7O2WMg"));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "홍보영상 보러가기",
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    Column(
                      children: List.generate(7, (index) {
                        return InkWell(
                          onTap: () {
                            _launchUrl(url[index]);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 5.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Image.asset(logo[index], width: 40.w),
                                Text(
                                  title[index],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                Icon(Icons.navigate_next, size: 40.sp),
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

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ],
    );
  }
}

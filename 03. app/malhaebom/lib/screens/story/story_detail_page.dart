// Flutter UI 제작 기본 라이브러리
import 'package:malhaebom/screens/story/story_testInfo_page.dart';
import 'package:flutter/material.dart';
// 앱 공통 색상 정의
import 'package:malhaebom/theme/colors.dart';
// 화면 크기에 맞춰 UI 요소 크기를 자동 조정하는 패키지
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 오버레이/사용 페이지 라우팅
import 'watch_how_overlay_page.dart';

// 녹음 페이지 라우팅 추가
import 'package:malhaebom/screens/story/story_record_page.dart';

/// ===== 전역 리소스 & 디자인 상수 =====
const String kCoverAsset = 'assets/story/mother_gloves_cover.png';
const String kIcoLock = 'assets/icons/ico_lock.png';
const String kIcoCheck = 'assets/icons/ico_check.png';
const String kIcoPencil = 'assets/icons/ico_pencil.png';
const String kIcoDrama = 'assets/icons/ico_drama.png';

const String kFont = 'GmarketSans'; // 상단바와 본문 통일 폰트
const Color kDivider = Color(0xFFE5E7EB);
const Color kTextDark = Color(0xFF202124);
const Color kTextSub = Color(0xFF6B7280);

// 진행 스트립 컬러
const Color kStepDark = Color(0xFF0B1551); // 원 배경(진남)
const Color kStepLite = Color(0xFF5A78CF); // 파이/연결선(밝은 파랑)
const Color kCoin = Color(0xFFFACC15);
const Color kCoinText = Color(0xFF7C5B00);

/// 스토리(이야기) 상세 페이지
class StoryDetailPage extends StatefulWidget {
  const StoryDetailPage({
    super.key,
    required this.title, // 페이지 제목 (스토리 이름)
    required this.storyImg,
  });

  final String title;
  final String storyImg;

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ===== 상단 AppBar (주신 틀 유지) =====
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          child: AppBar(
            backgroundColor: AppColors.btnColorDark,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              widget.title,
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w500, // ← 요청: 안 굵게
                fontSize: 30.sp,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),

      backgroundColor: AppColors.background,

      // ===== 본문 =====
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
        children: [
          // --- 표지 배너 (좌/우 화살표) ---
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kDivider),
            ),
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 160.h,
                    maxHeight: 180.h,
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.asset(widget.storyImg, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.black54,
                    iconSize: 28.sp,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.black54,
                    iconSize: 28.sp,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // --- 서브 카피 ---
          Center(
            child: Text(
              '동화 시청만으로 인지검사와 다양한 활동까지!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w400,
                fontSize: 13.sp,
                color: kTextSub,
                height: 1.35,
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // --- 알약 버튼 4개 (제목 더 크고/더 굵게) ---
          _ActionPill(
            iconAsset: kIcoLock,
            fallbackIcon: Icons.lock_outline,
            title: '동화보기',
            subtitle: '영상으로 재생되는 동화 시청하기',
            onTap: () {
              Navigator.of(context).push(
                WatchHowOverlayPage.route(
                  title: widget.title,
                  storyImg: widget.storyImg,
                ),
              );
            },
          ),
          SizedBox(height: 12.h),
          _ActionPill(
            iconAsset: kIcoCheck,
            fallbackIcon: Icons.assignment_turned_in_outlined,
            title: '화행 인지검사',
            subtitle: '동화 퀴즈 풀고 인지능력 진단받기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StoryTestinfoPage(
                        title: widget.title,
                        storyImg: widget.storyImg,
                      ),
                ),
              );
            },
          ),
          SizedBox(height: 12.h),
          _ActionPill(
            iconAsset: kIcoPencil,
            fallbackIcon: Icons.brush_outlined,
            title: '워크북 풀어보기',
            subtitle: '재밌고 간단한 활동으로 인지능력 강화하기',
          ),
          SizedBox(height: 12.h),
          _ActionPill(
            iconAsset: kIcoDrama,
            fallbackIcon: Icons.record_voice_over_outlined,
            title: '동화 연극하기',
            subtitle: '이야기 주인공의 대사 따라하기',
            onTap: () {
              // >>> 여기서 녹음 페이지로 이동 <<<
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StoryRecordPage(
                        title: widget.title,
                        totalLines: 38, // 필요 시 변경
                      ),
                ),
              );
            },
          ),

          SizedBox(height: 22.h),

          // --- 진행 스트립 (배경 카드 없음 / 파이 위 라벨 얇게) ---
          const _ProgressStrip(),

          SizedBox(height: 10.h),

          Center(
            child: Text(
              '모든 활동을 끝내고 코인받으세요!',
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w700,
                fontSize: 12.5.sp,
                color: kTextDark,
              ),
            ),
          ),
        ],
      ),

      // ===== 하단 툴바(네비게이션) =====
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.btnColorDark,
          unselectedItemColor: const Color(0xFF9CA3AF),
          showUnselectedLabels: true,
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          selectedLabelStyle: TextStyle(
            fontSize: 12.sp,
            fontFamily: kFont,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12.sp,
            fontFamily: kFont,
            fontWeight: FontWeight.w400,
          ),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.apps), label: '활동'),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: '훈련',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '결과'),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: '소통',
            ),
          ],
        ),
      ),
    );
  }
}

//// ===== 진행 스트립 =====
/// 라벨(파란색, 원 '위', 얇게) + 파이 원 + 파란 연결선 + (오른쪽 끝) 200P(위)/코인(아래)
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 오른쪽 200P/코인 공간을 확보하고 4 스텝 폭 산정
        final double colW = (c.maxWidth - 70.w) / 4;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StepColumn(label: '동화', colWidth: colW),
            _StepConnector(),
            StepColumn(label: '검사', colWidth: colW),
            _StepConnector(),
            StepColumn(label: '워크북', colWidth: colW), // 워크북 줄바꿈/쏠림 방지
            _StepConnector(),
            StepColumn(label: '연극', colWidth: colW),

            SizedBox(width: 10.w),

            // 200P(위) + 코인(아래)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '200P',
                  style: TextStyle(
                    fontFamily: kFont,
                    fontWeight: FontWeight.w400, // ← 얇게
                    fontSize: 16.sp,
                    color: AppColors.btnColorDark,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  width: 26.w,
                  height: 26.w,
                  decoration: const BoxDecoration(
                    color: kCoin,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'C',
                    style: TextStyle(
                      fontFamily: kFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                      color: kCoinText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 하나의 스텝(라벨↑ + 파이 원)
class StepColumn extends StatelessWidget {
  final String label;
  final double colWidth;
  const StepColumn({super.key, required this.label, required this.colWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: colWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- 라벨: 파란색, 얇게, 절대 줄바꿈 금지 ----
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                fontFamily: kFont,
                fontWeight: FontWeight.w400, // ← 요청: 얇게
                fontSize: 12.sp,
                color: AppColors.btnColorDark,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          const StepCircle(progress: 0.22, startAngle: -3.0), // 좌상단 작은 조각
        ],
      ),
    );
  }
}

/// 파란 연결선(배경 카드 없음)
class _StepConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2.h,
        margin: EdgeInsets.symmetric(horizontal: 6.w),
        decoration: BoxDecoration(
          color: kStepLite,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}

/// 파이 조각이 들어간 원형 아이콘
class StepCircle extends StatelessWidget {
  final double progress; // 0.0 ~ 1.0
  final double startAngle; // 라디안(좌상단: -3.1 ~ -2.8)
  const StepCircle({super.key, required this.progress, this.startAngle = -3.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(26.w, 26.w),
      painter: _StepCirclePainter(progress, startAngle),
    );
  }
}

class _StepCirclePainter extends CustomPainter {
  final double progress;
  final double startAngle;
  _StepCirclePainter(this.progress, this.startAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    // 진파랑 원
    final bg = Paint()..color = kStepDark;
    canvas.drawCircle(center, r, bg);

    // 밝은 파랑 파이 조각 (좌상단에서 시계 방향)
    final fg = Paint()..color = kStepLite;
    final rect = Rect.fromCircle(center: center, radius: r);
    final sweep = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweep, true, fg);
  }

  @override
  bool shouldRepaint(_StepCirclePainter old) =>
      old.progress != progress || old.startAngle != startAngle;
}

/// ===== 알약형 액션 버튼 (제목 더 크고/굵게) =====
class _ActionPill extends StatelessWidget {
  final String? iconAsset;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap; // ← 추가

  const _ActionPill({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    this.onTap, // ← 추가
  });

  @override
  Widget build(BuildContext context) {
    final Widget iconW =
        (iconAsset != null)
            ? Image.asset(
              iconAsset!,
              width: 22.w,
              height: 22.w,
              errorBuilder:
                  (_, __, ___) => Icon(
                    fallbackIcon,
                    size: 22.sp,
                    color: const Color(0xFF374151),
                  ),
            )
            : Icon(fallbackIcon, size: 22.sp, color: const Color(0xFF374151));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, // ← 추가
        borderRadius: BorderRadius.circular(28.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: kDivider),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: iconW,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 — 크게/굵게
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 20.sp,
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    // 부제 — 얇게
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFont,
                        fontWeight: FontWeight.w400,
                        fontSize: 12.5.sp,
                        color: kTextSub,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

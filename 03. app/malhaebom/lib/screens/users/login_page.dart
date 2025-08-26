// lib/user/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Colors
  static const Color kPrimary = Color(0xFF344CB7); // 일반 버튼/텍스트 버튼 색
  static const Color kDivider = Color(0xFFE5E7EB);
  static const Color kTextDark = Color(0xFF111827);
  static const Color kTextSub = Color(0xFF6B7280);

  // Brand colors
  static const Color kNaver = Color(0xFF03C75A);
  static const Color kKakao = Color(0xFFFEE500);
  static const Color kGoogleBorder = Color(0xFFE5E7EB);

  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _autoLogin = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  // TODO: 실제 SNS/일반 로그인 로직 연결
  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (phone.isEmpty || pw.isEmpty) {
      _snack('휴대전화번호와 비밀번호를 입력해 주세요.');
      return;
    }
    _snack('로그인 시도: $phone');
  }

  void _loginWithGoogle() => _snack('구글로 로그인');
  void _loginWithNaver() => _snack('네이버로 로그인');
  void _loginWithKakao() => _snack('카카오로 로그인');

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 글자 크기 고정
    final fixedMedia = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    return MediaQuery(
      data: fixedMedia,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: '뒤로가기',
          ),
          title: Text(
            '로그인',
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w600,
              fontSize: 16.sp,
              color: Colors.black,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420.w),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 로고
                    Padding(
                      padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/logo/logo_top2.png',
                            height: 64.w,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) => Icon(
                                  Icons.image,
                                  size: 40.w,
                                  color: Colors.black26,
                                ),
                          ),
                          SizedBox(height: 8.h),
                        ],
                      ),
                    ),

                    // SNS 로그인 (구글/네이버/카카오)
                    _googleSoftButton(
                      label: '구글로 로그인',
                      iconPath: 'assets/icons/google_icon.png',
                      onPressed: _loginWithGoogle,
                    ),
                    SizedBox(height: 10.h),
                    _snsFilledButton(
                      label: '네이버로 로그인',
                      iconPath: 'assets/icons/naver_icon.png',
                      background: kNaver,
                      foreground: Colors.white,
                      onPressed: _loginWithNaver,
                    ),
                    SizedBox(height: 10.h),
                    _snsFilledButton(
                      label: '카카오로 로그인',
                      iconPath: 'assets/icons/Kakao_icon.png',
                      background: kKakao,
                      foreground: Colors.black,
                      onPressed: _loginWithKakao,
                    ),

                    SizedBox(height: 16.h),

                    // 구분선
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: kDivider)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text(
                            '또는',
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              fontWeight: FontWeight.w500,
                              fontSize: 12.sp,
                              color: kTextSub,
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: kDivider)),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // 휴대전화번호 (아이디=전화번호 전용)
                    Text(
                      '휴대전화번호',
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                      ],
                      decoration: InputDecoration(
                        hintText: '휴대전화번호를 입력해 주세요.',
                        hintStyle: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w400,
                          fontSize: 13.sp,
                          color: kTextSub,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 14.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: kDivider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: kDivider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(
                            color: kPrimary,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12.h),

                    // 비밀번호
                    Text(
                      '비밀번호',
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _pwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '비밀번호를 입력해 주세요.',
                        hintStyle: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w400,
                          fontSize: 13.sp,
                          color: kTextSub,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 14.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: kDivider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: kDivider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(
                            color: kPrimary,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // 자동로그인
                    Row(
                      children: [
                        Checkbox(
                          value: _autoLogin,
                          onChanged:
                              (v) => setState(() => _autoLogin = v ?? false),
                          activeColor: kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Text(
                          '자동로그인',
                          style: TextStyle(
                            fontFamily: 'GmarketSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 13.sp,
                            color: kTextDark,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // 로그인 버튼 (#344CB7)
                    SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                          textStyle: TextStyle(
                            fontFamily: 'GmarketSans',
                            fontWeight: FontWeight.w700,
                            fontSize: 16.sp,
                          ),
                        ),
                        child: const Text('로그인'),
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // 하단 문구 + 회원가입 링크
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '아직 계정이 없으신가요?',
                          style: TextStyle(
                            fontFamily: 'GmarketSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 13.sp,
                            color: kTextSub,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        _linkButton('회원가입', onTap: () => _snack('회원가입')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------- Buttons & Widgets -----------------

  // Google 전용: 배경을 검정색으로, 아이콘은 원본 그대로 사용
  Widget _googleSoftButton({
    required String label,
    required String iconPath,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48.h,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black, // 검정 배경
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                spreadRadius: 1,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ 원본 PNG 아이콘 그대로
                _assetIcon(iconPath, size: 22),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: Colors.white, // 흰 텍스트
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Naver/Kakao 공통(가득 채운 스타일)
  Widget _snsFilledButton({
    required String label,
    required String iconPath,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          surfaceTintColor: background,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(
            fontFamily: 'GmarketSans',
            fontWeight: FontWeight.w700,
            fontSize: 14.sp,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _assetIcon(iconPath, size: 22),
            SizedBox(width: 8.w),
            Text(label),
          ],
        ),
      ),
    );
  }

  // 일반 아이콘(네이버/카카오/구글에 공통 사용)
  Widget _assetIcon(String path, {double size = 22}) {
    return Image.asset(
      path,
      width: size.w,
      height: size.w,
      fit: BoxFit.contain,
      cacheWidth: (size.w * 3).toInt(),
      cacheHeight: (size.w * 3).toInt(),
      errorBuilder:
          (_, __, ___) => Icon(
            Icons.image_not_supported_rounded,
            size: size.w,
            color: Colors.black26,
          ),
    );
  }

  // 하단 링크(회원가입)
  Widget _linkButton(String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'GmarketSans',
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
            color: kPrimary,
          ),
        ),
      ),
    );
  }
}

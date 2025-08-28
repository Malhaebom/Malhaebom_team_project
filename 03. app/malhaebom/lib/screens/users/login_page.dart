// lib/screens/users/login_page.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

// 추가된 import
import 'package:malhaebom/screens/users/signup_page.dart';
import 'package:malhaebom/screens/main/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ================== 서버 주소 ==================
  static final String API_BASE =
      (() {
        const defined = String.fromEnvironment('API_BASE', defaultValue: '');
        if (defined.isNotEmpty) return defined;

        if (kIsWeb) return 'http://localhost:4000';
        if (Platform.isAndroid) return 'http://10.0.2.2:4000'; // 에뮬레이터 기본
        return 'http://localhost:4000'; // iOS 시뮬레이터/기타
      })();

  // SNS 콜백 스킴/호스트/경로 (Manifest의 data와 동일해야 함)
  static const String CALLBACK_SCHEME = 'myapp';
  static const String CALLBACK_HOST = 'auth';
  static const String CALLBACK_PATH = '/callback';
  static const String CALLBACK_URI =
      '$CALLBACK_SCHEME://$CALLBACK_HOST$CALLBACK_PATH';

  // Colors
  static const Color kPrimary = Color(0xFF344CB7);
  static const Color kDivider = Color(0xFFE5E7EB);
  static const Color kTextDark = Color(0xFF111827);
  static const Color kTextSub = Color(0xFF6B7280);

  // Brand colors
  static const Color kNaver = Color(0xFF03C75A);
  static const Color kKakao = Color(0xFFFEE500);
  static const Color kGoogleBorder = Color(0xFFE5E5E5);

  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  // 🔻 기본 해제
  bool _autoLogin = false;
  bool _loggingIn = false;
  bool _bootChecked = false; // 앱 시작 시 자동로그인 검사 완료 여부

  @override
  void initState() {
    super.initState();
    _loadPrefsAndMaybeAutoLogin();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefsAndMaybeAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAuto = prefs.getBool('auto_login') ?? false;
    final token = prefs.getString('auth_token');

    // ✅ UI에 저장된 값 즉시 반영
    if (mounted) {
      setState(() {
        _autoLogin = savedAuto;
      });
    }

    // 앱 부팅 시 자동로그인 플로우: 저장된 토큰이 있고 auto_login=true 이면 검증
    if (savedAuto && token != null && token.isNotEmpty) {
      try {
        final me = await http.get(
          Uri.parse('$API_BASE/userLogin/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (me.statusCode == 200 && mounted) {
          // 유효 → 곧바로 홈
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
          return;
        }
      } catch (_) {
        // 네트워크 실패 시 그냥 로그인 화면 유지
      }
    }
    if (mounted) setState(() => _bootChecked = true);
  }

  Future<void> _saveAutoLogin(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', v);
  }

  Future<void> _login() async {
    if (_loggingIn) return;

    final userId = _phoneCtrl.text.trim();
    final pwd = _pwCtrl.text;
    if (userId.isEmpty || pwd.isEmpty) {
      _snack('전화번호/비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => _loggingIn = true);
    try {
      final uri = Uri.parse('$API_BASE/userLogin/login');

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'pwd': pwd}),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = j['token'] as String?;
        final user = j['user'] as Map<String, dynamic>?;

        if (token == null) {
          _snack('로그인 응답에 토큰이 없습니다.');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        // ✅ 현재 체크박스(_autoLogin) 기준으로 저장/삭제
        if (_autoLogin) {
          await prefs.setString('auth_token', token);
          await _saveAutoLogin(true);
          await prefs.setBool('auto_login_last', true);
        } else {
          await prefs.remove('auth_token');
          await _saveAutoLogin(false);
          await prefs.setBool('auto_login_last', false);
        }
        if (user != null) {
          await prefs.setString('auth_user', jsonEncode(user));
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else if (resp.statusCode == 401) {
        _snack('아이디 또는 비밀번호가 올바르지 않습니다.');
      } else {
        final msg = _extractMessage(resp.body) ?? '서버 오류가 발생했습니다.';
        _snack('오류(${resp.statusCode}): $msg');
      }
    } catch (e) {
      _snack('네트워크 오류: $e');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  /// ============== 핵심: SNS 로그인 시 '현재 체크박스 상태' 기준으로 처리 ==============
  /// - 토큰 저장/삭제도 _autoLogin(사용자 UI 선택)에 맞춤
  /// - reauth 트리거도 _autoLogin 및 lastAutoUsed/hasToken 조합으로 결정
  Future<void> _startSnsLogin(String provider) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ 지금 화면의 체크박스 상태를 '원하는 설정'으로 확정하고 곧바로 저장(레이스 방지)
    final bool wantAuto = _autoLogin;
    await _saveAutoLogin(wantAuto);

    final bool hasToken = (prefs.getString('auth_token') ?? '').isNotEmpty;
    final bool? lastAutoUsed = prefs.getBool('auto_login_last');

    // 자동로그인 OFF면 혼선 방지를 위해 남아있을 수 있는 토큰 제거
    if (!wantAuto) {
      await prefs.remove('auth_token');
    }

    // 재인증 필요 판단
    bool needReauth = false;
    if (!wantAuto) {
      needReauth = true; // OFF면 항상 계정선택/재동의
    } else {
      if (!hasToken) needReauth = true; // 최초 바인딩
      if (lastAutoUsed != null && lastAutoUsed != wantAuto) {
        needReauth = true; // 이전 로그인 시 설정과 상이
      }
    }

    // 얇은 로딩 오버레이
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final authUrl =
          Uri.parse('$API_BASE/auth/$provider')
              .replace(queryParameters: {if (needReauth) 'reauth': '1'})
              .toString();

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: CALLBACK_SCHEME,
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final uri = Uri.parse(result);
      if (uri.host != CALLBACK_HOST || !uri.path.startsWith(CALLBACK_PATH)) {
        _snack('잘못된 콜백 URL입니다.');
        return;
      }

      final error = uri.queryParameters['error'];
      if (error != null) {
        _snack('SNS 로그인 실패: $error');
        return;
      }

      final token = uri.queryParameters['token'];
      final snsUserId = uri.queryParameters['sns_user_id'];
      final snsNick = uri.queryParameters['sns_nick'];
      final snsLoginType = uri.queryParameters['sns_login_type'] ?? provider;

      if (token == null || snsUserId == null) {
        _snack('SNS 로그인 응답이 올바르지 않습니다.');
        return;
      }

      // ✅ 최종 저장도 wantAuto(현재 체크박스) 기준으로 일관 처리
      if (wantAuto) {
        await prefs.setString('auth_token', token);
        await _saveAutoLogin(true);
        await prefs.setBool('auto_login_last', true);
      } else {
        await prefs.remove('auth_token');
        await _saveAutoLogin(false);
        await prefs.setBool('auto_login_last', false);
      }

      await prefs.setString(
        'auth_user',
        jsonEncode({
          'user_id': snsUserId,
          'nick': snsNick ?? '',
          'sns_login_type': snsLoginType,
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on PlatformException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (e.code == 'canceled' || e.code == 'cancelled') {
        _snack('로그인이 취소되었습니다.');
        return;
      }
      _snack('SNS 로그인 오류: ${e.message ?? e.code}');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('SNS 로그인 중 오류: $e');
    }
  }

  // (참고) 이 페이지에서 직접 로그아웃 쓸 일은 거의 없음. HomePage에서 pushAndRemoveUntil로 처리 권장.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // 자동로그인 토큰만 제거
    await prefs.remove('auth_user'); // 사용자 정보 제거
    // ⚠️ auto_login 값은 절대 건드리지 않음
    _snack('로그아웃되었습니다.');
  }

  String? _extractMessage(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final m = j['message'];
      if (m is String && m.trim().isNotEmpty) return m;
      return null;
    } catch (_) {
      return null;
    }
  }

  void _loginWithGoogle() => _startSnsLogin('google');
  void _loginWithNaver() => _startSnsLogin('naver');
  void _loginWithKakao() => _startSnsLogin('kakao');

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final fixedMedia = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    // 부팅 자동검사 중엔 로딩만 간단히
    if (!_bootChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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

                    // SNS 로그인
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

                    // 휴대전화번호
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
                          onChanged: (v) async {
                            final nv = v ?? false;
                            setState(() => _autoLogin = nv);
                            await _saveAutoLogin(nv); // ✅ 즉시 저장
                          },
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

                    // 로그인 버튼
                    SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _loggingIn ? null : _login,
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
                        child:
                            _loggingIn
                                ? SizedBox(
                                  height: 18.w,
                                  width: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('로그인'),
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
                        _linkButton(
                          '회원가입',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpPage(),
                              ),
                            );
                          },
                        ),
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
            color: Colors.black,
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
                _assetIcon(iconPath, size: 22),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

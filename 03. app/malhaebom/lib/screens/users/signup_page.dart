// lib/user/signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Colors (로그인 페이지와 동일 계열)
  static const Color kPrimary = Color(0xFF344CB7);
  static const Color kDivider = Color(0xFFE5E7EB);
  static const Color kTextDark = Color(0xFF111827);
  static const Color kTextSub = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nickCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  // States
  bool _pwObscure = true;
  bool _pw2Obscure = true;
  DateTime? _birthDate;
  String? _gender; // "남" or "여"

  @override
  void dispose() {
    _nickCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: '생년월일 선택',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  String _formatYMD(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('생년월일을 선택해 주세요.')));
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('성별을 선택해 주세요.')));
      return;
    }
    if (_pwCtrl.text != _pwConfirmCtrl.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    final payload = {
      'nick': _nickCtrl.text.trim(),
      'user_id': _phoneCtrl.text.trim(), // 전화번호를 아이디로 사용할 경우
      'pwd': _pwCtrl.text,
      'birth': _formatYMD(_birthDate!),
      'gender': _gender,
    };

    // TODO: 서버 연동 (예: POST /join)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('회원가입 요청을 보냈습니다.')));
  }

  // 입력 박스 공통 데코 (라운드, 옅은 테두리, 플레이스홀더) — 라벨은 상단 Text로 별도 표기
  InputDecoration _boxDec({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'GmarketSans',
        fontWeight: FontWeight.w400,
        color: kTextSub,
        fontSize: 13.sp,
      ),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: kDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: kPrimary, width: 1.2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      suffixIcon: suffix,
    );
  }

  // 상단 라벨 텍스트 (로그인 화면 스타일 맞춤)
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'GmarketSans',
        fontWeight: FontWeight.w600,
        fontSize: 13.sp,
        color: kTextDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        centerTitle: true,
        title: Text(
          '회원가입',
          style: TextStyle(
            fontFamily: 'GmarketSans',
            color: kTextDark,
            fontWeight: FontWeight.w600,
            fontSize: 16.sp,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8.h),

              // 닉네임
              _fieldLabel('닉네임'),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _nickCtrl,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 14.sp,
                  color: kTextDark,
                ),
                decoration: _boxDec(hint: '닉네임을 입력해 주세요.'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '닉네임을 입력해 주세요.';
                  if (v.trim().length > 20) return '닉네임은 20자 이내로 입력해 주세요.';
                  return null;
                },
              ),

              SizedBox(height: 12.h),

              // 휴대전화번호
              _fieldLabel('휴대전화번호'),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 14.sp,
                  color: kTextDark,
                ),
                decoration: _boxDec(hint: '휴대전화번호를 입력해 주세요.'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return '휴대전화번호를 입력해 주세요.';
                  if (s.length < 10 || s.length > 11) {
                    return '휴대전화번호 길이를 확인해 주세요.';
                  }
                  return null;
                },
              ),

              SizedBox(height: 12.h),

              // 비밀번호
              _fieldLabel('비밀번호'),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _pwCtrl,
                obscureText: _pwObscure,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 14.sp,
                  color: kTextDark,
                ),
                decoration: _boxDec(
                  hint: '비밀번호를 입력해 주세요.',
                  suffix: IconButton(
                    onPressed: () => setState(() => _pwObscure = !_pwObscure),
                    icon: Icon(
                      _pwObscure ? Icons.visibility_off : Icons.visibility,
                      color: kTextSub,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? '');
                  if (s.isEmpty) return '비밀번호를 입력해 주세요.';
                  if (s.length < 6) return '비밀번호는 6자 이상이어야 해요.';
                  return null;
                },
              ),

              SizedBox(height: 12.h),

              // 비밀번호 확인
              _fieldLabel('비밀번호 확인'),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _pwConfirmCtrl,
                obscureText: _pw2Obscure,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  fontSize: 14.sp,
                  color: kTextDark,
                ),
                decoration: _boxDec(
                  hint: '비밀번호를 다시 입력해 주세요.',
                  suffix: IconButton(
                    onPressed: () => setState(() => _pw2Obscure = !_pw2Obscure),
                    icon: Icon(
                      _pw2Obscure ? Icons.visibility_off : Icons.visibility,
                      color: kTextSub,
                    ),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? '');
                  if (s.isEmpty) return '비밀번호 확인을 입력해 주세요.';
                  if (s != _pwCtrl.text) return '비밀번호가 일치하지 않습니다.';
                  return null;
                },
              ),

              SizedBox(height: 12.h),

              // 생년월일 (달력 스타일 입력)
              _fieldLabel('생년월일'),
              SizedBox(height: 8.h),
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(12.r),
                child: InputDecorator(
                  decoration: _boxDec(hint: '달력을 열어 생년월일을 선택해 주세요.'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _birthDate == null
                              ? '달력을 열어 생년월일을 선택해 주세요.'
                              : _formatYMD(_birthDate!),
                          style: TextStyle(
                            fontFamily: 'GmarketSans',
                            color: _birthDate == null ? kTextSub : kTextDark,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: kTextSub),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // 성별 (남/여)
              _fieldLabel('성별'),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: kDivider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: '남',
                        groupValue: _gender,
                        onChanged: (v) => setState(() => _gender = v),
                        title: Text(
                          '남',
                          style: TextStyle(
                            fontFamily: 'GmarketSans',
                            fontSize: 14.sp,
                            color: kTextDark,
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: '여',
                        groupValue: _gender,
                        onChanged: (v) => setState(() => _gender = v),
                        title: Text(
                          '여',
                          style: TextStyle(
                            fontFamily: 'GmarketSans',
                            fontSize: 14.sp,
                            color: kTextDark,
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // 회원가입 버튼 (텍스트 흰색)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white, // ✅ 흰색 텍스트
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                    textStyle: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('회원가입'),
                ),
              ),

              SizedBox(height: 16.h),

              // 하단 문구: "계정을 보유하고 계신가요? 로그인"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '계정을 보유하고 계신가요? ',
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      color: kTextSub,
                      fontSize: 13.sp,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // 로그인으로 돌아가기
                    },
                    child: Text(
                      '로그인',
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        color: kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}

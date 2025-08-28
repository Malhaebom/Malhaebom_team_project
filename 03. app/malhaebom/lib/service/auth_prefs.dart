// lib/services/auth_prefs.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthPrefs {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kAuto = 'auto_login';
  static const _kAutoLast = 'auto_login_last';

  /// 토큰 저장/삭제
  static Future<void> setToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
  }

  static Future<void> removeToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  /// 유저 정보 저장/삭제
  static Future<void> setUser(Map<String, dynamic> user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, jsonEncode(user));
  }

  static Future<void> removeUser() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUser);
  }

  /// 자동 로그인 체크 박스 값 (사용자 설정)
  static Future<void> setAutoLogin(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAuto, v);
  }

  static Future<bool> getAutoLogin() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAuto) ?? false;
  }

  /// 마지막 로그인 시 사용한 자동로그인 상태 (재인증 판단용)
  static Future<void> setAutoLoginLast(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoLast, v);
  }

  static Future<bool?> getAutoLoginLast() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAutoLast);
  }

  /// 로그아웃: **토큰/유저만** 지움 (auto_login은 건드리지 마세요!)
  static Future<void> logoutKeepSetting() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
    // auto_login, auto_login_last는 유지 (사용자 의도 존중)
  }
}

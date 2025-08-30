import 'package:malhaebom/screens/main/home_page.dart';
import 'package:malhaebom/screens/main/splash_page.dart';
import 'package:malhaebom/screens/story/story_main_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/story/story_test_page.dart';
import 'package:malhaebom/screens/users/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ScreenUtilInit(
      designSize: Size(375, 812),
      builder: (context, child) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Malhaebom',
      theme: ThemeData(fontFamily: 'Pretendard'),
      debugShowCheckedModeBanner: false,
      home: SplashPage(next: const LoginPage()),
      //home: SplashPage(next: const HomePage()),
    );
  }
}
